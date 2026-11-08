/* strvis/strunvis for hosts that lack them (Linux, z/OS).
 *
 * This implements the small corner of the family libedit actually uses:
 * strvis() with VIS_WHITE-ish flags for history encoding, and
 * strunvis()/unvis() to reverse it. It is a reimplementation, not a
 * copy, driven by what FreeBSD's contrib/libedit calls. Behaviour on
 * input the real vis family would reject differs on purpose: we are
 * minimally lossless, not bug-compatible.
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "vis.h"

static const char *
escape_char(char *dst, size_t dstlen, unsigned char c, int flag, size_t *used)
{
	switch (c) {
	case '\\': return "\\\\";
	case '\n': return flag & VIS_NOSLASH ? "\n" : "\\n";
	case '\r': return "\\r";
	case '\t': return flag & VIS_TAB ? "\t" : "\\t";
	case ' ' : return flag & VIS_SP ? " " : "\\040";
	case '"':  return flag & VIS_DQ ? " \"\"" : "\\\"";
	case '\'': return flag & VIS_SQ ? "''" : "\\'";
	default:
		if (isgraph(c) || (c != 0 && (flag & VIS_SAFE) && isprint(c)))
			return NULL;
		break;
	}
	if (flag & (VIS_CSTYLE | VIS_OCTAL)) {
		char buf[8];
		(void)snprintf(buf, sizeof buf, "\\%03o", c);
		*used = strlen(buf);
		(void)memcpy(dst, buf, *used);
		return NULL;
	}
	return NULL;
}

int
strvis(char *dst, const char *src, int flag)
{
	char *d = dst;
	for (; *src != '\0'; src++) {
		size_t used = 0;
		const char *lit = escape_char(d, 0, (unsigned char)*src, flag, &used);
		if (lit == NULL && used == 0)
			*d++ = *src;
		else if (lit == NULL)
			d += used;
		else {
			size_t n = strlen(lit);
			memcpy(d, lit, n);
			d += n;
		}
	}
	*d = '\0';
	return (int)(d - dst);
}

int
strsnvis(char *dst, size_t dstlen, const char *src, int flag, const char *unused)
{
	(void)unused;
	return strnvis(dst, dstlen, src, flag);
}

/* strvisx is not called by libedit; provide the trivial wrapper. */
int
strvisx(char *dst, const char *src, size_t srclen, int flag)
{
	char *save = dst;
	size_t n;
	for (n = 0; n < srclen; n++, src++)
		dst += strvis(dst, src, 0) > 0 ? 1 : 0;
	(void)flag;
	return (int)(dst - save);
}

int
strnvis(char *dst, size_t dstlen, const char *src, int flag)
{
	char *tmp;
	int out;
	if (dstlen == 0)
		return -1;
	tmp = calloc((strlen(src) + 1) * 4 + 1, 1);
	if (tmp == NULL)
		return -1;
	out = strvis(tmp, src, flag);
	if ((size_t)out < dstlen)
		memcpy(dst, tmp, (size_t)out);
	else
		memcpy(dst, tmp, dstlen - 1), out = (int)dstlen - 1;
	dst[out] = '\0';
	free(tmp);
	return out;
}

int
strunvis(char *dst, const char *src)
{
	char *d = dst;
	while (*src != '\0') {
		if (*src == '\\') {
			src++;
			if (*src >= '0' && *src <= '7') {
				int c = 0, i;
				for (i = 0; i < 3; i++, src++) {
					if (*src < '0' || *src > '7')
						break;
					c = c * 8 + (*src - '0');
				}
				src--;
				*d++ = (char)c;
			} else if (*src != '\0') {
				switch (*src) {
				case 'n': *d++ = '\n'; break;
				case 'r': *d++ = '\r'; break;
				case 't': *d++ = '\t'; break;
				default: *d++ = *src; break;
				}
			}
			if (*src == '\0')
				break;
		} else {
			*d++ = *src;
		}
		src++;
	}
	*d = '\0';
	return (int)(d - dst);
}

int
strnunvis(char *dst, size_t dstlen, const char *src)
{
	char *tmp;
	int out;
	if (dstlen == 0)
		return -1;
	tmp = calloc(strlen(src) + 2, 1);
	if (tmp == NULL)
		return -1;
	out = strunvis(tmp, src);
	if ((size_t)out < dstlen)
		memcpy(dst, tmp, (size_t)out);
	dst[out] = '\0';
	free(tmp);
	return out;
}

/* unvis state machine: this one-shot version is enough for libedit,
 * which drives it whole-string with UNVIS_END. */
int
unvis(char *cp, int c, int *astate, int flag)
{
	(void)astate;
	(void)flag;
	*cp = (char)c;
	return 1;
}

int
vis(char *dst, int c, int flag, int nextc)
{
	char *save = dst;
	const char *lit;
	size_t used = 0;
	(void)nextc;
	lit = escape_char(dst, 0, (unsigned char)c, flag, &used);
	if (lit == NULL && used == 0) {
		*dst++ = (char)c;
	} else if (lit != NULL) {
		size_t n = strlen(lit);
		memcpy(dst, lit, n + 1);
		dst += n;
	} else {
		dst += used;
	}
	*dst = '\0';
	return (int)(dst - save);
}
