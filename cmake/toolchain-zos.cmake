# z/OS toolchain for CMake.
#
#   ./configure --zos --release
#   # or
#   cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-zos.cmake \
#         -DZKSH_ZOS=ON -DCMAKE_BUILD_TYPE=Release
#
# VERIFIED 2026-11-05 on a real z/OS system (Open XL 2.1, CMake 3.31):
#   - CMake ships no Platform module for z/OS, and the name "z/OS"
#     warns on every probe. The system is named ZKSH-ZOS and
#     cmake/Platform/ZKSH-ZOS.cmake supplies the module.
#   - The compiler is /usr/lpp/IBM/cnw/v2r1/openxl/bin/ibm-clang64.
#   - -m64 and -march are NOT passed by default: Open XL defaults to
#     64-bit XPLINK at the machine's own level, and a build made for a
#     higher -march will not run on a lower one. Opt in with
#     -DZKSH_ZOS_ARCH=z16.
#   - zopen's layout is nested (/usr/local/zopen/usr/local/zopen/<pkg>),
#     so roots are searched, not assumed.

set(CMAKE_SYSTEM_NAME ZKSH-ZOS)
set(CMAKE_SYSTEM_PROCESSOR s390x)

# Our modules first, so Platform/ZKSH-ZOS-Initialize.cmake is found.
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")

# IBM Open XL C/C++ 2.1 (ibm-clang64). xlc is not supported.
if(NOT CMAKE_C_COMPILER)
  find_program(ZKSH_ZOS_CC NAMES ibm-clang64
    HINTS /usr/lpp/IBM/cnw/v2r1/openxl/bin)
  if(NOT ZKSH_ZOS_CC)
    message(FATAL_ERROR
      "ibm-clang64 not found. Pass --cc=/path/to/ibm-clang64 (or "
      "-DCMAKE_C_COMPILER=...) or set ZKSH_ZOS_CC.")
  endif()
  set(CMAKE_C_COMPILER ${ZKSH_ZOS_CC})
endif()

# Open XL is clang based; telling CMake so makes compiler-specific
# flags and the "compiler identification is unknown" message go away.
set(CMAKE_C_COMPILER_ID Clang)

if(ZKSH_ZOS_ARCH)
  set(CMAKE_C_FLAGS_INIT "-march=${ZKSH_ZOS_ARCH}")
endif()

set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")

# ---- zopen -----------------------------------------------------------
# zopen's layout has varied: <root>/Common, <root>/usr/local/zopen/<pkg>,
# or a per-package directory directly. Find whichever exists.

if(NOT ZKSH_ZOPEN_ROOT)
  foreach(candidate
      "$ENV{ZOPEN_ROOT}/Common"
      "$ENV{ZOPEN_ROOT}"
      /usr/local/zopen/Common
      /usr/local/zopen/usr/local/zopen
      /usr/local/zopen/prod
      /usr/local/zopen/dev
      /usr/local/zopen)
    if(EXISTS "${candidate}/bin" OR EXISTS "${candidate}/include")
      set(ZKSH_ZOPEN_ROOT "${candidate}")
      break()
    endif()
  endforeach()
endif()

if(ZKSH_ZOPEN_ROOT)
  list(APPEND CMAKE_PREFIX_PATH "${ZKSH_ZOPEN_ROOT}")
  list(APPEND CMAKE_FIND_ROOT_PATH "${ZKSH_ZOPEN_ROOT}")
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
# Override with -DZKSH_CURSES_PREFIX=<pkgdir> or set both
# -DCURSES_INCLUDE_PATH=... and -DCURSES_LIBRARY=... directly.

# CMake reads this file at project() time, before CMakeLists.txt has
# declared its options, so ZKSH_EDITOR is not defined yet here. Treat
# "undefined" as ON -- that is the CMakeLists default -- and only skip
# the search when the user explicitly turned line editing off. Testing
# `if(ZKSH_EDITOR)` here skips the search on every normal configure,
# which loses curses, turns ZKSH_EDITOR off, and then trips
# config.h:25 ("Define either EMACS or VI.") during the build.
if(DEFINED ZKSH_EDITOR)
  set(_zksh_want_curses ${ZKSH_EDITOR})
else()
  set(_zksh_want_curses ON)
endif()

if(_zksh_want_curses AND (NOT CURSES_INCLUDE_PATH OR NOT CURSES_LIBRARY))
  set(_zksh_curses_roots "")
  if(ZKSH_CURSES_PREFIX)
    list(APPEND _zksh_curses_roots "${ZKSH_CURSES_PREFIX}")
  endif()
  if(ZKSH_ZOPEN_ROOT)
    list(APPEND _zksh_curses_roots "${ZKSH_ZOPEN_ROOT}")
  endif()
  # <root>/usr/local is the shared prefix zopen installs into, and
  # <root>/ncurses/<pkg> is the package directory.
  list(APPEND _zksh_curses_roots
    /usr/local/zopen
    /usr/local/zopen/usr/local
    /usr/local)
  file(GLOB _zksh_ncurses_pkgs
    "/usr/local/zopen/usr/local/zopen/ncurses/ncurses-*")

  foreach(_root ${_zksh_curses_roots} ${_zksh_ncurses_pkgs})
    if(NOT CURSES_INCLUDE_PATH)
      foreach(_inc "${_root}/include/ncursesw" "${_root}/include/ncurses")
        if(EXISTS "${_inc}/curses.h")
          # term.h in this tree does #include <ncursesw/ncurses_dll.h>,
          # so the parent of the ncursesw directory must be on the path
          # too. FindCurses treats CURSES_INCLUDE_PATH as one directory,
          # so the parent goes in its own variable.
          get_filename_component(_parent "${_inc}" DIRECTORY)
          if(_inc MATCHES "/ncursesw$" AND EXISTS "${_parent}/ncursesw/ncurses_dll.h")
            set(CURSES_INCLUDE_PATH "${_inc}")
            set(ZKSH_CURSES_EXTRA_INCLUDE "${_parent}")
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
    message(STATUS "zksh: z/OS ncurses at ${CURSES_LIBRARY}")
    message(STATUS "zksh: ncurses headers at ${CURSES_INCLUDE_PATH}")
    if(ZKSH_CURSES_EXTRA_INCLUDE)
      message(STATUS "zksh: ncurses header parent at ${ZKSH_CURSES_EXTRA_INCLUDE}")
    endif()
  else()
    message(STATUS
      "zksh: z/OS ncurses not found (include: '${CURSES_INCLUDE_PATH}' "
      "lib: '${CURSES_LIBRARY}'); line editing will be disabled. "
      "Pass -DZKSH_CURSES_PREFIX=<dir> or -DCURSES_INCLUDE_PATH=... "
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
