# Feature checks, replacing oksh's configure script.
#
# vendor/oksh/configure probes each of these by compiling and linking a
# snippet. CMake does the same at configure time; the answers land in
# pconfig.h through cmake/pconfig.h.in.
#
# Two rules that matter on z/OS:
#   - __dead is only defined if the system does not already define it.
#     oksh's own pconfig.h guards this, because z/OS's <sys/cdefs.h>
#     may provide it; an unguarded definition is a hard error there.
#   - Nothing here assumes the execution character set.

include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckCSourceCompiles)
include(CheckTypeSize)
include(CheckStructHasMember)

# The checks must use the same feature-test macros as the build, or a
# function is reported missing when it is really hidden behind a macro.
set(CMAKE_REQUIRED_DEFINITIONS "")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
endif()
if(ZKSH_ZOS)
  list(APPEND CMAKE_REQUIRED_DEFINITIONS -D_ALL_SOURCE)
endif()

# ---- __dead ----------------------------------------------------------

set(HAVE___DEAD 0)
check_c_source_compiles("
  int main(int argc, char **argv) { (void)argc; (void)argv; return 0; }
  __dead void f(void);" NO_DEAD)
if(NO_DEAD)
  set(HAVE___DEAD 1)
else()
  # z/OS and anything with __cdefs may already give us one.
  check_c_source_compiles("
    #include <sys/cdefs.h>
    __dead void f(void);
    int main(void) { return 0; }" HAS_CDEFS_DEAD)
  if(HAS_CDEFS_DEAD)
    set(HAVE___DEAD 1)
  endif()
endif()

# ---- Functions oksh uses if present --------------------------------

foreach(fn asprintf confstr getauxval reallocarray setresgid setresuid
    strlcat strlcpy strtonum)
  string(TOUPPER ${fn} FN_UC)
  check_function_exists(${fn} HAVE_${FN_UC})
endforeach()

# ---- Types and structure members -------------------------------------

check_type_size(sig_t HAVE_SIG_T)
check_struct_has_member("struct stat" st_mtim "sys/stat.h" HAVE_ST_MTIM)

# ---- timeradd / timersub ---------------------------------------------
# These come from <sys/time.h> on BSD/Linux; the macro is not a symbol,
# so test that a call compiles.

check_c_source_compiles("
  #include <sys/time.h>
  int main(void) {
    struct timeval a, b, c;
    timeradd(&a, &b, &c);
    timersub(&a, &b, &c);
    timerclear(&c);
    return c.tv_sec != 0;
  }" HAVE_TIMERMACROS)
if(HAVE_TIMERMACROS)
  set(HAVE_TIMERADD 1)
  set(HAVE_TIMERSUB 1)
  set(HAVE_TIMERCLEAR 1)
endif()

# ---- Curses ----------------------------------------------------------

if(ZKSH_EDITOR)
  set(HAVE_CURSES 1)
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/pconfig.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/pconfig.h @ONLY)
