cmake_minimum_required(VERSION 3.20)
project(zksh VERSION 0.1.0 LANGUAGES C)

# zksh: a z/OS Korn shell. oksh 7.9 (pdksh lineage) as the engine, with a
# z/OS layer in src/zos/. See docs/direction.md for the rules and
# docs/merge.md for what came from where.
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
    if(ZKSH_CURSES_EXTRA_INCLUDE)
      list(APPEND CURSES_INCLUDE_DIRS "${ZKSH_CURSES_EXTRA_INCLUDE}")
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

# Every .c in src/ is part of the shell, except the z/OS-only files that
# live in src/zos/ and are added conditionally below.
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
endif()

if(ZKSH_STRICT)
  target_compile_options(zksh PRIVATE -Wall -Wextra -Werror)
else()
  target_compile_options(zksh PRIVATE -Wall -Wextra)
endif()

# ---- z/OS layer ------------------------------------------------------
# src/zos/ holds our code. zos_spawn.c is the spawnp() layer; the rest
# is being merged from zash (docs/merge.md, phase 1).

if(ZKSH_ZOS)
  target_sources(zksh PRIVATE ${ZKSH_SRC_DIR}/zos/zos_spawn.c)
  # _ALL_SOURCE: the z/OS "make everything visible" switch.
  # _XPLATFORM_SOURCE: BSD/X-Open interfaces such as flock() in
  # <sys/file.h> and the timeradd() family in <sys/time.h>.
  target_compile_definitions(zksh PRIVATE _ALL_SOURCE _XPLATFORM_SOURCE)
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

find_program(CLANG_FORMAT_EXE clang-format)
if(CLANG_FORMAT_EXE)
  add_custom_target(format
    COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror
      ${ZKSH_SOURCES} ${ZKSH_SRC_DIR}/zos/*.c
    COMMENT "clang-format check" VERBATIM)
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
