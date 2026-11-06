/*
 * strsignal() for systems without it, or where it is declared but not
 * linkable.
 *
 * On z/OS 3.2 strsignal() exists as a POSIX.1-2008 interface, but it is
 * a Language Environment service and a statically linked program cannot
 * always resolve it. trap.c already treats a NULL return as
 * "Unknown signal", so returning NULL here is the honest answer rather
 * than a guess at the right words: zksh reports "Unknown signal" for a
 * signal it cannot name, on any platform.
 *
 * Kept in its own translation unit so that the #define in portable.h
 * cannot turn this definition into a recursive call.
 */

#include "pconfig.h"

#ifndef HAVE_STRSIGNAL

#include "portable.h"

char *
oksh_strsignal(int sig)
{
	(void) sig;
	return NULL;
}

#endif /* !HAVE_STRSIGNAL */
