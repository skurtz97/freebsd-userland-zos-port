# Convert one build input from FROM to TO for a z/OS tool that reads
# raw bytes.  CMake runs this with -P; execute_process gives us
# OUTPUT_FILE without needing a shell redirection.
if(NOT ICONV OR NOT INPUT OR NOT OUTPUT)
  message(FATAL_ERROR "zos-convert: ICONV, INPUT and OUTPUT are required")
endif()
if(NOT FROM)
  set(FROM UTF-8)
endif()
if(NOT TO)
  set(TO IBM-1047)
endif()
execute_process(
  COMMAND "${ICONV}" -f "${FROM}" -t "${TO}" "${INPUT}"
  OUTPUT_FILE "${OUTPUT}"
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR
    "zos-convert: iconv ${FROM}->${TO} ${INPUT} -> ${OUTPUT} failed (${rc})")
endif()
