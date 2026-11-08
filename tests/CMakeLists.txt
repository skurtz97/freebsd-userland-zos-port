# Tests.
#
# Two layers:
#
#   smoke_*  one-line checks that the shell starts and the ksh88 basics
#            evaluate.  They catch "the build produced a broken binary",
#            which a script test can hide behind a later failure.
#
#   regression_*  tests/<name>.sh run under the shell being tested,
#            compared against tests/<name>.out by tests/run.sh.  $T is
#            a private temporary directory, $SH the shell under test and
#            $SH_UNDER_TEST its absolute path; the runner substitutes $T
#            in the expected output before comparing.
#
# Adding a case: add <name>.sh, <name>.out, and name it in FSH_CASES
# below.  Expectations are ASCII; on z/OS run-c.sh decodes IBM-1047
# output before it is compared (see docs/build.md).
#
# Every case runs through run-c.sh so that z/OS output (IBM-1047) is
# decoded before it is matched against these ASCII expectations.
# FSH_DECODE and FSH_ENCODE are empty on hosts whose shell already
# reads and writes ASCII (they are the output and input halves of the
# same bridge: see tests/run-c.sh and tests/run.sh).
set(FSH_TEST_COMMAND
  ${CMAKE_COMMAND} -E env FSH_DECODE=${FSH_DECODE} FSH_ENCODE=${FSH_ENCODE} ${FSH_TEST_ENV}
  ${FSH_TEST_SHELL} ${CMAKE_CURRENT_SOURCE_DIR}/run-c.sh $<TARGET_FILE:fsh>)

add_test(NAME smoke_print COMMAND ${FSH_TEST_COMMAND} -c "print hello")
set_tests_properties(smoke_print PROPERTIES PASS_REGULAR_EXPRESSION "hello")

add_test(NAME smoke_arith COMMAND ${FSH_TEST_COMMAND} -c "echo $((6*7))")
set_tests_properties(smoke_arith PROPERTIES PASS_REGULAR_EXPRESSION "42")

add_test(NAME smoke_array
  COMMAND ${FSH_TEST_COMMAND} -c "set -A a x y z; print \${a[2]}")
set_tests_properties(smoke_array PROPERTIES PASS_REGULAR_EXPRESSION "z")

add_test(NAME smoke_typeset
  COMMAND ${FSH_TEST_COMMAND} -c "f() { typeset x=local; print \$x; }; x=global; f; print \$x")
set_tests_properties(smoke_typeset PROPERTIES PASS_REGULAR_EXPRESSION "local\nglobal")

# The script suite.  run.sh runs every tests/*.sh and compares with
# tests/*.out; it is the same runner a developer runs by hand:
#
#   ./build/fsh tests/run.sh ./build/fsh
#
# One test, not one per file, because the runner already reports which
# file failed with a diff.  Registering each case separately here would
# need CMake to know the file list (and to keep it in step with run.sh).
add_test(NAME regression
  COMMAND ${CMAKE_COMMAND} -E env
    FSH_DECODE=${FSH_DECODE} FSH_ENCODE=${FSH_ENCODE} ${FSH_TEST_ENV}
    ${FSH_TEST_SHELL} ${CMAKE_CURRENT_SOURCE_DIR}/run.sh
    -v $<TARGET_FILE:fsh>)
set_tests_properties(regression PROPERTIES
  TIMEOUT 120
  FAIL_REGULAR_EXPRESSION "FAIL")

if(SHELLCHECK_EXE)
  add_test(NAME shellcheck
    COMMAND ${SHELLCHECK_EXE} --shell=sh ${FSH_SHELL_SCRIPTS})
endif()
