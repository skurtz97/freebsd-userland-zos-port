# Platform/FSH-ZOS.cmake -- fsh's own CMake platform module.
#
# CMake ships no Platform/zOS, and CMakeSystemSpecificInformation
# prints "System is unknown to cmake" unless Platform/<name> exists.
# Rather than name the system UNIX (accurate) and accept ~40 lines of
# warning per configure, name it FSH-ZOS and supply this module.
#
# It is a generic UNIX: Open XL defines __MVS__, which is what the
# source tests. Nothing here sets a compiler triple: this is a native
# build on the machine doing the compiling.

# The compiler is Open XL, a clang. CMake's own identification cannot
# read its version string, leaving CMAKE_C_COMPILER_ID empty and
# GNUInstallDirs unable to pick lib vs lib64. Setting it here is the
# supported way to tell CMake what it is working with.
set(CMAKE_C_COMPILER_ID Clang)
set(CMAKE_C_COMPILER_ID_RUN 1)
set(CMAKE_C_COMPILER_ID_TOOL "ibm-clang64")

# z/OS has no lib64: everything lives in lib/ under the prefix, and
# zopen follows that.
set(CMAKE_INSTALL_LIBDIR "lib" CACHE STRING "z/OS uses lib, not lib64")
set(CMAKE_INSTALL_LIBDIR "lib")

# 64-bit XPLINK is the default; the pointer is 8 bytes.
set(CMAKE_SIZEOF_VOID_P 8 CACHE STRING "XPLINK64")
