/* z/OS has no <sys/cdefs.h>.  FreeBSD's shell sources include it for
 * the usual BSD annotation macros, so provide the subset they use.
 * This is deliberately self-contained: it is reached from system
 * headers too, so it must not pull in <stdio.h> or <sys/stat.h>. */
#ifndef FSH_ZOS_SYS_CDEFS_H
#define FSH_ZOS_SYS_CDEFS_H

#include <stdint.h>

#ifdef __cplusplus
#define __BEGIN_DECLS extern "C" {
#define __END_DECLS }
#else
#define __BEGIN_DECLS
#define __END_DECLS
#endif

#ifndef __P
#define __P(protos) protos
#endif
#ifndef __unused
#define __unused __attribute__((__unused__))
#endif
#ifndef __dead2
#define __dead2 __attribute__((__noreturn__))
#endif
#ifndef __printflike
#define __printflike(a, b) __attribute__((__format__(__printf__, a, b)))
#endif
#ifndef __printf0like
#define __printf0like(a, b) __attribute__((__format__(__printf__, a, b)))
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
#ifndef __predict_true
#define __predict_true(exp) __builtin_expect((exp), 1)
#endif
#ifndef __predict_false
#define __predict_false(exp) __builtin_expect((exp), 0)
#endif
#ifndef __RCSID
#define __RCSID(x)
#endif
#ifndef __FBSDID
#define __FBSDID(x)
#endif
#ifndef __IDSTRING
#define __IDSTRING(name, string)
#endif

#endif /* FSH_ZOS_SYS_CDEFS_H */
