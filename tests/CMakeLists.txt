# Tests.
#
# Two layers:
#
#   smoke_*  one-line checks that the shell starts and the POSIX basics
#            evaluate.  They catch "the build produced a broken binary",
#            which a script test can hide behind a later failure.
#
#   regression_*  tests/<name>.sh run under the shell being tested,
#            compared against tests/<name>.out by tests/run.sh.  $T is
#            a private temporary directory and $SH the shell under test;
#            the runner harness pipes commands in.
#
# The old oksh script suite (param.sh, zos.sh, ...) still stands for the
# Korn-shell dialect work and is re-enabled when the FreeBSD base
# replaces it. The FreeBSD base has no `print', `typeset' or z/OS builtins.
set(FSH_TEST_COMMAND $<TARGET_FILE:fsh>)

add_test(NAME smoke_print COMMAND ${FSH_TEST_COMMAND} -c "printf 'hello\n'")
set_tests_properties(smoke_print PROPERTIES PASS_REGULAR_EXPRESSION "hello")

add_test(NAME smoke_arith COMMAND ${FSH_TEST_COMMAND} -c "echo $((6*7))")
set_tests_properties(smoke_arith PROPERTIES PASS_REGULAR_EXPRESSION "42")

add_test(NAME smoke_case
  COMMAND ${FSH_TEST_COMMAND} -c "case foo.c in *.h) echo header;; *.c) echo csrc;; esac")
set_tests_properties(smoke_case PROPERTIES PASS_REGULAR_EXPRESSION "csrc")

# The script suite.  run.sh runs every tests/*.sh and compares with
# tests/*.out; it is the same runner a developer runs by hand:
#
#   ./build/fsh tests/harness tests/*.sh
#
set(FSH_TEST_SCRIPTS
  ${CMAKE_CURRENT_SOURCE_DIR}/harness)
add_test(NAME regression
  COMMAND /bin/sh ${FSH_TEST_SCRIPTS}
    $<TARGET_FILE:fsh> ${CMAKE_CURRENT_SOURCE_DIR})
set_tests_properties(regression PROPERTIES
  TIMEOUT 120
  FAIL_REGULAR_EXPRESSION "FAIL")

if(SHELLCHECK_EXE)
  add_test(NAME shellcheck
    COMMAND ${SHELLCHECK_EXE} --shell=sh ${FSH_SHELL_SCRIPTS})
endif()
