# Convert generated files from IBM-1047 (what the EBCDIC generator
# programs write) to UTF-8 (the only source encoding Open XL accepts),
# replacing each file in place and tagging it UTF-8.
if(NOT ICONV)
  return()
endif()
if(NOT FILES)
  return()
endif()
foreach(f IN LISTS FILES)
  if(NOT EXISTS "${f}")
    message(FATAL_ERROR "zos-utf8-inplace: ${f} does not exist")
  endif()
  execute_process(
    COMMAND "${ICONV}" -f IBM-1047 -t UTF-8 "${f}"
    OUTPUT_FILE "${f}.utf8"
    RESULT_VARIABLE rc)
  if(NOT rc EQUAL 0)
    message(FATAL_ERROR "zos-utf8-inplace: iconv ${f} failed (${rc})")
  endif()
  file(REMOVE "${f}")
  file(RENAME "${f}.utf8" "${f}")
  if(CHTAG)
    execute_process(
      COMMAND "${CHTAG}" -tc UTF-8 "${f}"
      RESULT_VARIABLE rc)
    if(NOT rc EQUAL 0)
      message(FATAL_ERROR "zos-utf8-inplace: chtag ${f} failed (${rc})")
    endif()
  endif()
endforeach()
