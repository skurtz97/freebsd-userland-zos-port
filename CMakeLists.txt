cmake_minimum_required(VERSION 3.20)
project(freebsd_userland_zos_port VERSION 0.1.0 LANGUAGES C)

# fsh: a z/OS Korn shell. oksh 7.9 (pdksh lineage) as the engine, with a
# z/OS layer in src/zos_builtins.c and src/zos_spawn.c.  See
# docs/direction.md for the rules and docs/merge.md for what came from
# where.
#
# Sources in src/ keep their upstream oksh names, so a rebase against the
# oksh-7.9 pin (docs/merge.md) stays a mechanical diff. The oksh, dash and
# ksh93 vendor checkouts were removed after the benchmark answered its
# question; only the FreeBSD sh reference is kept.

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)        # oksh is not a strict -std=c99 tree

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ---- Options ---------------------------------------------------------

option(FSH_EDITOR "Build emacs/vi line editing" ON)
option(FSH_SMALL "Compile out optional features (-DSMALL)" OFF)
option(FSH_INSTALL_AS_KSH "Install the binary as ksh instead of fsh" OFF)
option(FSH_STRICT "Treat warnings as errors" OFF)
option(FSH_ZOS "Target z/OS UNIX (normally set by cmake/toolchain-zos.cmake)" OFF)

# ---- The shell -------------------------------------------------------

set(FSH_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ---- Curses (line editing) -------------------------------------------
# oksh probes -lcurses, -lncurses and -lncursesw. On z/OS the only
# terminal library is zopen's wide-character ncurses.
#
# This runs BEFORE pconfig.h is generated, because HAVE_CURSES in
# pconfig.h is what gates #include <curses.h> in emacs.c, vi.c and
# var.c. It cannot touch the target here -- the target does not exist
# yet -- so the results are applied further down.

if(FSH_EDITOR)
  # The z/OS toolchain may already have located the static, wide ncurses
  # that FindCurses cannot see; don't look for a second answer.
  if(CURSES_LIBRARY AND CURSES_INCLUDE_PATH)
    set(CURSES_FOUND TRUE)
    set(CURSES_LIBRARIES "${CURSES_LIBRARY}")
    set(CURSES_INCLUDE_DIRS "${CURSES_INCLUDE_PATH}")
    if(FSH_CURSES_SHIM)
      list(APPEND CURSES_INCLUDE_DIRS "${FSH_CURSES_SHIM}")
    endif()
  else()
    find_package(Curses)
  endif()
  if(NOT CURSES_FOUND)
    # A shell without line editing still builds; failing the whole
    # build because a terminal library was not found is the wrong trade.
    message(WARNING
      "fsh: no curses found, building WITHOUT line editing.\n"
      "       Set -DCURSES_INCLUDE_PATH=... -DCURSES_LIBRARY=... "
      "or --disable-curses to silence this.")
    set(FSH_EDITOR OFF)
  endif()
endif()

# Test invocation. Three host differences, all measured on z/OS:
#   - fsh writes IBM-1047 there, so the tests decode its output before
#     matching ASCII expectations (tests/run-c.sh, FSH_DECODE);
#   - fsh *reads* IBM-1047 there, and an EBCDIC shell cannot parse
#     ASCII bytes as shell syntax, so each test script is converted to
#     IBM-1047 before the shell sees it (tests/run.sh, FSH_ENCODE);
#   - /bin/sh cannot read this repo's UTF-8-tagged scripts at all
#     ("FSUM7332 syntax error: got (", with or without _BPXK_AUTOCVT),
#     so the runner is bash, which reads them as they are. bash is
#     development tooling here, not a runtime dependency of fsh.
if(FSH_ZOS)
  set(FSH_DECODE IBM-1047)
  set(FSH_ENCODE IBM-1047)
  find_program(FSH_TEST_SHELL NAMES bash HINTS
    /usr/local/zopen/usr/local/bin
    "${FSH_ZOPEN_ROOT}/usr/local/bin")
  if(NOT FSH_TEST_SHELL)
    message(WARNING
      "fsh: bash not found; ctest on z/OS needs it to run "
      "tests/run-c.sh (see docs/build.md).")
  endif()
else()
  set(FSH_DECODE "")
  set(FSH_ENCODE "")
  find_program(FSH_TEST_SHELL NAMES sh HINTS /bin)
endif()
if(NOT FSH_TEST_SHELL)
  set(FSH_TEST_SHELL sh)
endif()

# Every .c in src/ is part of the shell.  src/zos_builtins.c is globbed
# with the rest (it compiles everywhere: off z/OS its builtins report
# "only available on z/OS"); src/zos_spawn.c is added conditionally
# below because it is all __MVS__ and empty elsewhere.
file(GLOB FSH_SOURCES CONFIGURE_DEPENDS ${FSH_SRC_DIR}/*.c)
list(SORT FSH_SOURCES)

# Feature checks; they generate pconfig.h through cmake/pconfig.h.in.
include(cmake/checks.cmake)

add_executable(fsh ${FSH_SOURCES})

target_include_directories(fsh PRIVATE
  ${FSH_SRC_DIR}
  ${CMAKE_CURRENT_BINARY_DIR})

target_compile_definitions(fsh PRIVATE
  $<$<BOOL:${FSH_EDITOR}>:EMACS VI>
  $<$<BOOL:${FSH_SMALL}>:SMALL>
  # oksh's configure adds -D_GNU_SOURCE on glibc; setresuid/setresgid
  # and other prototypes live behind it (surfaced as implicit
  # declaration errors once -w was dropped).
  $<$<PLATFORM_ID:Linux>: _GNU_SOURCE>)

# Apply the curses detection done above, now that the target exists.
if(FSH_EDITOR AND CURSES_FOUND)
  target_include_directories(fsh PRIVATE ${CURSES_INCLUDE_DIRS})
  # An absolute path to a static archive links as a file, which is what
  # z/OS needs (only libncursesw.a is installed, no shared object).
  if(CURSES_LIBRARY MATCHES "\\.a$")
    target_link_libraries(fsh PRIVATE "${CURSES_LIBRARY}")
  else()
    target_link_libraries(fsh PRIVATE ${CURSES_LIBRARIES})
  endif()
  message(STATUS "fsh: line editing with ${CURSES_LIBRARY}")
  # z/OS: libncursesw.a needs zoslib to bind (the ASCII runtime shims
  # and the C++ support its members reference). The toolchain locates
  # it and hands the archives over here; empty elsewhere.
  if(FSH_CURSES_LINK_ITEMS)
    target_link_libraries(fsh PRIVATE ${FSH_CURSES_LINK_ITEMS})
  endif()
endif()

if(FSH_STRICT)
  target_compile_options(fsh PRIVATE -Wall -Wextra -Werror)
else()
  target_compile_options(fsh PRIVATE -Wall -Wextra)
endif()

# ---- z/OS layer ------------------------------------------------------
# src/zos/sys_zos.c.ref is the zash donor for tagging and MVS data set
# redirection; it is a .ref, not a .c, precisely so the glob above never
# compiles it.  It is not buildable against oksh yet (see
# docs/zos-changes.md).


if(FSH_ZOS)
  # zos_spawn.c lives at src/ root, not src/zos/, so that main.c and
  # jobs.c can #include "zos_spawn.h" without an extra -I.
  target_sources(fsh PRIVATE ${FSH_SRC_DIR}/zos_spawn.c)
  # The ncurses link needs zoslib; see FSH_CURSES_LINK_ITEMS in
  # cmake/toolchain-zos.cmake and docs/port.md P24.
  # The z/OS headers gate interfaces on a stack of feature macros, and
  # each one hides different things:
  #   _ALL_SOURCE       the broad "make everything visible" switch
  #   _XPLATFORM_SOURCE BSD/X-Open: flock() in <sys/file.h>, the
  #                     timeradd() family in <sys/time.h>
  #   _OPEN_SYS         z/OS UNIX interfaces: setgroups() in <grp.h>
  #   _POSIX_C_SOURCE   POSIX.1-2008: strsignal() in <string.h>
  #   _OPEN_SYS_FILE_EXT  extended file data: struct stat's st_tag
  #                     (ft_ccsid, ft_txtflag) and <fcntl.h>'s F_SETTAG,
  #                     F_CONTROL_CVT -- zos_builtins.c's chtag -p
  #
  # AGENTS.txt 2a lists the macros with the interface each one hides.
  #
  # Deliberately NOT _UNIX03_SOURCE: it makes the headers emit the
  # __-prefixed LE entry points (__sysconf, __fopen_ascii), which a
  # statically linked program cannot resolve -- the binder reports
  # IEW2456E for each. _ALL_SOURCE already exposes setenv() under its
  # documented non-POSIX name, so SUSv3 is not needed for it.
  # docs/port.md records which interface needed which; AGENTS.txt 2a
  # keeps the list.
  target_compile_definitions(fsh PRIVATE
    _ALL_SOURCE _XPLATFORM_SOURCE _OPEN_SYS _OPEN_SYS_FILE_EXT
    _POSIX_C_SOURCE=200809L)
endif()

# ---- Install ---------------------------------------------------------

if(FSH_INSTALL_AS_KSH)
  set(FSH_PROG ksh)
else()
  set(FSH_PROG fsh)
endif()

set_target_properties(fsh PROPERTIES OUTPUT_NAME ${FSH_PROG})

include(GNUInstallDirs)
install(TARGETS fsh RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
# No man page is installed yet. The copied oksh ksh.1 was removed when
# the FreeBSD sh port became the candidate foundation: it documents the
# old base, not fsh or the FreeBSD userland port. Write man/fsh.1 once
# the base decision is settled; FreeBSD sh's own page stays in the
# vendor submodule at bin/sh/sh.1.

# ---- Checks and formatting -------------------------------------------

# Format only the files this project writes.  Upstream oksh is not
# clang-formatted (2,992 violations in src/ at the 2026-11-06 pin), and
# reformatting it would make every future rebase a diff of whitespace.
# An fsh-written file that is not formatted is a real finding; an
# upstream one is not, so it is not checked here.
set(FSH_FORMAT_SOURCES
  ${FSH_SRC_DIR}/zos_builtins.c
  ${FSH_SRC_DIR}/zos_spawn.c
  ${FSH_SRC_DIR}/zos_spawn.h)

find_program(CLANG_FORMAT_EXE clang-format)
if(CLANG_FORMAT_EXE)
  add_custom_target(format
    COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror ${FSH_FORMAT_SOURCES}
    COMMENT "clang-format check (fsh-written files only)" VERBATIM)
endif()

find_program(CLANG_TIDY_EXE clang-tidy)
if(CLANG_TIDY_EXE)
  add_custom_target(tidy
    COMMAND ${CLANG_TIDY_EXE} -p ${CMAKE_BINARY_DIR}
      ${FSH_SOURCES}
    COMMENT "clang-tidy" VERBATIM)
endif()

# Every shell script this project writes is POSIX sh, including the test
# scripts. A test may deliberately exercise a non-POSIX construct; those
# lines carry a narrow shellcheck disable with the reason next to them.
file(GLOB FSH_SHELL_SCRIPTS CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/bench/*.sh
  ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.sh)
list(APPEND FSH_SHELL_SCRIPTS ${CMAKE_CURRENT_SOURCE_DIR}/configure)
list(REMOVE_DUPLICATES FSH_SHELL_SCRIPTS)

find_program(SHELLCHECK_EXE shellcheck)
if(SHELLCHECK_EXE)
  add_custom_target(shellcheck
    COMMAND ${SHELLCHECK_EXE} --shell=sh ${FSH_SHELL_SCRIPTS}
    COMMENT "shellcheck (POSIX sh) on all project shell scripts" VERBATIM)
endif()

# ---- Reference shell and benchmark ----------------------------------
# The vendored FreeBSD sh is the benchmark reference, not part of fsh.
# It is built out of tree by bench/build-refs.sh and is never installed.
# The target is omitted on z/OS: there is no second shell to build there.
if(NOT FSH_ZOS)
  add_custom_target(refshells
    COMMAND ${CMAKE_COMMAND} -E env FSH_REF_BUILD=${CMAKE_BINARY_DIR}/refs
      /bin/sh ${CMAKE_CURRENT_SOURCE_DIR}/bench/build-refs.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building the vendored FreeBSD sh reference"
    VERBATIM)

  find_program(BASH_EXECUTABLE bash)
  if(BASH_EXECUTABLE)
    add_custom_target(bench
      COMMAND ${BASH_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/bench/run.sh
        $<TARGET_FILE:fsh>
        ${CMAKE_BINARY_DIR}/refs/bin/freebsd-sh
      DEPENDS fsh refshells
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMENT "Benchmarking fsh against FreeBSD sh"
      VERBATIM)
  else()
    message(WARNING
      "fsh: bash not found; the 'bench' target needs it (bench/run.sh).")
  endif()
endif()

enable_testing()
add_subdirectory(tests)
