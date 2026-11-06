# Tests.
#
# Phase 0 has no runner yet: these register what exists so `ctest`
# works and the gap is visible. The zash suite under tests/ was written
# against zash; its cases are being ported to zksh in phase 1
# (docs/merge.md) and only the ones that pass are listed here.
#
# Adding a test: add a .sh under tests/, a CTest entry here, and the
# expected output next to the script.

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
