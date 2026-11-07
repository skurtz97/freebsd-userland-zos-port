cmake_minimum_required(VERSION 3.20)
project(zksh VERSION 0.1.0 LANGUAGES C)

# zksh: a z/OS Korn shell. oksh 7.9 (pdksh lineage) as the engine, with a
# z/OS layer in src/zos_builtins.c and src/zos_spawn.c.  See
# docs/direction.md for the rules and docs/merge.md for what came from
# where.
#
# Sources in src/ keep their upstream oksh names, so a rebase against
# vendor/oksh (ibara/oksh oksh-7.9) stays a mechanical diff.

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)        # oksh is not a strict -std=c99 tree

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ---- Options ---------------------------------------------------------

option(ZKSH_EDITOR "Build emacs/vi line editing" ON)
option(ZKSH_SMALL "Compile out optional features (-DSMALL)" OFF)
option(ZKSH_INSTALL_AS_KSH "Install the binary as ksh instead of zksh" OFF)
option(ZKSH_STRICT "Treat warnings as errors" OFF)
option(ZKSH_ZOS "Target z/OS UNIX (normally set by cmake/toolchain-zos.cmake)" OFF)

# ---- The shell -------------------------------------------------------

set(ZKSH_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ---- Curses (line editing) -------------------------------------------
# oksh probes -lcurses, -lncurses and -lncursesw. On z/OS the only
# terminal library is zopen's wide-character ncurses.
#
# This runs BEFORE pconfig.h is generated, because HAVE_CURSES in
# pconfig.h is what gates #include <curses.h> in emacs.c, vi.c and
# var.c. It cannot touch the target here -- the target does not exist
# yet -- so the results are applied further down.

if(ZKSH_EDITOR)
  # The z/OS toolchain may already have located the static, wide ncurses
  # that FindCurses cannot see; don't look for a second answer.
  if(CURSES_LIBRARY AND CURSES_INCLUDE_PATH)
    set(CURSES_FOUND TRUE)
    set(CURSES_LIBRARIES "${CURSES_LIBRARY}")
    set(CURSES_INCLUDE_DIRS "${CURSES_INCLUDE_PATH}")
    if(ZKSH_CURSES_SHIM)
      list(APPEND CURSES_INCLUDE_DIRS "${ZKSH_CURSES_SHIM}")
    endif()
  else()
    find_package(Curses)
  endif()
  if(NOT CURSES_FOUND)
    # A shell without line editing still builds; failing the whole
    # build because a terminal library was not found is the wrong trade.
    message(WARNING
      "zksh: no curses found, building WITHOUT line editing.\n"
      "       Set -DCURSES_INCLUDE_PATH=... -DCURSES_LIBRARY=... "
      "or --disable-curses to silence this.")
    set(ZKSH_EDITOR OFF)
  endif()
endif()

# Test invocation. Two host differences, both measured on z/OS:
#   - zksh writes IBM-1047 there, so the tests decode its output before
#     matching ASCII expectations (tests/run-c.sh, ZKSH_DECODE);
#   - /bin/sh cannot read this repo's UTF-8-tagged scripts at all
#     ("FSUM7332 syntax error: got (", with or without _BPXK_AUTOCVT),
#     so the runner is bash, which reads them as they are. bash is
#     development tooling here, not a runtime dependency of zksh.
if(ZKSH_ZOS)
  set(ZKSH_DECODE IBM-1047)
  find_program(ZKSH_TEST_SHELL NAMES bash HINTS
    /usr/local/zopen/usr/local/bin
    "${ZKSH_ZOPEN_ROOT}/usr/local/bin")
  if(NOT ZKSH_TEST_SHELL)
    message(WARNING
      "zksh: bash not found; ctest on z/OS needs it to run "
      "tests/run-c.sh (see docs/build.md).")
  endif()
else()
  set(ZKSH_DECODE "")
  find_program(ZKSH_TEST_SHELL NAMES sh HINTS /bin)
endif()
if(NOT ZKSH_TEST_SHELL)
  set(ZKSH_TEST_SHELL sh)
endif()

# Every .c in src/ is part of the shell.  src/zos_builtins.c is globbed
# with the rest (it compiles everywhere: off z/OS its builtins report
# "only available on z/OS"); src/zos_spawn.c is added conditionally
# below because it is all __MVS__ and empty elsewhere.
file(GLOB ZKSH_SOURCES CONFIGURE_DEPENDS ${ZKSH_SRC_DIR}/*.c)
list(SORT ZKSH_SOURCES)

# Feature checks; they generate pconfig.h through cmake/pconfig.h.in.
include(cmake/checks.cmake)

add_executable(zksh ${ZKSH_SOURCES})

target_include_directories(zksh PRIVATE
  ${ZKSH_SRC_DIR}
  ${CMAKE_CURRENT_BINARY_DIR})

target_compile_definitions(zksh PRIVATE
  $<$<BOOL:${ZKSH_EDITOR}>:EMACS VI>
  $<$<BOOL:${ZKSH_SMALL}>:SMALL>
  # oksh's configure adds -D_GNU_SOURCE on glibc; setresuid/setresgid
  # and other prototypes live behind it (surfaced as implicit
  # declaration errors once -w was dropped).
  $<$<PLATFORM_ID:Linux>: _GNU_SOURCE>)

# Apply the curses detection done above, now that the target exists.
if(ZKSH_EDITOR AND CURSES_FOUND)
  target_include_directories(zksh PRIVATE ${CURSES_INCLUDE_DIRS})
  # An absolute path to a static archive links as a file, which is what
  # z/OS needs (only libncursesw.a is installed, no shared object).
  if(CURSES_LIBRARY MATCHES "\\.a$")
    target_link_libraries(zksh PRIVATE "${CURSES_LIBRARY}")
  else()
    target_link_libraries(zksh PRIVATE ${CURSES_LIBRARIES})
  endif()
  message(STATUS "zksh: line editing with ${CURSES_LIBRARY}")
  # z/OS: libncursesw.a needs zoslib to bind (the ASCII runtime shims
  # and the C++ support its members reference). The toolchain locates
  # it and hands the archives over here; empty elsewhere.
  if(ZKSH_CURSES_LINK_ITEMS)
    target_link_libraries(zksh PRIVATE ${ZKSH_CURSES_LINK_ITEMS})
  endif()
endif()

if(ZKSH_STRICT)
  target_compile_options(zksh PRIVATE -Wall -Wextra -Werror)
else()
  target_compile_options(zksh PRIVATE -Wall -Wextra)
endif()

# ---- z/OS layer ------------------------------------------------------
# src/zos/sys_zos.c.ref is the zash donor for tagging and MVS data set
# redirection; it is a .ref, not a .c, precisely so the glob above never
# compiles it.  It is not buildable against oksh yet (see
# docs/zos-changes.md).


if(ZKSH_ZOS)
  # zos_spawn.c lives at src/ root, not src/zos/, so that main.c and
  # jobs.c can #include "zos_spawn.h" without an extra -I.
  target_sources(zksh PRIVATE ${ZKSH_SRC_DIR}/zos_spawn.c)
  # The ncurses link needs zoslib; see ZKSH_CURSES_LINK_ITEMS in
  # cmake/toolchain-zos.cmake and docs/port.md P24.
  # The z/OS headers gate interfaces on a stack of feature macros, and
  # each one hides different things:
  #   _ALL_SOURCE       the broad "make everything visible" switch
  #   _XPLATFORM_SOURCE BSD/X-Open: flock() in <sys/file.h>, the
  #                     timeradd() family in <sys/time.h>
  #   _OPEN_SYS         z/OS UNIX interfaces: setgroups() in <grp.h>
  #   _POSIX_C_SOURCE   POSIX.1-2008: strsignal() in <string.h>
  #
  # Deliberately NOT _UNIX03_SOURCE: it makes the headers emit the
  # __-prefixed LE entry points (__sysconf, __fopen_ascii), which a
  # statically linked program cannot resolve -- the binder reports
  # IEW2456E for each. _ALL_SOURCE already exposes setenv() under its
  # documented non-POSIX name, so SUSv3 is not needed for it.
  # docs/port.md records which interface needed which; AGENTS.txt 2a
  # keeps the list.
  target_compile_definitions(zksh PRIVATE
    _ALL_SOURCE _XPLATFORM_SOURCE _OPEN_SYS
    _POSIX_C_SOURCE=200809L)
endif()

# ---- Install ---------------------------------------------------------

if(ZKSH_INSTALL_AS_KSH)
  set(ZKSH_PROG ksh)
else()
  set(ZKSH_PROG zksh)
endif()

set_target_properties(zksh PROPERTIES OUTPUT_NAME ${ZKSH_PROG})

include(GNUInstallDirs)
install(TARGETS zksh RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/vendor/oksh/ksh.1
  DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
  RENAME ${ZKSH_PROG}.1)

# ---- Checks and formatting -------------------------------------------

# Format only the files this project writes.  Upstream oksh is not
# clang-formatted (2,992 violations in src/ at the 2026-11-06 pin), and
# reformatting it would make every future rebase a diff of whitespace.
# A zksh-written file that is not formatted is a real finding; an
# upstream one is not, so it is not checked here.
set(ZKSH_FORMAT_SOURCES
  ${ZKSH_SRC_DIR}/zos_builtins.c
  ${ZKSH_SRC_DIR}/zos_spawn.c
  ${ZKSH_SRC_DIR}/zos_spawn.h)

find_program(CLANG_FORMAT_EXE clang-format)
if(CLANG_FORMAT_EXE)
  add_custom_target(format
    COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror ${ZKSH_FORMAT_SOURCES}
    COMMENT "clang-format check (zksh-written files only)" VERBATIM)
endif()

find_program(CLANG_TIDY_EXE clang-tidy)
if(CLANG_TIDY_EXE)
  add_custom_target(tidy
    COMMAND ${CLANG_TIDY_EXE} -p ${CMAKE_BINARY_DIR}
      ${ZKSH_SOURCES}
    COMMENT "clang-tidy" VERBATIM)
endif()

enable_testing()
add_subdirectory(tests)
