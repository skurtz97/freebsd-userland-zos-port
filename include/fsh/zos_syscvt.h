/*	zos_syscvt.h -- z/OS character-set handling for fsh		*/

#ifndef FSH_ZOS_SYSCVT_H
#define FSH_ZOS_SYSCVT_H

/*
 * z/OS converts a tagged text file to the *program's* CCSID when the
 * program reads it.  fsh is a native EBCDIC program ('A' == 0xC1), so
 * a script tagged IBM-1047 is converted to... the program CCSID, which
 * under _BPXK_AUTOCVT=ON is 819 (ISO8859-1) rather than 1047.  The
 * shell then parses ASCII bytes against EBCDIC string literals and
 * every comparison fails: docs/port.md P29.
 *
 * Two independent pieces fix this:
 *
 *   zos_autocvt_off()   called once from main(): putenv()s
 *                       _BPXK_AUTOCVT=OFF so the shell is not seen as
 *                       an ASCII program.  Children inherit it.
 *   zos_src_cvt_off(fd) turns conversion off for one descriptor, via
 *                       fcntl(F_CONTROL_CVT, SETCVTOFF).  Used for the
 *                       shell's own source files (scripts, ".", $ENV,
 *                       profiles) so they read as the EBCDIC bytes
 *                       they are, whatever their tag says.
 *
 * Both are no-ops off z/OS, so callers need no #ifdef.
 */

#if defined(__MVS__)
#define HAVE_ZOS_SYSCVT 1
#endif

#ifdef HAVE_ZOS_SYSCVT
/* Scrub _BPXK_AUTOCVT from our own environment.  `_ZOS_AUTOCVT=KEEP'
 * leaves it alone for sites that want fsh treated as ASCII. */
void zos_autocvt_off(void);

/* Turn auto-conversion off for descriptor `fd' (a shell source file).
 * Returns 0 on success, -1 if the descriptor does not support it, in
 * which case the caller carries on unmodified. */
int zos_src_cvt_off(int fd);
#else
#define zos_autocvt_off() ((void)0)
#define zos_src_cvt_off(fd) (-1)
#endif

#endif /* FSH_ZOS_SYSCVT_H */
