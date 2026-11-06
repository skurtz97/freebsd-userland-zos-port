# z/OS toolchain for CMake.
#
#   cmake -S . -B build-zos \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-zos.cmake \
#     -DZKSH_ZOS=ON -DCMAKE_BUILD_TYPE=Release
#
# Every line marked VERIFY was written from the z/OS reference
# documentation and from the zrx project's build, not from a
# successful build of zksh on z/OS. The first real build should
# confirm or correct them, and this file is the place to record the
# answer.

set(CMAKE_SYSTEM_NAME z/OS)
set(CMAKE_SYSTEM_PROCESSOR s390x)

# IBM Open XL C/C++ 2.1. xlc is not supported: Open XL is clang based,
# so the options are clang options (see ~/src/zrx/Makefile).
find_program(ZKSH_ZOS_CC ibm-clang64)
if(NOT ZKSH_ZOS_CC)
  message(FATAL_ERROR "ibm-clang64 not found in PATH (IBM Open XL C/C++ 2.1)")
endif()

set(CMAKE_C_COMPILER ${ZKSH_ZOS_CC})
set(CMAKE_C_COMPILER_TARGET s390x-ibm-zos)

# 64-bit XPLINK. Amode 31 is only needed to call TSO/E services, and
# that is done at call sites, not by building the shell 31-bit.
set(ZKSH_ZOS_ARCH "z16" CACHE STRING "z/OS -march level (z16 is the tested machine)")
set(CMAKE_C_FLAGS_INIT "-m64 -march=${ZKSH_ZOS_ARCH}")

# VERIFY: _ALL_SOURCE selects the full z/OS UNIX API surface in the
# LE headers. Confirm it is needed and sufficient.
set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")

# The zopen tree supplies make, cmake, ninja, ncurses and the shell
# tools. VERIFY: adjust to this system's zopen root.
if(DEFINED ENV{ZOPEN_ROOT})
  set(ZKSH_ZOPEN_ROOT $ENV{ZOPEN_ROOT})
elseif(EXISTS /usr/local/zopen/Common)
  set(ZKSH_ZOPEN_ROOT /usr/local/zopen)
endif()

if(ZKSH_ZOPEN_ROOT)
  # ncurses is built --enable-widec, so the library is ncursesw and
  # terminfo lives under ASCII_TERMINFO.
  list(APPEND CMAKE_PREFIX_PATH ${ZKSH_ZOPEN_ROOT})
  set(CURSES_NEED_WIDE TRUE)
endif()

# Host programs for the build itself are the same machine on z/OS.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
