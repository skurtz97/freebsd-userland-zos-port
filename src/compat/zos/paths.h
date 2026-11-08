/* z/OS has no <paths.h>.  Provide the few path macros the FreeBSD shell
 * uses; values follow FreeBSD's defaults and the z/OS UNIX layout. */
#ifndef FSH_ZOS_PATHS_H
#define FSH_ZOS_PATHS_H

#define _PATH_BSHELL "/bin/sh"
#define _PATH_DEFPATH "/bin:/usr/bin"
#define _PATH_DEVNULL "/dev/null"
#define _PATH_STDPATH "/bin:/usr/bin:/sbin:/usr/sbin"
#define _PATH_TMP "/tmp/"
#define _PATH_TTY "/dev/tty"

#endif /* FSH_ZOS_PATHS_H */
