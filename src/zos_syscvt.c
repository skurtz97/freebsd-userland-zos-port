/*	zos_syscvt.c -- z/OS character-set handling for oksh		*/

/*
 * Why this file exists, in one paragraph.
 *
 * z/OS auto-converts a file whose tag says "text" to the CCSID of the
 * program reading it.  fsh's literals are EBCDIC ('A' == 0xC1,
 * '\n' == 0x15), so it wants IBM-1047.  But LFS derives the program
 * CCSID from _BPXK_AUTOCVT (and _BPXK_CCSID); with _BPXK_AUTOCVT=ON --
 * which is what a zopen login leaves set -- the program is taken to be
 * an ISO8859-1 (819) program.  A script tagged IBM-1047 is therefore
 * converted EBCDIC->ASCII on read, and the shell parses ASCII against
 * EBCDIC literals.  Measured: a file holding  print OK\n  as
 * 97 99 89 95 A3 40 D6 D2 15  was read as
 * 70 72 69 6E 74 20 4F 4B 0A, and every comparison failed
 * (docs/port.md P29).
 *
 * The fix is two-layered on purpose:
 *
 *   1. zos_autocvt_off() -- make the shell not be an ASCII program at
 *      all, so nothing it does is converted behind its back.  This is
 *      the environment-level statement of what fsh is.
 *
 *   2. zos_src_cvt_off() -- belt and braces for the shell's own source
 *      files.  A site may set _BPXK_AUTOCVT=ON again (a child, a
 *      wrapper, a profile), or start fsh from a program that has
 *      already fixed its CCSID.  A shell must read its script as shell
 *      syntax regardless, so the descriptor is pinned off explicitly.
 *      This is the same mechanism as the z/OS sh's _TAG_REDIR_IN, but
 *      applied to shell input rather than to redirections: a
 *      redirection's conversion is the *parent's* business and is left
 *      alone.
 *
 * Only the shell's own source reads use (2): the script argument,
 * include() (which covers ".", $ENV and the profile), and nothing
 * else.  $(<file) and fc's temp files read data, not shell syntax, and
 * are deliberately left to the normal tag rules.
 *
 * Off z/OS this file compiles to nothing; the header's fallbacks make
 * the callers no-ops.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "shell.h"
#include "fsh/zos_syscvt.h"

#ifdef HAVE_ZOS_SYSCVT

/* struct f_cnvrt, SETCVTOFF/SETCVTON/QUERYCVT, and F_CONTROL_CVT all
 * hide behind _OPEN_SYS_FILE_EXT (AGENTS.txt 2a).  The build defines it
 * globally (CMakeLists.txt), but define it here too so this file is
 * self-contained if it is ever built alone.  Every z/OS system header
 * must come *after* this, or the struct is not declared.
 */
#ifndef _OPEN_SYS_FILE_EXT
#define _OPEN_SYS_FILE_EXT 1
#error "zos_syscvt.c: _OPEN_SYS_FILE_EXT must be defined before any header"
#endif
#include <sys/stat.h>

/* Strings given to putenv() must outlive the call, so this is static
 * rather than a local.  zos_autocvt_off() runs once, from main().
 */
static char autocvt_off_env[] = "_BPXK_AUTOCVT=OFF";

void zos_autocvt_off(void) {
  const char *cp;

  /* Opt-out for anyone who really wants fsh treated as an ASCII
   * program (for example a site that stores its scripts as tagged
   * ASCII and relies on conversion).  Named like the other fsh
   * z/OS switches (_OKSH_SHAREAS), not _BPXK_*.
   */
  cp = getenv("_ZOS_AUTOCVT");
  if (cp != NULL && (strcmp(cp, "KEEP") == 0 || strcmp(cp, "keep") == 0))
    return;

  /* putenv(), not setenv(): POSIX since the beginning and not hidden
   * behind the z/OS feature-macro stack, as in zos_spawn.c.  Setting
   * it in the environment is the point -- the runtime reads it when it
   * works out the program CCSID, and daughters inherit our choice.
   *
   * Note this is *our* environment only; it is not exported to the
   * parent, and a child that wants conversion back can set it itself.
   */
  putenv(autocvt_off_env);
}

/*
 * Turn auto-conversion off for a shell source descriptor.
 *
 * SETCVTOFF is the blunt setting: no Unicode Services conversion at all
 * for this descriptor, so read() returns the file's bytes untouched.
 * That is what a native EBCDIC shell needs from a script.
 *
 * Deliberately silent on failure.  A descriptor that cannot be
 * controlled (already binary, a socket, a device, an old level of the
 * OS) simply keeps the behaviour it had; the shell then relies on
 * zos_autocvt_off() having made the program EBCDIC in the first place.
 * Turning "could not pin this off" into a startup error would break
 * `fsh < /dev/null' for no benefit.
 *
 * QUERYCVT first is not an optimisation -- it distinguishes "already
 * off" (common: untagged files, and everything after autocvt_off) from
 * "no conversion controls available", and skips a pointless fcntl().
 */
int zos_src_cvt_off(int fd) {
  struct f_cnvrt cv;

  if (fd < 0)
    return -1;

  memset(&cv, 0, sizeof cv);
  cv.cvtcmd = QUERYCVT;
  if (fcntl(fd, F_CONTROL_CVT, &cv) == 0 && cv.cvtcmd == SETCVTOFF)
    return 0; /* nothing to do */

  memset(&cv, 0, sizeof cv);
  cv.cvtcmd = SETCVTOFF;
  if (fcntl(fd, F_CONTROL_CVT, &cv) == 0)
    return 0;

  /* Not an error worth reporting: see the comment above.  errno is
   * left as the fcntl() set it so a caller that does care can look.
   */
  return -1;
}

#endif /* HAVE_ZOS_SYSCVT */
