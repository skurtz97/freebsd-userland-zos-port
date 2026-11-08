/* Minimal substitute for FreeBSD's <vis.h> for libedit. */
#ifndef FSH_COMPAT_VIS_H
#define FSH_COMPAT_VIS_H
#include <stddef.h>
#define VIS_SP 0x01
#define VIS_TAB 0x02
#define VIS_NL 0x04
#define VIS_SAFE 0x10
#define VIS_NOSLASH 0x20
#define VIS_OCTAL 0x40
#define VIS_GLOB 0x80
#define VIS_CSTYLE 0x100
#define VIS_WHITE (VIS_SP | VIS_TAB | VIS_NL)
#define VIS_DQ 0x400
#define VIS_SQ 0x800
#define UNVIS_ERROR (-1)
#define UNVIS_NOCHAR 1
#define UNVIS_VALID 2
#define UNVIS_VALIDPUNCT 3
#define UNVIS_SYNBAD 4
#define UNVIS_IGNORE 5
#define UNVIS_END 6
int strvis(char *, const char *, int);
int strsnvis(char *, size_t, const char *, int, const char *);
int strvisx(char *, const char *, size_t, int);
int strnvis(char *, size_t, const char *, int);
int strunvis(char *, const char *);
int strnunvis(char *, size_t, const char *);
int unvis(char *, int, int *, int);
#endif
/* Per-character vis for readline.c. */
int vis(char *, int, int, int);
