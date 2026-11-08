cmake_minimum_required(VERSION 3.20)
project(freebsd_userland_zos_port VERSION 0.1.0 LANGUAGES C)

# fsh: FreeBSD bin/sh for z/OS UNIX, built from the FreeBSD userland
# source pin and a vendored FreeBSD contrib/libedit.  The project name
# is the repository name; the binary is fsh.

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "" FORCE)
endif()

option(FSH_STRICT "Treat warnings as errors" OFF)
option(FSH_ZOS "Target z/OS UNIX (normally set by cmake/toolchain-zos.cmake)" OFF)
option(FSH_WITH_LIBEDIT "Build the vendored FreeBSD libedit" ON)

set(FSH_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(FSH_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
set(FSH_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(FSH_LIBEDIT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/vendor/freebsd/contrib/libedit)
set(FSH_LIBEDIT_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/libedit-generated)
set(FSH_LIBEDIT_STAGE ${CMAKE_CURRENT_BINARY_DIR}/libedit-staged)
file(MAKE_DIRECTORY ${FSH_GEN_DIR} ${FSH_LIBEDIT_GEN_DIR})

find_program(FSH_BUILD_SHELL NAMES bash sh)
if(NOT FSH_BUILD_SHELL)
  set(FSH_BUILD_SHELL sh)
endif()

# ---- Curses and libedit ---------------------------------------------

if(FSH_WITH_LIBEDIT)
  if(FSH_ZOS)
    # The z/OS toolchain locates zopen's static wide ncurses and passes
    # CURSES_LIBRARY / CURSES_INCLUDE_PATH.  If it did not, build
    # without line editing rather than failing the whole shell.
    if(CURSES_LIBRARY)
      set(CURSES_LIBRARIES "${CURSES_LIBRARY}")
    endif()
    if(NOT CURSES_LIBRARIES)
      message(WARNING
        "fsh: no z/OS ncurses found; building without libedit/history.")
      set(FSH_WITH_LIBEDIT OFF)
    endif()
  else()
    find_package(Curses REQUIRED)
  endif()
endif()

if(FSH_WITH_LIBEDIT)
  include(CheckIncludeFile)
  include(CheckFunctionExists)
  include(CheckStructHasMember)
  if(NOT FSH_ZOS)
    set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
  endif()
  check_include_file(curses.h FSH_LIBEDIT_HAVE_CURSES_H)
  check_include_file(ncurses.h FSH_LIBEDIT_HAVE_NCURSES_H)
  check_include_file(termcap.h FSH_LIBEDIT_HAVE_TERMCAP_H)
  check_include_file(term.h FSH_LIBEDIT_HAVE_TERM_H)
  check_include_file(sys/cdefs.h FSH_LIBEDIT_HAVE_SYS_CDEFS_H)
  check_function_exists(getpwnam_r FSH_LIBEDIT_HAVE_GETPW_R_POSIX)
  check_function_exists(issetugid FSH_LIBEDIT_HAVE_ISSETUGID)
  check_struct_has_member("struct dirent" d_namlen dirent.h
    FSH_LIBEDIT_HAVE_DIRENT_D_NAMLEN)

  set(HAVE_CURSES_H ${FSH_LIBEDIT_HAVE_CURSES_H})
  set(HAVE_NCURSES_H ${FSH_LIBEDIT_HAVE_NCURSES_H})
  set(HAVE_TERMCAP_H ${FSH_LIBEDIT_HAVE_TERMCAP_H})
  set(HAVE_TERM_H ${FSH_LIBEDIT_HAVE_TERM_H})
  set(HAVE_SYS_CDEFS_H ${FSH_LIBEDIT_HAVE_SYS_CDEFS_H})
  set(HAVE_GETPW_R_POSIX ${FSH_LIBEDIT_HAVE_GETPW_R_POSIX})
  set(HAVE_GETPW_R_DRAFT 0)
  set(HAVE_ISSETUGID ${FSH_LIBEDIT_HAVE_ISSETUGID})
  set(HAVE_STRUCT_DIRENT_D_NAMLEN ${FSH_LIBEDIT_HAVE_DIRENT_D_NAMLEN})
  # FreeBSD ships config.h checked in. Linux needs different answers,
  # and the C preprocessor resolves "config.h" from the .c's own
  # directory first, so the build stages a copy of the vendor source
  # with the generated config.h dropped in. The submodule stays clean;
  # on z/OS the staged copy gets the z/OS config.h instead.
  file(REMOVE_RECURSE ${FSH_LIBEDIT_STAGE})
  file(COPY ${FSH_LIBEDIT_DIR}/ DESTINATION ${FSH_LIBEDIT_STAGE}
    FILES_MATCHING PATTERN "*")
  configure_file(cmake/libedit-config.h.in
    ${FSH_LIBEDIT_STAGE}/config.h @ONLY)

  set(FSH_LIBEDIT_SOURCES
    ${FSH_LIBEDIT_STAGE}/chared.c
    ${FSH_LIBEDIT_STAGE}/chartype.c
    ${FSH_LIBEDIT_STAGE}/common.c
    ${FSH_LIBEDIT_STAGE}/el.c
    ${FSH_LIBEDIT_STAGE}/eln.c
    ${FSH_LIBEDIT_STAGE}/emacs.c
    ${FSH_LIBEDIT_STAGE}/filecomplete.c
    ${FSH_LIBEDIT_STAGE}/hist.c
    ${FSH_LIBEDIT_STAGE}/history.c
    ${FSH_LIBEDIT_STAGE}/historyn.c
    ${FSH_LIBEDIT_STAGE}/keymacro.c
    ${FSH_LIBEDIT_STAGE}/literal.c
    ${FSH_LIBEDIT_STAGE}/map.c
    ${FSH_LIBEDIT_STAGE}/parse.c
    ${FSH_LIBEDIT_STAGE}/prompt.c
    ${FSH_LIBEDIT_STAGE}/read.c
    ${FSH_LIBEDIT_STAGE}/readline.c
    ${FSH_LIBEDIT_STAGE}/refresh.c
    ${FSH_LIBEDIT_STAGE}/search.c
    ${FSH_LIBEDIT_STAGE}/sig.c
    ${FSH_LIBEDIT_STAGE}/terminal.c
    ${FSH_LIBEDIT_STAGE}/tokenizer.c
    ${FSH_LIBEDIT_STAGE}/tokenizern.c
    ${FSH_LIBEDIT_STAGE}/tty.c
    ${FSH_LIBEDIT_STAGE}/vi.c)

  function(fsh_libedit_header out mode inputs)
    add_custom_command(OUTPUT ${FSH_LIBEDIT_GEN_DIR}/${out}
      COMMAND ${CMAKE_COMMAND}
        -DMAKELIST=${FSH_LIBEDIT_STAGE}/makelist
        -DOUTPUT=${FSH_LIBEDIT_GEN_DIR}/${out}
        -DMODE=${mode}
        "-DINPUTS=${inputs}"
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen-libedit-header.cmake
      DEPENDS ${FSH_LIBEDIT_STAGE}/makelist ${ARGN}
      VERBATIM)
  endfunction()

  fsh_libedit_header(vi.h -h "${FSH_LIBEDIT_STAGE}/vi.c"
    ${FSH_LIBEDIT_STAGE}/vi.c)
  fsh_libedit_header(emacs.h -h "${FSH_LIBEDIT_STAGE}/emacs.c"
    ${FSH_LIBEDIT_STAGE}/emacs.c)
  fsh_libedit_header(common.h -h "${FSH_LIBEDIT_STAGE}/common.c"
    ${FSH_LIBEDIT_STAGE}/common.c)
  fsh_libedit_header(fcns.h -fh
    "${FSH_LIBEDIT_GEN_DIR}/vi.h|${FSH_LIBEDIT_GEN_DIR}/emacs.h|${FSH_LIBEDIT_GEN_DIR}/common.h"
    ${FSH_LIBEDIT_GEN_DIR}/vi.h ${FSH_LIBEDIT_GEN_DIR}/emacs.h
    ${FSH_LIBEDIT_GEN_DIR}/common.h)
  fsh_libedit_header(func.h -fc
    "${FSH_LIBEDIT_GEN_DIR}/vi.h|${FSH_LIBEDIT_GEN_DIR}/emacs.h|${FSH_LIBEDIT_GEN_DIR}/common.h"
    ${FSH_LIBEDIT_GEN_DIR}/vi.h ${FSH_LIBEDIT_GEN_DIR}/emacs.h
    ${FSH_LIBEDIT_GEN_DIR}/common.h)
  fsh_libedit_header(help.h -bh
    "${FSH_LIBEDIT_STAGE}/vi.c|${FSH_LIBEDIT_STAGE}/emacs.c|${FSH_LIBEDIT_STAGE}/common.c"
    ${FSH_LIBEDIT_STAGE}/vi.c ${FSH_LIBEDIT_STAGE}/emacs.c
    ${FSH_LIBEDIT_STAGE}/common.c)

  set(FSH_LIBEDIT_GENERATED
    ${FSH_LIBEDIT_GEN_DIR}/vi.h
    ${FSH_LIBEDIT_GEN_DIR}/emacs.h
    ${FSH_LIBEDIT_GEN_DIR}/common.h
    ${FSH_LIBEDIT_GEN_DIR}/fcns.h
    ${FSH_LIBEDIT_GEN_DIR}/func.h
    ${FSH_LIBEDIT_GEN_DIR}/help.h)

  add_library(edit STATIC ${FSH_LIBEDIT_SOURCES} ${FSH_LIBEDIT_GENERATED})
  target_include_directories(edit
    PRIVATE ${FSH_LIBEDIT_GEN_DIR} ${CURSES_INCLUDE_DIRS}
      ${FSH_SRC_DIR}/compat ${FSH_LIBEDIT_STAGE}
    PUBLIC ${FSH_LIBEDIT_STAGE} ${FSH_INCLUDE_DIR})
  if(FSH_ZOS)
    target_include_directories(edit PRIVATE ${FSH_SRC_DIR}/compat/zos)
  endif()
  target_link_libraries(edit PUBLIC ${CURSES_LIBRARIES}
    ${FSH_CURSES_LINK_ITEMS})
  if(NOT FSH_ZOS)
    target_compile_definitions(edit PRIVATE _GNU_SOURCE)
  else()
    # libedit needs the same z/OS feature macros as fsh itself:
    # getline() and SIGWINCH are hidden without them.
    #
    # z/OS wchar_t holds EBCDIC code points rather than ISO 10646.
    # libedit guards against non-ASCII-compatible wchar_t because its
    # editing code assumes the character and multibyte encodings agree;
    # on z/OS its literals, input and mbrtowc/wcrtomb conversions all use
    # the same EBCDIC locale, so the assumption holds well enough to
    # build and run. Tell libedit's chartype.h not to reject it.
    target_compile_definitions(edit PRIVATE
      _ALL_SOURCE _XPLATFORM_SOURCE _OPEN_SYS _OPEN_SYS_FILE_EXT
      _POSIX_C_SOURCE=200809L
      __STDC_ISO_10646__=201706L)
  endif()
endif()

# ---- FreeBSD sh generators ------------------------------------------

# The generators are EBCDIC programs on z/OS; the shell generator
# scripts use awk/sed/tr, which mix EBCDIC output with bash's ASCII
# here-documents.  Two rules keep the generated C readable by Open XL,
# which accepts UTF-8 source only:
#
#   mknodes/mksyntax  read/write EBCDIC, so convert their inputs and
#                     outputs with iconv.
#   mkbuiltins/mktokens run with the zopen GNU text tools (gawk, gsed,
#                     gtr, ggrep, gwc), which emit UTF-8 bytes, then tag
#                     the result UTF-8.
if(FSH_ZOS)
  find_program(FSH_ICONV NAMES iconv)
  find_program(FSH_CHTAG NAMES chtag)
  find_program(FSH_GAWK NAMES gawk)
  find_program(FSH_GSED NAMES gsed)
  find_program(FSH_GTR NAMES gtr)
  find_program(FSH_GGREP NAMES ggrep)
  find_program(FSH_GWC NAMES gwc)
  foreach(_tool ICONV CHTAG GAWK GSED GTR GGREP GWC)
    if(NOT FSH_${_tool})
      message(FATAL_ERROR
        "z/OS build needs ${_tool} (zopen coreutils/gawk)")
    endif()
  endforeach()

  set(FSH_ZOS_GNU_BIN ${FSH_GEN_DIR}/gnubin)
  file(MAKE_DIRECTORY ${FSH_ZOS_GNU_BIN})
  file(CREATE_LINK ${FSH_GAWK} ${FSH_ZOS_GNU_BIN}/awk SYMBOLIC)
  file(CREATE_LINK ${FSH_GSED} ${FSH_ZOS_GNU_BIN}/sed SYMBOLIC)
  file(CREATE_LINK ${FSH_GTR} ${FSH_ZOS_GNU_BIN}/tr SYMBOLIC)
  file(CREATE_LINK ${FSH_GGREP} ${FSH_ZOS_GNU_BIN}/grep SYMBOLIC)
  file(CREATE_LINK ${FSH_GWC} ${FSH_ZOS_GNU_BIN}/wc SYMBOLIC)
  set(FSH_GEN_ENV ${CMAKE_COMMAND} -E env
    "PATH=${FSH_ZOS_GNU_BIN}:$ENV{PATH}")

  set(FSH_NODETYPES ${FSH_GEN_DIR}/nodetypes)
  set(FSH_NODES_PAT ${FSH_GEN_DIR}/nodes.c.pat)
  foreach(_pair "${FSH_SRC_DIR}/nodetypes;${FSH_NODETYPES}"
                "${FSH_SRC_DIR}/nodes.c.pat;${FSH_NODES_PAT}")
    list(GET _pair 0 _in)
    list(GET _pair 1 _out)
    get_filename_component(_name "${_out}" NAME)
    add_custom_command(OUTPUT ${_out}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${FSH_GEN_DIR}
      COMMAND ${CMAKE_COMMAND} -DICONV=${FSH_ICONV}
        -DINPUT=${_in} -DOUTPUT=${_out}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-convert.cmake
      DEPENDS ${_in} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-convert.cmake
      COMMENT "Converting ${_name} to IBM-1047"
      VERBATIM)
  endforeach()
else()
  set(FSH_NODETYPES ${FSH_SRC_DIR}/nodetypes)
  set(FSH_NODES_PAT ${FSH_SRC_DIR}/nodes.c.pat)
endif()

add_executable(mknodes ${FSH_SRC_DIR}/mknodes.c)
add_executable(mksyntax ${FSH_SRC_DIR}/mksyntax.c)
foreach(tool mknodes mksyntax)
  target_include_directories(${tool} PRIVATE
    ${FSH_SRC_DIR} ${FSH_SRC_DIR}/compat)
  # FreeBSD's generator sources use __unused/__printf0like/__dead2.
  # Linux has no FreeBSD <sys/cdefs.h>, and z/OS does not supply these
  # names at all, so use the compat header on both hosts.
  target_compile_options(${tool} PRIVATE
    -include ${FSH_SRC_DIR}/compat/bsd.h)
endforeach()

if(FSH_ZOS)
  set(FSH_ZOS_UTF8 ${CMAKE_COMMAND}
    -DICONV=${FSH_ICONV} -DCHTAG=${FSH_CHTAG})
  set(FSH_ZOS_TAG_UTF8 ${FSH_CHTAG} -tc UTF-8)
else()
  set(FSH_ZOS_UTF8 ${CMAKE_COMMAND})
  set(FSH_ZOS_TAG_UTF8 ${CMAKE_COMMAND} -E echo_append)
endif()

add_custom_command(OUTPUT ${FSH_GEN_DIR}/nodes.c ${FSH_GEN_DIR}/nodes.h
  COMMAND ${CMAKE_COMMAND} -E make_directory ${FSH_GEN_DIR}
  COMMAND $<TARGET_FILE:mknodes> ${FSH_NODETYPES} ${FSH_NODES_PAT}
  COMMAND ${FSH_ZOS_UTF8} "-DFILES=${FSH_GEN_DIR}/nodes.c;${FSH_GEN_DIR}/nodes.h"
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-utf8-inplace.cmake
  DEPENDS mknodes ${FSH_NODETYPES} ${FSH_NODES_PAT}
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-utf8-inplace.cmake
  WORKING_DIRECTORY ${FSH_GEN_DIR}
  VERBATIM)

add_custom_command(OUTPUT ${FSH_GEN_DIR}/syntax.c ${FSH_GEN_DIR}/syntax.h
  COMMAND ${CMAKE_COMMAND} -E make_directory ${FSH_GEN_DIR}
  COMMAND $<TARGET_FILE:mksyntax>
  COMMAND ${FSH_ZOS_UTF8} "-DFILES=${FSH_GEN_DIR}/syntax.c;${FSH_GEN_DIR}/syntax.h"
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-utf8-inplace.cmake
  DEPENDS mksyntax ${CMAKE_CURRENT_SOURCE_DIR}/cmake/zos-utf8-inplace.cmake
  WORKING_DIRECTORY ${FSH_GEN_DIR}
  VERBATIM)

add_custom_command(OUTPUT ${FSH_GEN_DIR}/token.h
  COMMAND ${CMAKE_COMMAND} -E make_directory ${FSH_GEN_DIR}
  COMMAND ${FSH_GEN_ENV} ${FSH_BUILD_SHELL} ${FSH_SRC_DIR}/mktokens
  COMMAND ${FSH_ZOS_TAG_UTF8} ${FSH_GEN_DIR}/token.h
  DEPENDS ${FSH_SRC_DIR}/mktokens
  WORKING_DIRECTORY ${FSH_GEN_DIR}
  VERBATIM)

add_custom_command(OUTPUT ${FSH_GEN_DIR}/builtins.c ${FSH_GEN_DIR}/builtins.h
  COMMAND ${CMAKE_COMMAND} -E make_directory ${FSH_GEN_DIR}
  COMMAND ${FSH_GEN_ENV} ${FSH_BUILD_SHELL} ${FSH_SRC_DIR}/mkbuiltins ${FSH_SRC_DIR}
  COMMAND ${FSH_ZOS_TAG_UTF8} ${FSH_GEN_DIR}/builtins.c ${FSH_GEN_DIR}/builtins.h
  DEPENDS ${FSH_SRC_DIR}/mkbuiltins ${FSH_SRC_DIR}/builtins.def
    ${FSH_SRC_DIR}/shell.h
  WORKING_DIRECTORY ${FSH_GEN_DIR}
  VERBATIM)

# ---- fsh -------------------------------------------------------------

set(FSH_SOURCES
  ${FSH_SRC_DIR}/alias.c
  ${FSH_SRC_DIR}/arith_yacc.c
  ${FSH_SRC_DIR}/arith_yylex.c
  ${FSH_SRC_DIR}/cd.c
  ${FSH_SRC_DIR}/bltin/echo.c
  ${FSH_SRC_DIR}/error.c
  ${FSH_SRC_DIR}/eval.c
  ${FSH_SRC_DIR}/exec.c
  ${FSH_SRC_DIR}/expand.c
  ${FSH_SRC_DIR}/histedit.c
  ${FSH_SRC_DIR}/input.c
  ${FSH_SRC_DIR}/jobs.c
  ${FSH_SRC_DIR}/kill.c
  ${FSH_SRC_DIR}/mail.c
  ${FSH_SRC_DIR}/main.c
  ${FSH_SRC_DIR}/memalloc.c
  ${FSH_SRC_DIR}/miscbltin.c
  ${FSH_SRC_DIR}/mystring.c
  ${FSH_SRC_DIR}/options.c
  ${FSH_SRC_DIR}/output.c
  ${FSH_SRC_DIR}/parser.c
  ${FSH_SRC_DIR}/printf.c
  ${FSH_SRC_DIR}/redir.c
  ${FSH_SRC_DIR}/show.c
  ${FSH_SRC_DIR}/test.c
  ${FSH_SRC_DIR}/trap.c
  ${FSH_SRC_DIR}/var.c
  ${FSH_SRC_DIR}/zos_syscvt.c
  ${FSH_SRC_DIR}/compat/btemp.c
  ${FSH_SRC_DIR}/compat/setmode.c
  ${FSH_SRC_DIR}/compat/strlcpy.c
  ${FSH_SRC_DIR}/compat/vis.c
  ${FSH_GEN_DIR}/builtins.c
  ${FSH_GEN_DIR}/nodes.c
  ${FSH_GEN_DIR}/syntax.c)

add_executable(fsh ${FSH_SOURCES}
  ${FSH_GEN_DIR}/builtins.h
  ${FSH_GEN_DIR}/nodes.h
  ${FSH_GEN_DIR}/syntax.h
  ${FSH_GEN_DIR}/token.h)

target_include_directories(fsh PRIVATE
  ${FSH_SRC_DIR}
  ${FSH_SRC_DIR}/bltin
  ${FSH_SRC_DIR}/compat
  ${FSH_INCLUDE_DIR})
# The generated headers are included with quotes. Keep them out of the
# angle-bracket search path: z/OS <stdlib.h> itself includes a system
# <builtins.h>, which would otherwise pick up the shell's generated one.
target_compile_options(fsh PRIVATE -iquote ${FSH_GEN_DIR})
if(FSH_ZOS)
  # z/OS has no <sys/param.h>, and its <wchar.h> has no wcsdup().
  target_include_directories(fsh PRIVATE ${FSH_SRC_DIR}/compat/zos)
endif()
target_compile_definitions(fsh PRIVATE SHELL)
target_compile_options(fsh PRIVATE
  -include ${FSH_SRC_DIR}/compat/bsd.h)
if(FSH_WITH_LIBEDIT)
  target_include_directories(fsh PRIVATE ${FSH_LIBEDIT_DIR})
  target_link_libraries(fsh PRIVATE edit)
else()
  target_compile_definitions(fsh PRIVATE NO_HISTORY)
endif()
if(NOT FSH_ZOS)
  target_compile_definitions(fsh PRIVATE _GNU_SOURCE)
else()
  target_compile_definitions(fsh PRIVATE
    _ALL_SOURCE _XPLATFORM_SOURCE _OPEN_SYS _OPEN_SYS_FILE_EXT
    _POSIX_C_SOURCE=200809L)
endif()
if(FSH_STRICT)
  target_compile_options(fsh PRIVATE -Wall -Wextra -Werror)
else()
  target_compile_options(fsh PRIVATE -Wall -Wextra)
endif()

include(GNUInstallDirs)
install(TARGETS fsh RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/man/fsh.1
  DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
  RENAME fsh.1)

# ---- Checks ----------------------------------------------------------

# Every shell script this project writes is POSIX sh, including the test
# scripts. A test may deliberately exercise a non-POSIX construct; those
# lines carry a narrow shellcheck disable with the reason next to them.
file(GLOB FSH_SHELL_SCRIPTS CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/bench/*.sh)
list(APPEND FSH_SHELL_SCRIPTS
  ${CMAKE_CURRENT_SOURCE_DIR}/configure
  ${CMAKE_CURRENT_SOURCE_DIR}/tests/harness)
list(REMOVE_DUPLICATES FSH_SHELL_SCRIPTS)

find_program(SHELLCHECK_EXE shellcheck)
if(SHELLCHECK_EXE)
  add_custom_target(shellcheck
    COMMAND ${SHELLCHECK_EXE} --shell=sh ${FSH_SHELL_SCRIPTS}
    COMMENT "shellcheck (POSIX sh) on all project shell scripts" VERBATIM)
endif()

# ---- Reference shell and benchmark ----------------------------------
# The vendored FreeBSD sh is kept as the pristine benchmark reference.
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
      COMMENT "Benchmarking fsh against pristine FreeBSD sh"
      VERBATIM)
  else()
    message(WARNING
      "fsh: bash not found; the 'bench' target needs it (bench/run.sh).")
  endif()
endif()

enable_testing()
add_subdirectory(tests)
