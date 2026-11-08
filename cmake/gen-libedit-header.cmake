# Generate one libedit header with makelist.  Kept in a CMake script so
# the build does not depend on shell redirection or a particular shell.
if(NOT DEFINED MAKELIST OR NOT DEFINED OUTPUT OR NOT DEFINED MODE OR NOT DEFINED INPUTS)
  message(FATAL_ERROR "gen-libedit-header: MAKELIST, OUTPUT, MODE and INPUTS are required")
endif()
string(REPLACE "|" ";" input_list "${INPUTS}")
set(cmd sh "${MAKELIST}" "${MODE}")
foreach(i IN LISTS input_list)
  list(APPEND cmd "${i}")
endforeach()
execute_process(COMMAND ${cmd} OUTPUT_FILE "${OUTPUT}" RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "gen-libedit-header: ${cmd} failed with ${rc}")
endif()
