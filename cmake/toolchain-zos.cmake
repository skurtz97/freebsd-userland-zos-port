# z/OS toolchain for CMake.
#
#   cmake -S . -B build-zos \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-zos.cmake \
#     -DZKSH_ZOS=ON -DCMAKE_BUILD_TYPE=Release
#
# or, through the shim:  ./configure --zos --release
#
# Lines marked VERIFY were written from the z/OS reference
# documentation and from the zrx project's build, not from a
# successful build of zksh on z/OS. The first real build should
# confirm or correct them; record the answer here.
#
# VERIFIED (2026-11-05): removed CMAKE_C_COMPILER_TARGET. A native
# build must not set a compiler target triple -- ibm-clang64 already
# targets z/OS, and a triple overrides that. The same triple was the
# reason the zrx scripts needed it only for cross-generating assembly
# with a Linux clang, which is a different job.

set(CMAKE_SYSTEM_NAME z/OS)
set(CMAKE_SYSTEM_PROCESSOR s390x)

# IBM Open XL C/C++ 2.1. xlc is not supported: Open XL is clang based,
# so the options are clang options (see ~/src/zrx/Makefile).
if(NOT DEFINED CMAKE_C_COMPILER)
  find_program(ZKSH_ZOS_CC ibm-clang64)
  if(NOT ZKSH_ZOS_CC)
    message(FATAL_ERROR
      "ibm-clang64 not found in PATH (IBM Open XL C/C++ 2.1); "
      "pass -DZKSH_ZOS_CC=/path/to/ibm-clang64 or --cc= to configure")
  endif()
  set(CMAKE_C_COMPILER ${ZKSH_ZOS_CC})
endif()

# 64-bit XPLINK. Amode 31 is only needed to call TSO/E services, and
# that is done at call sites, not by building the shell 31-bit.
set(ZKSH_ZOS_ARCH "z16" CACHE STRING "z/OS -march level (z16 is the tested machine)")
set(CMAKE_C_FLAGS_INIT "-m64 -march=${ZKSH_ZOS_ARCH}")

# VERIFY: whether _ALL_SOURCE is needed at all is decided by the first
# build. checks.cmake applies it to the feature checks; CMakeLists.txt
# applies it to the build.
set(CMAKE_C_FLAGS_DEBUG_INIT "-g")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")

# The zopen tree supplies cmake, ninja, make, ncurses and the shell
# tools. VERIFY: set ZOPEN_ROOT, or pass -DZKSH_ZOPEN_ROOT=..., or let
# the default below find it.
if(NOT DEFINED ZKSH_ZOPEN_ROOT)
  if(DEFINED ENV{ZOPEN_ROOT})
    set(ZKSH_ZOPEN_ROOT $ENV{ZOPEN_ROOT})
  elseif(EXISTS /usr/local/zopen/Common)
    set(ZKSH_ZOPEN_ROOT /usr/local/zopen)
  endif()
endif()

if(ZKSH_ZOPEN_ROOT)
  # zopen installs into per-package directories; the "Common" tree is
  # the merged view, which has bin/ lib/ include/.
  list(APPEND CMAKE_PREFIX_PATH ${ZKSH_ZOPEN_ROOT}/Common)
  list(APPEND CMAKE_FIND_ROOT_PATH ${ZKSH_ZOPEN_ROOT}/Common)
  # ncurses is built --enable-widec: toolchain file must ask for wide.
  set(CURSES_NEED_WIDE TRUE)
  set(CURSES_NEED_NCURSES TRUE)
endif()

# Native build: programs, libraries and headers all come from this
# system. (For a cross build this would be BOTH or ONLY.)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
