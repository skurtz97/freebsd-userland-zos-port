/* z/OS <string.h> does not declare the BSD extensions libedit and the
 * FreeBSD shell use, and it does not pull in <strings.h> for
 * strcasecmp().  Add both here; the implementations of strlcpy/strlcat
 * are in src/compat/strlcpy.c. */
#ifndef FSH_ZOS_STRING_H
#define FSH_ZOS_STRING_H

#include_next <string.h>
#include <strings.h>

#ifndef FSH_HAVE_STRLCPY
size_t strlcpy(char *, const char *, size_t);
size_t strlcat(char *, const char *, size_t);
#endif

#endif /* FSH_ZOS_STRING_H */
