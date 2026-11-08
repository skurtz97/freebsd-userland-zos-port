/* z/OS <wchar.h> has no wcsdup() declaration or implementation.
 * libedit uses it in el.c, eln.c, history.c, keymacro.c and read.c.
 * Declare the compat implementation from src/compat/btemp.c. */
#ifndef FSH_ZOS_WCHAR_H
#define FSH_ZOS_WCHAR_H

#include_next <wchar.h>

#ifndef FSH_HAVE_WCSDUP
#define FSH_HAVE_WCSDUP 1
wchar_t *wcsdup(const wchar_t *);
#endif

#endif /* FSH_ZOS_WCHAR_H */
