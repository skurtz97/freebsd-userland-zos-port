/* z/OS has no <sys/param.h>.  FreeBSD shell sources include it for
 * the traditional BSD convenience macros.  fsh itself uses PATH_MAX
 * from <limits.h>, but keep the common names here so imported sources
 * that really use MAXPATHLEN/roundup/howmany still compile. */
#ifndef FSH_ZOS_SYS_PARAM_H
#define FSH_ZOS_SYS_PARAM_H

#include <sys/types.h>
#include <limits.h>

#ifndef MAXPATHLEN
#define MAXPATHLEN PATH_MAX
#endif
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif
#ifndef roundup
#define roundup(x, y) (((x) + ((y) - 1)) & ~((y) - 1))
#endif
#ifndef howmany
#define howmany(x, y) (((x) + ((y) - 1)) / (y))
#endif
#ifndef powerof2
#define powerof2(x) ((((x) - 1) & (x)) == 0)
#endif
#ifndef nitems
#define nitems(a) (sizeof(a) / sizeof((a)[0]))
#endif

#endif /* FSH_ZOS_SYS_PARAM_H */
