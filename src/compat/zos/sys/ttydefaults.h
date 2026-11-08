/* z/OS has no <sys/ttydefaults.h>.  libedit's readline/readline.h
 * includes it only to get CTRL(); tty.h supplies the default control
 * characters itself when <termios.h> does not. */
#ifndef FSH_ZOS_SYS_TTYDEFAULTS_H
#define FSH_ZOS_SYS_TTYDEFAULTS_H

#include <sys/types.h>

#ifndef CTRL
#define CTRL(c) ((c) & 037)
#endif

#endif /* FSH_ZOS_SYS_TTYDEFAULTS_H */
