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
# Adding a case: add <name>.sh, <name>.out, and name it in ZKSH_CASES
# below.  Expectations are ASCII; on z/OS run-c.sh decodes IBM-1047
# output before it is compared (see docs/build.md).
#
# Every case runs through run-c.sh so that z/OS output (IBM-1047) is
# decoded before it is matched against these ASCII expectations.
# ZKSH_DECODE is empty on hosts whose shell already writes ASCII.
set(ZKSH_TEST_COMMAND
  ${CMAKE_COMMAND} -E env ZKSH_DECODE=${ZKSH_DECODE} ${ZKSH_TEST_ENV}
  ${ZKSH_TEST_SHELL} ${CMAKE_CURRENT_SOURCE_DIR}/run-c.sh $<TARGET_FILE:zksh>)

add_test(NAME smoke_print COMMAND ${ZKSH_TEST_COMMAND} -c "print hello")
set_tests_properties(smoke_print PROPERTIES PASS_REGULAR_EXPRESSION "hello")

add_test(NAME smoke_arith COMMAND ${ZKSH_TEST_COMMAND} -c "echo $((6*7))")
set_tests_properties(smoke_arith PROPERTIES PASS_REGULAR_EXPRESSION "42")

add_test(NAME smoke_array
  COMMAND ${ZKSH_TEST_COMMAND} -c "set -A a x y z; print \${a[2]}")
set_tests_properties(smoke_array PROPERTIES PASS_REGULAR_EXPRESSION "z")

add_test(NAME smoke_typeset
  COMMAND ${ZKSH_TEST_COMMAND} -c "f() { typeset x=local; print \$x; }; x=global; f; print \$x")
set_tests_properties(smoke_typeset PROPERTIES PASS_REGULAR_EXPRESSION "local\nglobal")

# The script suite.  run.sh runs every tests/*.sh and compares with
# tests/*.out; it is the same runner a developer runs by hand:
#
#   ./build/zksh tests/run.sh ./build/zksh
#
# One test, not one per file, because the runner already reports which
# file failed with a diff.  Registering each case separately here would
# need CMake to know the file list (and to keep it in step with run.sh).
add_test(NAME regression
  COMMAND ${CMAKE_COMMAND} -E env
    ZKSH_DECODE=${ZKSH_DECODE} ${ZKSH_TEST_ENV}
    ${ZKSH_TEST_SHELL} ${CMAKE_CURRENT_SOURCE_DIR}/run.sh
    -v $<TARGET_FILE:zksh>)
set_tests_properties(regression PROPERTIES
  TIMEOUT 120
  FAIL_REGULAR_EXPRESSION "FAIL")
