# Goose notes and memory -- zksh
#
# Durable notes for goose sessions. Read this first in a new session;
# update it at the end of one. Decisions with reasons belong in
# docs/direction.md so code, docs and this file never disagree.

## The project in one line
zksh = oksh 7.9 (pdksh/ksh88) ported to z/OS UNIX, plus an aggressive
z/OS layer (tso/alloc/free/zosclass builtins, spawnp-first, tagging).
Repo: /home/skurtz/src/zksh. Docs: docs/README.md (index),
docs/direction.md (constitution), docs/status.md (what works).

## History of the decision (do not relitigate without new facts)
- 2026-11-02: started an ash-first import of FreeBSD bin/sh at
  ~/src/freebsd-sh-port-zos. Built docs; no code ported.
- 2026-11-03..05: user chose the name zksh and the direction
  "ash + ksh features, tso as a builtin, more POSIX than bash,
  aggressively non-POSIX for z/OS".
- 2026-11-05: **that tree was deleted with its git history** (commit
  a7b28f2 gone; no btrfs snapshots). Only docs/direction.md,
  language.md and budget.md survived and were carried into the new
  tree.
- 2026-11-05: inspected ~/src/zash (fresh 7.2k-line ash, own remote,
  z/OS tagging + cvtprobe) and ~/src/oksh (oksh 7.9 + zos_spawn.c,
  doc/ZOS-NOTES.md, uncommitted). Committed oksh work as 3d04c43 on
  branch zos-spawn. **Base changed to oksh** (ksh-first), zash kept
  as reference. docs/direction.md records why.

## Environment
- Linux dev: Fedora 44, clang 22, clang-format 21+, clang-tidy 22,
  ncurses 6.6 (ncursesw), GNU make, bash 5.3, gawk 5.3.
- z/OS: Open XL C/C++ 2.1 (ibm-clang64, clang 18) on z16; zopen
  provides make/bash/gawk/ncurses(widec) but not libedit.
- goose's working directory is ~/src (changed 2026-11-05; it used
  to be ~/src/zrx). Project paths are relative to it: zksh/, oksh/,
  zash/, zrx/. Still prefer absolute paths in commands that another
  session might copy.
- Reference books (grep, never guess):
  /home/skurtz/docs/mainframe/txt/zos-c-runtime-library.txt
  /home/skurtz/docs/mainframe/txt/zos-unix-command-reference-bpxa500_v3r2.txt
  /home/skurtz/docs/mainframe/txt/zos-unix-users-guide-bpxa400_v3r2.txt

## Verified facts about the base (2026-11-05, Linux)
- Builds with ./configure && make -j8, links lld, 804 KB / 269 KB
  stripped, starts in 0.43 ms, RSS 2.33 MB.
- Has: (( )), set -A, typeset, local, print, [[ ]], let, whence,
  select, trap, job control, coprocs (untested), emacs/vi.
- **Does NOT have ${v/pat/rep}** ("bad substitution"). First language
  task.
- zos_spawn.c compiles to a 0-byte object on Linux (gated on __MVS__).

## Companion repos (do not merge accidentally)
- ~/src/oksh  : upstream + zos-spawn branch (source of this base)
- ~/src/zash  : ash reference implementation, own remote, NOT vendored
- ~/src/zrx   : unrelated (REXX)

## Remotes (set up 2026-11-05, do not lose them)
- zksh:   git@github.com:skurtz97/zksh.git  (private, main -> 3397739)
- oksh:   git@github.com:skurtz97/oksh.git  (fork; branch zos-spawn
          -> 3d04c43, pushed via the `zfork` remote in ~/src/oksh)

## Open questions for the user
- D1 install as zksh only, or also sh?
- D2 pattern syntax for ${v/pat/rep}
- D3 alloc/free scope (DSN, DD, TSO ALLOC)
- D4 line-mode editing: numbered history vs libedit dumb profile
- D5 rebase on oksh upstream or fork at 7.9
- Whether zksh stays private or goes public

## Next actions
1. ~~Set a git remote and push~~ done 2026-11-05.
2. ~~First z/OS build~~ **done 2026-11-06**: builds, links, runs,
   `ctest` on the z/OS host. Fixes P23-P27 in docs/port.md.
3. ~~Line editing and job control through a pty~~ **done 2026-11-06**,
   both work (docs/status.md). Still open: co-processes, and whether
   `zos_spawn_child()` is really the path taken (P1-P5).
4. ~~`${v/pat/rep}`~~ **done 2026-11-06**: all four forms, ksh glob,
   D2 decided; `tests/param.sh` is the proof (docs/port.md L1-L4).
5. ~~`tso`/`chtag`/`extattr`~~ **done off z/OS** 2026-11-06, plus
   `alloc`/`free`/`zosclass` (src/zos_builtins.c). The __MVS__ bodies
   have never been compiled: first z/OS build is next.
6. `_TAG_REDIR_*` and MVS data set redirection -- src/zos/sys_zos.c.ref
   is the donor. This is the measured mixed-encoding gap.

## Testing lesson (2026-11-06)
The suite was red on the day it was committed: `history.out` had been
copied from zash (an ash shell) and described no ksh at all. Verify an
expectation against the base shell before blessing it -- and never
reformat a whole file to fix one function (clang-format -i on eval.c
was safe only because that file already conformed).

## z/OS host, as measured 2026-11-06
- ssh alias `cbt` (port 2022, user SKURTZ), OS/390 CBT 29.00,
  `~/src/zksh` is a clone of the GitHub repo; build there with
  `bash ./configure --zos --release --build-dir=build-zos`.
- PATH from a non-interactive ssh session is /bin only: put
  /usr/local/zopen/usr/local/bin on it, or call bash by full path.
- ibm-clang64 is NOT on PATH; CMake finds it under
  /usr/lpp/IBM/cnw/v2r1/openxl/bin.
- oksh is at ~/bin/oksh and runs the configure script that /bin/sh
  cannot.
- `git` is zopen's; `git pull` on the host is how code gets there.

## How to update this file
Short facts and pointers, not a log. Dated entries only for decisions
that might be revisited. Anything that becomes a rule moves to
README.md, AGENTS.txt or docs/ and is deleted here.
