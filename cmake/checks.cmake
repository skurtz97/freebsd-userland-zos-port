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
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckCSourceCompiles)
include(CheckTypeSize)
include(CheckStructHasMember)

# The checks must use the same feature-test macros as the build, or a
# function is reported missing when it is really hidden behind a macro.
# The flags matter too: the target builds with -std=gnu99, and a check
# compiled as bare C89 sees neither //-comments nor declarations the
# system headers expect.
set(CMAKE_REQUIRED_DEFINITIONS "")
set(CMAKE_REQUIRED_FLAGS "")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
endif()
if(ZKSH_ZOS)
  # Must match the target's definitions, or a probe reports a function
  # missing while the build can see it.
  list(APPEND CMAKE_REQUIRED_DEFINITIONS
    -D_ALL_SOURCE -D_XPLATFORM_SOURCE -D_OPEN_SYS
    -D_POSIX_C_SOURCE=200809L)
endif()
# Match CMAKE_C_STANDARD 99 / CMAKE_C_EXTENSIONS ON in CMakeLists.txt.
list(APPEND CMAKE_REQUIRED_FLAGS -std=gnu99)

# ---- __dead ----------------------------------------------------------
# Does the system already provide __dead (z/OS <sys/cdefs.h> may)?
# A successful compile here means "system has it, do not define ours".
# The check must not rely on a bare __dead compiling, which is always
# false.

set(ZKSH_HAVE_SYSTEM_DEAD 0)
check_c_source_compiles("
  #include <sys/cdefs.h>
  __dead void zksh_probe_dead(void);
  int main(void) { return 0; }" ZKSH_SYSTEM_DEAD_OK)
if(ZKSH_SYSTEM_DEAD_OK)
  set(ZKSH_HAVE_SYSTEM_DEAD 1)
endif()
# Fallback: some systems define it in stdlib.h (BSD).
if(NOT ZKSH_HAVE_SYSTEM_DEAD)
  check_c_source_compiles("
    #include <stdlib.h>
    __dead void zksh_probe_dead(void);
    int main(void) { return 0; }" ZKSH_STDLIB_DEAD_OK)
  if(ZKSH_STDLIB_DEAD_OK)
    set(ZKSH_HAVE_SYSTEM_DEAD 1)
  endif()
endif()

# ---- Headers ---------------------------------------------------------
# z/OS has no <sys/param.h> at all, and MAXLOGNAME comes from it on BSD
# but from <limits.h> (or nowhere) elsewhere.

check_include_file("paths.h" HAVE_PATHS_H)
if(HAVE_PATHS_H)
  set(HAVE_PATHS_H 1)
else()
  set(HAVE_PATHS_H 0)
endif()
check_include_file("sys/param.h" HAVE_SYS_PARAM_H)
if(HAVE_SYS_PARAM_H)
  set(HAVE_SYS_PARAM_H 1)
else()
  set(HAVE_SYS_PARAM_H 0)
endif()

set(HAVE_MAXLOGNAME 0)
check_c_source_compiles("
  #include <limits.h>
  #include <sys/param.h>
  int zksh_pw = MAXLOGNAME;
  int main(void) { return zksh_pw == 0; }" ZKSH_MAXLOGNAME_OK)
if(NOT ZKSH_MAXLOGNAME_OK)
  # BSD also has <sys/syslimits.h>; try it in case param.h is absent.
  check_c_source_compiles("
    #include <limits.h>
    #include <sys/syslimits.h>
    int zksh_pw = MAXLOGNAME;
    int main(void) { return zksh_pw == 0; }" ZKSH_SYSLIMITS_OK)
  if(ZKSH_SYSLIMITS_OK)
    set(ZKSH_MAXLOGNAME_OK 1)
  endif()
endif()
if(ZKSH_MAXLOGNAME_OK)
  set(HAVE_MAXLOGNAME 1)
endif()

# ---- Functions oksh uses if present --------------------------------

# Each HAVE_x is set to 0 before the check, so that a cached answer from
# an older configure, or a check that errors out instead of answering
# "no", cannot leave a feature switched on that is not there.
foreach(fn asprintf confstr getauxval reallocarray setresgid setresuid
    strlcat strlcpy strtonum)
  string(TOUPPER ${fn} FN_UC)
  set(HAVE_${FN_UC} 0)
  check_function_exists(${fn} HAVE_${FN_UC})
  if(NOT HAVE_${FN_UC})
    set(HAVE_${FN_UC} 0)
  endif()
endforeach()

# flock(): BSD 4.4, in <sys/file.h>. z/OS has it, but only under
# _XPLATFORM_SOURCE.
set(HAVE_FLOCK 0)
check_c_source_compiles("
  #include <sys/file.h>
  int main(void) { return flock(0, LOCK_EX | LOCK_UN); }" ZKSH_FLOCK_OK)
if(ZKSH_FLOCK_OK)
  set(HAVE_FLOCK 1)
endif()

# strsignal(): POSIX.1-2008. Present on z/OS 3.2 behind
# _POSIX_C_SOURCE, but it is a Language Environment service, so a
# static link need not resolve it. check_c_source_compiles LINKS, which
# is what matters here: a declaration that compiles and then fails to
# link is the failure this probe exists to catch.
set(HAVE_STRSIGNAL 0)
check_c_source_compiles("
  #include <string.h>
  int main(void) { return strsignal(2) == 0; }" ZKSH_STRSIGNAL_OK)
if(ZKSH_STRSIGNAL_OK)
  set(HAVE_STRSIGNAL 1)
endif()

# WCOREDUMP(): a BSD macro over the wait status. Absent from POSIX and
# from z/OS, where there is no core-dump flag in a wait status at all.
set(HAVE_WCOREDUMP 0)
check_c_source_compiles("
  #include <sys/wait.h>
  int main(void) { return WCOREDUMP(0); }" ZKSH_WCOREDUMP_OK)
if(ZKSH_WCOREDUMP_OK)
  set(HAVE_WCOREDUMP 1)
endif()

# ---- Types and structure members -------------------------------------

# sig_t: portable.h typedefs its own when HAVE_SIG_T is 0, so a wrong
# "no" here collides with the system typedef and a wrong "yes" leaves
# sig_t undeclared. Check the typedef the way the source uses it.
set(HAVE_SIG_T 0)
check_c_source_compiles("
  #include <signal.h>
  int main(void) { sig_t f = SIG_DFL; return f == 0; }" ZKSH_SIG_T_OK)
if(ZKSH_SIG_T_OK)
  set(HAVE_SIG_T 1)
endif()

# struct stat's time member is st_mtim on Linux, st_mtimespec on BSD,
# and st_mtime where neither exists. Ask by compiling a use of it.
set(HAVE_ST_MTIM 0)
check_c_source_compiles("
  #include <sys/stat.h>
  int main(void) {
    struct stat sb;
    return (int) sb.st_mtim.tv_sec;
  }" ZKSH_ST_MTIM_OK)
if(ZKSH_ST_MTIM_OK)
  set(HAVE_ST_MTIM 1)
endif()

# ---- timeradd / timersub / timerclear -------------------------------
# These are macros, not symbols, so each is probed by compiling a use.
# They are probed separately because a system can have some and not
# others: z/OS has timeradd and timersub in <sys/time.h> under
# _XPLATFORM_SOURCE but no timerclear.

set(HAVE_TIMERADD 0)
set(HAVE_TIMERSUB 0)
set(HAVE_TIMERCLEAR 0)
check_c_source_compiles("
  #include <sys/time.h>
  int main(void) {
    struct timeval a, b, c;
    timeradd(&a, &b, &c);
    return c.tv_sec != 0;
  }" ZKSH_TIMERADD_OK)
if(ZKSH_TIMERADD_OK)
  set(HAVE_TIMERADD 1)
endif()
check_c_source_compiles("
  #include <sys/time.h>
  int main(void) {
    struct timeval a, b, c;
    timersub(&a, &b, &c);
    return c.tv_sec != 0;
  }" ZKSH_TIMERSUB_OK)
if(ZKSH_TIMERSUB_OK)
  set(HAVE_TIMERSUB 1)
endif()
check_c_source_compiles("
  #include <sys/time.h>
  int main(void) {
    struct timeval c;
    timerclear(&c);
    return c.tv_sec != 0;
  }" ZKSH_TIMERCLEAR_OK)
if(ZKSH_TIMERCLEAR_OK)
  set(HAVE_TIMERCLEAR 1)
endif()

# ---- Curses ----------------------------------------------------------

if(ZKSH_EDITOR)
  set(HAVE_CURSES 1)
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/pconfig.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/pconfig.h @ONLY)
