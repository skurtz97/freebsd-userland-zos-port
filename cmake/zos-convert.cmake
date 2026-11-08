# Convert one build input from UTF-8 to IBM-1047 for a z/OS tool that
# reads raw bytes.  CMake runs this with -P; execute_process gives us
# OUTPUT_FILE without needing a shell redirection.
if(NOT ICONV OR NOT INPUT OR NOT OUTPUT)
  message(FATAL_ERROR "zos-convert: ICONV, INPUT and OUTPUT are required")
endif()
execute_process(
  COMMAND "${ICONV}" -f UTF-8 -t IBM-1047 "${INPUT}"
  OUTPUT_FILE "${OUTPUT}"
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "zos-convert: iconv ${INPUT} -> ${OUTPUT} failed (${rc})")
endif()
