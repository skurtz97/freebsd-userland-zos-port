#ifndef ZKSH_FREEBSD_COMPAT_H
#define ZKSH_FREEBSD_COMPAT_H
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <sys/stat.h>
#ifndef __dead2
#define __dead2 __attribute__((__noreturn__))
#endif
#ifndef __printf0like
#define __printf0like(a, b) __attribute__((__format__(__printf__, a, b)))
#endif
#ifndef __printflike
#define __printflike(a, b) __attribute__((__format__(__printf__, a, b)))
#endif
#ifndef __unused
#define __unused __attribute__((__unused__))
#endif
#ifndef __pure
#define __pure __attribute__((__pure__))
#endif
#ifndef __used
#define __used __attribute__((__used__))
#endif
#ifndef __packed
#define __packed __attribute__((__packed__))
#endif
#ifndef __aligned
#define __aligned(x) __attribute__((__aligned__(x)))
#endif
#ifndef __nonstring
#define __nonstring
#endif
#ifndef __DECONST
#define __DECONST(type, var) ((type)(uintptr_t)(const void *)(var))
#endif
#ifndef MAXLOGNAME
#define MAXLOGNAME 256
#endif
#ifndef ALIGNBYTES
#define ALIGNBYTES (sizeof(void *) - 1)
#endif
#ifndef ALIGN
#define ALIGN(p) (((uintptr_t)(p) + ALIGNBYTES) & ~ALIGNBYTES)
#endif
#ifndef CLOCK_UPTIME
#define CLOCK_UPTIME CLOCK_MONOTONIC
#endif
#ifndef timespecsub
#define timespecsub(tsp, usp, vsp) do { \
	(vsp)->tv_sec = (tsp)->tv_sec - (usp)->tv_sec; \
	(vsp)->tv_nsec = (tsp)->tv_nsec - (usp)->tv_nsec; \
	if ((vsp)->tv_nsec < 0) { (vsp)->tv_sec--; (vsp)->tv_nsec += 1000000000L; } \
} while (0)
#endif
#ifndef timespeccmp
#define timespeccmp(tsp, usp, cmp) \
	(((tsp)->tv_sec == (usp)->tv_sec) ? \
	    ((tsp)->tv_nsec cmp (usp)->tv_nsec) : \
	    ((tsp)->tv_sec cmp (usp)->tv_sec))
#endif
#ifndef O_VERIFY
#define O_VERIFY 0
#endif
#ifndef S_ISTXT
#define S_ISTXT S_ISVTX
#endif
#ifndef SIG2STR_MAX
#define SIG2STR_MAX 32
#endif

extern const int sys_nsig;
extern const char *const sys_signame[];
int fsh_issetugid(void);
int sig2str(int, char *);
int str2sig(const char *, int *);
void *setmode(const char *);
mode_t getmode(const void *, mode_t);
FILE *fwopen(void *, int (*)(void *, const char *, int));
#endif
/* C11 Annex K qsort_s is a FreeBSD libc feature (and Linux glibc has no
 * prototype even where it exists). histedit.c uses it for command-name
 * completion. fsh is single threaded, so the thunk goes through a
 * file-scope variable in btemp.c and qsort() works. */
void fsh_qsort_s_adapter(void *, size_t, size_t,
    int (*)(const void *, const void *, void *), void *);
#define qsort_s(base, nmemb, size, cmp, thunk) \
	(fsh_qsort_s_adapter((base), (nmemb), (size), (cmp), (thunk)), 0)
