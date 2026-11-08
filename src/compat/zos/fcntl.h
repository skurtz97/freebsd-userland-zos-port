/* z/OS <fcntl.h> has no F_DUPFD_CLOEXEC.  Use F_DUPFD and accept that
 * the duplicated descriptor is not close-on-exec; the shell sets
 * FD_CLOEXEC itself where it matters. */
#ifndef FSH_ZOS_FCNTL_H
#define FSH_ZOS_FCNTL_H

#include_next <fcntl.h>

#ifndef F_DUPFD_CLOEXEC
#define F_DUPFD_CLOEXEC F_DUPFD
#endif

#endif /* FSH_ZOS_FCNTL_H */
