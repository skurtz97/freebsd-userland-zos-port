/* z/OS has no BSD <err.h>.  The FreeBSD kill/test/printf sources print
 * diagnostics through it; the implementations are in compat/btemp.c. */
#ifndef FSH_ZOS_ERR_H
#define FSH_ZOS_ERR_H

void err(int, const char *, ...) __attribute__((__noreturn__));
void errx(int, const char *, ...) __attribute__((__noreturn__));
void warn(const char *, ...);
void warnx(const char *, ...);

#endif /* FSH_ZOS_ERR_H */
