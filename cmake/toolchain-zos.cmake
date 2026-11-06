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
#     cmake/Platform/ZKSH-ZOS-Initialize.cmake supplies the module.
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
# zopen builds ncurses --enable-widec: libncursesw, headers under
# include/ncursesw or include/ncurses, terminfo under ASCII_TERMINFO.
# Pass -DZKSH_CURSES_PREFIX=... if the search below misses it, or
# -DCURSES_INCLUDE_PATH=... -DCURSES_LIBRARY=... directly.

if(ZKSH_CURSES_PREFIX)
  list(APPEND CMAKE_PREFIX_PATH "${ZKSH_CURSES_PREFIX}")
elseif(ZKSH_ZOPEN_ROOT)
  foreach(candidate
      "${ZKSH_ZOPEN_ROOT}/ncurses"
      "${ZKSH_ZOPEN_ROOT}/usr/local/zopen/ncurses"
      "${ZKSH_ZOPEN_ROOT}")
    if(EXISTS "${candidate}/lib" OR EXISTS "${candidate}/lib64")
      list(APPEND CMAKE_PREFIX_PATH "${candidate}")
    endif()
  endforeach()
endif()

set(CURSES_NEED_NCURSES TRUE)
set(CURSES_NEED_WIDE TRUE)

# ---- Native build ----------------------------------------------------
# Programs, libraries and headers all come from this system.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
