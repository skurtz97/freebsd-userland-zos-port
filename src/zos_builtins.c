/*
 * z/OS builtins: tso, alloc, free, zosclass, chtag, extattr.
 *
 * Why these are builtins at all (docs/direction.md, "aggressively
 * non-POSIX on z/OS"):
 *
 *   - alloc / free
 *           MVS allocations are NOT inherited across fork/exec, so a
 *           child cannot manage its parent's allocations.  Only the
 *           shell itself can usefully do this, which is also the
 *           argument for the fast path to move in-process later.
 *   - tso   can grow an in-process TSO/E interface (IKJTSOEV) that no
 *           external script could have.  Today it defers to tsocmd,
 *           which is a spawn per command.
 *   - zosclass
 *           reports the session kind so a profile can branch.
 *   - chtag reports a file's tag from st_tag without a spawn; every
 *           form it does not handle itself defers to /bin/chtag.
 *
 * Off z/OS every one of these exists and answers "only available on
 * z/OS" with status 2, so a script can test for the name or the status
 * instead of getting "not found" from a path search.  tests/zos.sh
 * checks exactly that contract.
 *
 * "Deferring" means building a command line and running it through
 * command(), so the real utility gets the shell's PATH, redirections
 * and exit status.  Arguments are quoted one by one: on EBCDIC, as on
 * ASCII, concatenating an argument raw is the bug.
 *
 * VERIFY (none of this has run on z/OS yet): the <_Ccsid.h> header
 * name and __toCSName() signature, struct stat's st_tag members
 * (ft_ccsid, ft_txtflag), that tsocmd and /bin/chtag exist under
 * those names, and the _BPX_TERMPATH values zosclass looks for.
 * AGENTS.txt 2a: check the local CRTL and command-reference books
 * before changing any of them.
 */

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "sh.h"

#ifdef __MVS__

#include <_Ccsid.h> /* __toCSName() */

/*
 * Run `util arg...' through the shell, passing argv[from..].
 *
 * With whole=0 each argument is passed as its own word, which is what
 * tsocmd wants.  With whole=1 the arguments are joined with spaces and
 * passed as one quoted word, which is what TSO/E ALLOC and FREE want
 * (they take a single operand string: "dsn('HLQ.DS') new catalog").
 *
 * Returns the utility's exit status, or 127 if it could not be run.
 */
static int zos_defer(const char *util, char **argv, int from, int whole) {
  struct shf *shf;
  char *cmd, *p;
  int i, rv;

  shf = shf_sopen(NULL, 0, SHF_WR | SHF_DYNAMIC, NULL);
  shf_puts(util, shf);

  if (whole) {
    shf_putc(' ', shf);
    shf_putc('\'', shf);
    for (i = from; argv[i] != NULL; i++) {
      if (i > from)
        shf_putc(' ', shf);
      /* Inside single quotes the only character that needs care is a
       * single quote itself; close, escape, reopen. */
      for (p = argv[i]; *p != '\0'; p++) {
        if (*p == '\'')
          shf_puts("'\\''", shf);
        else
          shf_putc(*p, shf);
      }
    }
    shf_putc('\'', shf);
  } else {
    for (i = from; argv[i] != NULL; i++) {
      shf_putc(' ', shf);
      if (argv[i][0] == '\0') {
        shf_puts("''", shf);
        continue;
      }
      for (p = argv[i]; *p != '\0'; p++) {
        /* Empty words are handled above; otherwise quote only when a
         * shell metacharacter is present, so the common case stays
         * readable in xtrace output. */
        if (ctype(*p, C_QUOTE))
          break;
      }
      if (*p == '\0') {
        shf_puts(argv[i], shf);
        continue;
      }
      shf_putc('\'', shf);
      for (p = argv[i]; *p != '\0'; p++) {
        if (*p == '\'')
          shf_puts("'\\''", shf);
        else
          shf_putc(*p, shf);
      }
      shf_putc('\'', shf);
    }
  }

  cmd = shf_sclose(shf);
  rv = command(cmd, 0);
  afree(cmd, ATEMP);
  return rv;
}

/* Number of words in wp, argv-style. */
static int zos_argc(char **wp) {
  int n = 0;

  while (wp[n] != NULL)
    n++;
  return n;
}

/*
 * tso: run a TSO/E command.
 *
 * Usage: tso command [arg ...]
 *
 * The in-process path (IKJTSOEV) is deliberately not attempted yet: it
 * needs authorization, and getting it wrong under TSO takes the
 * session down instead of returning an error.  A spawn per command is
 * the honest starting point.
 */
int b_tso(char **wp) {
  if (zos_argc(wp) < 2) {
    bi_errorf("usage: tso command [arg ...]");
    return 2;
  }
  return zos_defer("tsocmd", wp, 1, 0);
}

/*
 * alloc: allocate an MVS data set or DD.
 *
 * Usage: alloc "dsn('HLQ.TEMP.DATA') new catalog"
 *        alloc dsn\(\\\'HLQ.TEMP.DATA\\\'\) new catalog
 *
 * TSO/E ALLOC takes one operand string, so the arguments are joined
 * with spaces before they are quoted.
 */
int b_alloc(char **wp) {
  if (zos_argc(wp) < 2) {
    bi_errorf("usage: alloc \"dsn('HLQ.DS') [new] [catalog]\" ...");
    return 2;
  }
  return zos_defer("tsocmd ALLOC", wp, 1, 1);
}

/*
 * free: reverse an alloc (or free what JCL provided).
 *
 * Usage: free "dsn('HLQ.DS')" | free dd\(NAME\) | free all
 */
int b_free(char **wp) {
  if (zos_argc(wp) < 2) {
    bi_errorf("usage: free \"dsn('HLQ.DS')\" | dd(NAME) | all");
    return 2;
  }
  return zos_defer("tsocmd FREE", wp, 1, 1);
}

/*
 * zosclass: print how this session is running -- omvs, telnet, rlogin
 * or batch -- so a profile can branch.
 *
 * One word, no arguments, so it composes as `case $(zosclass) in'.
 *
 * Under TSO/E there is no controlling terminal (isatty(0) is false), so
 * a line-mode TSO session reports `batch'.  When stdin is a terminal,
 * _BPX_TERMPATH names the terminal driver and is the only distinction
 * the system makes; telnet and rlogin both hand out a pty.
 */
int b_zosclass(char **wp) {
  const char *p;

  if (zos_argc(wp) > 1) {
    bi_errorf("usage: zosclass");
    return 2;
  }
  if (!isatty(STDIN_FILENO)) {
    shprintf("batch\n");
    return 0;
  }
  p = str_val(global("_BPX_TERMPATH"));
  if (p != NULL) {
    if (strstr(p, "telnet") != NULL) {
      shprintf("telnet\n");
      return 0;
    }
    if (strstr(p, "rlogin") != NULL) {
      shprintf("rlogin\n");
      return 0;
    }
  }
  shprintf("omvs\n");
  return 0;
}

/* Print one file's tag, in chtag -p's format. */
static void zos_print_tag(const char *file) {
  struct stat st;
  char name[64];

  if (stat(file, &st) < 0) {
    bi_errorf("%s: %s", file, strerror(errno));
    return;
  }
  if (st.st_tag.ft_ccsid == 0) {
    shprintf("- untagged     %s\n", file);
    return;
  }
  if (st.st_tag.ft_ccsid == 65535) {
    shprintf("b binary       %s\n", file);
    return;
  }
  if (__toCSName(st.st_tag.ft_ccsid, name) != 0)
    snprintf(name, sizeof(name), "%u", (unsigned)st.st_tag.ft_ccsid);
  shprintf("%c %-12s %s\n", st.st_tag.ft_txtflag ? 't' : 'm', name, file);
}

/*
 * chtag: the `-p' (print) form in process; every other form defers to
 * /bin/chtag.  Reading a tag is a stat(); spawning for it is waste, and
 * the shell already cares which files are text.
 *
 * Usage: chtag -p file ...      (in process)
 *        chtag [anything else]  (deferred to /bin/chtag)
 */
int b_chtag(char **wp) {
  int i;

  if (wp[1] != NULL && strcmp(wp[1], "-p") == 0) {
    if (wp[2] == NULL) {
      bi_errorf("usage: chtag -p file ...");
      return 2;
    }
    /* A second option means the caller wants something -p alone does
     * not do (chtag -p -R dir, say): let the real chtag have it. */
    for (i = 2; wp[i] != NULL; i++)
      if (wp[i][0] == '-')
        return zos_defer("/bin/chtag", wp, 1, 0);
    for (i = 2; wp[i] != NULL; i++)
      zos_print_tag(wp[i]);
    return 0;
  }
  return zos_defer("/bin/chtag", wp, 1, 0);
}

/*
 * extattr: defers to /bin/extattr.  The in-process forms (+a/-a, +p,
 * +s, +l) need z/OS extended attributes and are not written yet; the
 * builtin exists now so a script can rely on the name.
 */
int b_extattr(char **wp) {
  if (zos_argc(wp) < 2) {
    bi_errorf("usage: extattr [+-a +-p +-s +-l ...] file ...");
    return 2;
  }
  return zos_defer("/bin/extattr", wp, 1, 0);
}

#else /* !__MVS__ */

/*
 * Off z/OS these names still exist, and say so.  Status 2 is a usage
 * error for a builtin, and docs/zos-changes.md documents it as the
 * contract: a script can test for availability without having to tell
 * "not found" from "not applicable".  bi_errorf() already prefixes the
 * builtin's own name, so the message must not repeat it.
 */
#define zos_unavailable() (bi_errorf("only available on z/OS"), 2)

int b_tso(char **wp) {
  (void)wp;
  return zos_unavailable();
}
int b_alloc(char **wp) {
  (void)wp;
  return zos_unavailable();
}
int b_free(char **wp) {
  (void)wp;
  return zos_unavailable();
}
int b_zosclass(char **wp) {
  (void)wp;
  return zos_unavailable();
}
int b_chtag(char **wp) {
  (void)wp;
  return zos_unavailable();
}
int b_extattr(char **wp) {
  (void)wp;
  return zos_unavailable();
}

#endif /* __MVS__ */
