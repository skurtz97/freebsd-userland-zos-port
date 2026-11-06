# z/OS toolchain for CMake.
#
#   ./configure --zos --release
#   # or
#   cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-zos.cmake \
#         -DZKSH_ZOS=ON -DCMAKE_BUILD_TYPE=Release
#
# VERIFIED 2026-11-05 on a real z/OS system:
#   - CMake 3.31 has no Platform/zOS module ("System is unknown to
#     cmake, create Platform/z/OS"). Naming the system z/OS gains
#     nothing and loses the platform modules, which is why sig_t,
#     st_mtim and timerclear were all reported missing on a system
#     that has them. z/OS is a UNIX system: name it UNIX. The
#     compiler's own __MVS__ macro identifies z/OS in the source.
#   - The compiler is /usr/lpp/IBM/cnw/v2r1/openxl/bin/ibm-clang64.
#     No -m64/-march is passed by default; Open XL defaults to 64-bit
#     XPLINK and the machine's own level. Set ZKSH_ZOS_ARCH to pin it.
#   - zopen's tree must be located, not guessed: ZKSH_ZOPEN_ROOT.

set(CMAKE_SYSTEM_NAME UNIX)
set(CMAKE_SYSTEM_PROCESSOR s390x)

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

# Defaults come from the compiler. -march is opt-in: this machine is a
# z16, but a build made for a higher level will not run on a lower one.
if(ZKSH_ZOS_ARCH)
  set(CMAKE_C_FLAGS_INIT "-march=${ZKSH_ZOS_ARCH}")
endif()

set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")

# ---- zopen -----------------------------------------------------------
# zopen's layout has varied: <root>/Common, <root>/usr/local/zopen/<pkg>,
# or a per-package directory directly. Find whichever exists rather
# than assume one.

if(NOT ZKSH_ZOPEN_ROOT)
  foreach(candidate
      "$ENV{ZOPEN_ROOT}/Common"
      "$ENV{ZOPEN_ROOT}"
      /usr/local/zopen/Common
      /usr/local/zopen/usr/local/zopen
      /usr/local/zopen
      /usr/local/zopen/prod
      /usr/local/zopen/dev)
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
# VERIFY the exact subpaths on the system; -DZKSH_CURSES_PREFIX overrides.

if(NOT ZKSH_CURSES_PREFIX AND ZKSH_ZOPEN_ROOT)
  foreach(candidate
      "${ZKSH_ZOPEN_ROOT}/ncurses"
      "${ZKSH_ZOPEN_ROOT}"
      "${ZKSH_ZOPEN_ROOT}/usr/local/zopen/ncurses")
    if(EXISTS "${candidate}/lib" OR EXISTS "${candidate}/lib64")
      list(APPEND CMAKE_PREFIX_PATH "${candidate}")
    endif()
  endforeach()
endif()

set(CURSES_NEED_NCURSES TRUE)
set(CURSES_NEED_WIDE TRUE)

# ---- Native build -----------------------------------------------------
# Programs, libraries and headers all come from this system.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
