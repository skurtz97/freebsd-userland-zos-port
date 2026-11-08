# z/OS toolchain for CMake.
#
#   ./configure --zos --release
#   # or
#   cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-zos.cmake \
#         -DFSH_ZOS=ON -DCMAKE_BUILD_TYPE=Release
#
# VERIFIED 2026-11-05 on a real z/OS system (Open XL 2.1, CMake 3.31):
#   - CMake ships no Platform module for z/OS, and the name "z/OS"
#     warns on every probe. The system is named FSH-ZOS and
#     cmake/Platform/FSH-ZOS.cmake supplies the module.
#   - The compiler is /usr/lpp/IBM/cnw/v2r1/openxl/bin/ibm-clang64.
#   - -m64 and -march are NOT passed by default: Open XL defaults to
#     64-bit XPLINK at the machine's own level, and a build made for a
#     higher -march will not run on a lower one. Opt in with
#     -DFSH_ZOS_ARCH=z16.
#   - zopen's layout is nested (/usr/local/zopen/usr/local/zopen/<pkg>),
#     so roots are searched, not assumed.

set(CMAKE_SYSTEM_NAME FSH-ZOS)
set(CMAKE_SYSTEM_PROCESSOR s390x)

# Our modules first, so Platform/FSH-ZOS-Initialize.cmake is found.
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

# Compiler selection:
#   FSH_ZOS_COMPILER=openxl  (default) -> IBM Open XL, ibm-clang64
#   FSH_ZOS_COMPILER=xlc               -> legacy XL C/C++, xlc/xlc64
# CMAKE_C_COMPILER (or ./configure --cc=...) overrides either choice.
if(NOT CMAKE_C_COMPILER)
  if(FSH_ZOS_COMPILER STREQUAL "xlc")
    find_program(FSH_ZOS_CC NAMES xlc xlc64)
    if(NOT FSH_ZOS_CC)
      message(FATAL_ERROR
        "xlc not found. Pass --cc=/path/to/xlc (or "
        "-DCMAKE_C_COMPILER=...) or set FSH_ZOS_CC.")
    endif()
  elseif(FSH_ZOS_COMPILER AND NOT FSH_ZOS_COMPILER STREQUAL "openxl")
    message(FATAL_ERROR
      "FSH_ZOS_COMPILER must be 'openxl' or 'xlc', not '${FSH_ZOS_COMPILER}'.")
  else()
    find_program(FSH_ZOS_CC NAMES ibm-clang64
      HINTS /usr/lpp/IBM/cnw/v2r1/openxl/bin)
    if(NOT FSH_ZOS_CC)
      message(FATAL_ERROR
        "ibm-clang64 not found. Pass --cc=/path/to/ibm-clang64 (or "
        "-DCMAKE_C_COMPILER=...), set FSH_ZOS_CC, or choose xlc with "
        "-DFSH_ZOS_COMPILER=xlc.")
    endif()
  endif()
  set(CMAKE_C_COMPILER ${FSH_ZOS_CC})
endif()

# Open XL is clang based. Legacy xlc needs its own 64-bit/XPLINK and
# language-level flags; telling CMake the compiler family avoids both
# the "compiler identification is unknown" warning and GNU-style flags
# the XL compiler does not understand.
get_filename_component(_fsh_cc_name "${CMAKE_C_COMPILER}" NAME)
if(_fsh_cc_name MATCHES "^xlc")
  set(_fsh_xlc TRUE)
  set(CMAKE_C_COMPILER_ID XL)
  set(CMAKE_C_FLAGS_INIT "-q64 -qXPLINK -qlanglvl=extended")
else()
  set(_fsh_xlc FALSE)
  set(CMAKE_C_COMPILER_ID Clang)
endif()

if(FSH_ZOS_ARCH)
  if(_fsh_xlc)
    string(APPEND CMAKE_C_FLAGS_INIT " -qarch=${FSH_ZOS_ARCH}")
  else()
    string(APPEND CMAKE_C_FLAGS_INIT " -march=${FSH_ZOS_ARCH}")
  endif()
endif()

set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")

# ---- zopen -----------------------------------------------------------
# zopen's layout has varied: <root>/Common, <root>/usr/local/zopen/<pkg>,
# or a per-package directory directly. Find whichever exists.

if(NOT FSH_ZOPEN_ROOT)
  foreach(candidate
      "$ENV{ZOPEN_ROOT}/Common"
      "$ENV{ZOPEN_ROOT}"
      /usr/local/zopen/Common
      /usr/local/zopen/usr/local/zopen
      /usr/local/zopen/prod
      /usr/local/zopen/dev
      /usr/local/zopen)
    if(EXISTS "${candidate}/bin" OR EXISTS "${candidate}/include")
      set(FSH_ZOPEN_ROOT "${candidate}")
      break()
    endif()
  endforeach()
endif()

if(FSH_ZOPEN_ROOT)
  list(APPEND CMAKE_PREFIX_PATH "${FSH_ZOPEN_ROOT}")
  list(APPEND CMAKE_FIND_ROOT_PATH "${FSH_ZOPEN_ROOT}")
endif()

# ---- ncurses ---------------------------------------------------------
# zopen builds ncurses --enable-widec: libncursesw.a plus headers under
# include/ncursesw, terminfo under ASCII_TERMINFO. Only STATIC archives
# are installed (libncursesw.a and the _g debug variant), so CMake's
# FindCurses -- which searches "-lncursesw" as a plain name and does not
# look inside include/ncursesw -- misses it and the build silently loses
# line editing. Search for the pieces ourselves and hand them over.
#
# Observed on z/OS 2026-11-05:
#   /usr/local/zopen/usr/local/include/ncursesw/curses.h
#   /usr/local/zopen/usr/local/lib/libncursesw.a
#   /usr/local/zopen/usr/local/zopen/ncurses/ncurses-<version>.zos/{include/ncursesw,lib}
#
# Override with -DFSH_CURSES_PREFIX=<pkgdir> or set both
# -DCURSES_INCLUDE_PATH=... and -DCURSES_LIBRARY=... directly.

# CMake reads this file at project() time, before CMakeLists.txt has
# declared its options, so FSH_EDITOR is not defined yet here. Treat
# "undefined" as ON -- that is the CMakeLists default -- and only skip
# the search when the user explicitly turned line editing off. Testing
# `if(FSH_EDITOR)` here skips the search on every normal configure,
# which loses curses, turns FSH_EDITOR off, and then trips
# config.h:25 ("Define either EMACS or VI.") during the build.
if(DEFINED FSH_EDITOR)
  set(_fsh_want_curses ${FSH_EDITOR})
else()
  set(_fsh_want_curses ON)
endif()

if(_fsh_want_curses AND (NOT CURSES_INCLUDE_PATH OR NOT CURSES_LIBRARY))
  set(_fsh_curses_roots "")
  if(FSH_CURSES_PREFIX)
    list(APPEND _fsh_curses_roots "${FSH_CURSES_PREFIX}")
  endif()
  if(FSH_ZOPEN_ROOT)
    list(APPEND _fsh_curses_roots "${FSH_ZOPEN_ROOT}")
  endif()
  # <root>/usr/local is the shared prefix zopen installs into, and
  # <root>/ncurses/<pkg> is the package directory.
  list(APPEND _fsh_curses_roots
    /usr/local/zopen
    /usr/local/zopen/usr/local
    /usr/local)
  file(GLOB _fsh_ncurses_pkgs
    "/usr/local/zopen/usr/local/zopen/ncurses/ncurses-*")

  foreach(_root ${_fsh_curses_roots} ${_fsh_ncurses_pkgs})
    if(NOT CURSES_INCLUDE_PATH)
      foreach(_inc "${_root}/include/ncursesw" "${_root}/include/ncurses")
        if(EXISTS "${_inc}/curses.h")
          # term.h in this tree does #include <ncursesw/ncurses_dll.h>,
          # so something that contains a `ncursesw` name must be on the
          # include path. Do NOT simply put the parent directory there:
          # on this system the parent is zopen's SHARED include tree
          # (/usr/local/zopen/usr/local/include), which holds every
          # zopen package's headers -- including sys/time.h, sys/param.h
          # and sys/stat.h from zoslib. Adding it silently shadows the
          # system headers for the whole build, so the shell compiled
          # against one set of headers while every feature probe saw
          # another (HAVE_TIMERSUB said no, the compiler saw timersub).
          #
          # Instead, build a one-entry shim directory in the build tree
          # that contains only a `ncursesw` link. Then the only thing
          # exposed is what ncurses itself needs.
          get_filename_component(_parent "${_inc}" DIRECTORY)
          if(_inc MATCHES "/ncursesw$" AND EXISTS "${_parent}/ncursesw/ncurses_dll.h")
            set(CURSES_INCLUDE_PATH "${_inc}")
            set(FSH_CURSES_SHIM "${CMAKE_BINARY_DIR}/ncurses-shim")
          else()
            set(CURSES_INCLUDE_PATH "${_inc}")
          endif()
          break()
        endif()
      endforeach()
    endif()
    if(NOT CURSES_LIBRARY)
      if(EXISTS "${_root}/lib/libncursesw.a")
        set(CURSES_LIBRARY "${_root}/lib/libncursesw.a")
      endif()
    endif()
    if(CURSES_INCLUDE_PATH AND CURSES_LIBRARY)
      break()
    endif()
  endforeach()

  if(CURSES_INCLUDE_PATH AND CURSES_LIBRARY)
    message(STATUS "fsh: z/OS ncurses at ${CURSES_LIBRARY}")
    message(STATUS "fsh: ncurses headers at ${CURSES_INCLUDE_PATH}")
    if(FSH_CURSES_SHIM)
      file(MAKE_DIRECTORY "${FSH_CURSES_SHIM}")
      file(CREATE_LINK "${_parent}/ncursesw" "${FSH_CURSES_SHIM}/ncursesw"
        SYMBOLIC COPY_ON_ERROR)
      message(STATUS "fsh: ncurses include shim at ${FSH_CURSES_SHIM}")
    endif()

    # ---- zoslib ------------------------------------------------------
    # libncursesw.a does not bind on its own. zopen's ncurses package
    # links against zoslib, and these names are zoslib's:
    #   __fopen_ascii, __sysconf   (the ASCII runtime shims)
    #   __cxa_guard_abort, std::to_string  (what libncursesw.a's C++
    #                               members pull in)
    # Without both archives the bind ends in IEW2456E "MEMBER COULD NOT
    # BE INCLUDED FROM THE DESIGNATED CALL LIBRARY" and exit 12.
    #
    # This is from the package's own pkg-config Libs line, then
    # bisected on the host to the minimum for a C caller:
    #   archive + -lzoslib                 -> __cxa_guard_abort (fails)
    #   archive + -lzoslib -lzoslib-supp   -> links
    # celquopt.s.o in that line is for C++ exceptions and is not
    # needed here; -Wl,-bcompress=yes only shrinks the load module.
    if(NOT FSH_ZOSLIB_LIBDIR)
      foreach(_zl
          /usr/local/zopen/usr/local/zopen/zoslib/zoslib/lib
          "${FSH_ZOPEN_ROOT}/usr/local/zopen/zoslib/zoslib/lib"
          "${FSH_ZOPEN_ROOT}/zoslib/zoslib/lib"
          /usr/local/zopen/usr/local/zopen/zoslib/lib)
        if(EXISTS "${_zl}/libzoslib.a")
          set(FSH_ZOSLIB_LIBDIR "${_zl}")
          break()
        endif()
      endforeach()
    endif()

    if(FSH_ZOSLIB_LIBDIR
        AND EXISTS "${FSH_ZOSLIB_LIBDIR}/libzoslib.a"
        AND EXISTS "${FSH_ZOSLIB_LIBDIR}/libzoslib-supp.a")
      set(FSH_CURSES_LINK_ITEMS
        "${FSH_ZOSLIB_LIBDIR}/libzoslib.a"
        "${FSH_ZOSLIB_LIBDIR}/libzoslib-supp.a")
      message(STATUS "fsh: z/OS zoslib at ${FSH_ZOSLIB_LIBDIR}")
    else()
      message(WARNING
        "fsh: zoslib not found (looked under FSH_ZOSLIB_LIBDIR="
        "'${FSH_ZOSLIB_LIBDIR}'). libncursesw.a will not bind: "
        "IEW2456E __fopen_ascii/__sysconf. Pass "
        "-DFSH_ZOSLIB_LIBDIR=<dir containing libzoslib.a>.")
    endif()
  else()
    message(STATUS
      "fsh: z/OS ncurses not found (include: '${CURSES_INCLUDE_PATH}' "
      "lib: '${CURSES_LIBRARY}'); line editing will be disabled. "
      "Pass -DFSH_CURSES_PREFIX=<dir> or -DCURSES_INCLUDE_PATH=... "
      "-DCURSES_LIBRARY=....")
  endif()
endif()

set(CURSES_NEED_NCURSES TRUE)
set(CURSES_NEED_WIDE TRUE)

# ---- Native build ----------------------------------------------------
# Programs, libraries and headers all come from this system.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
