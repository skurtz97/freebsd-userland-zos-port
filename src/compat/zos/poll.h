/* z/OS <poll.h> has poll() but no ppoll().  The compat implementation
 * in compat/btemp.c converts the timespec to milliseconds and restores
 * the signal mask after poll(). */
#ifndef FSH_ZOS_POLL_H
#define FSH_ZOS_POLL_H

#include_next <poll.h>
#include <signal.h>
#include <time.h>

int ppoll(struct pollfd *, nfds_t, const struct timespec *, const sigset_t *);

#endif /* FSH_ZOS_POLL_H */
