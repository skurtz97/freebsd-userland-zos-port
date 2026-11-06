# Port notes: edits to the oksh base

The base under this tree is oksh 7.9 with a small set of edits. This
file is the ledger: one entry per edit, naming the file, the reason
and the decision. An edit without an entry here is a bug in the
process.

Marker convention: an edited site gets a comment beginning
`/* zos: `.

Base pin: `ibara/oksh` tag **oksh-7.9**, commit **15f69e4**
(2026-06-10).

## Inherited edits (from `~/src/oksh`, branch `zos-spawn`)

Committed as **3d04c43** in `~/src/oksh` before this tree was made.
Carried here unchanged.

| # | File | Edit | Reason | State |
| - | ---- | ---- | ------ | ----- |
| P1 | `zos_spawn.c`, `zos_spawn.h` | new: `spawnp()` process creation | fork copies the z/OS address space; spawn does not | inherited, unverified on z/OS |
| P2 | `configure` | `zos_spawn.o` added to `OBJS` | new object | inherited |
| P3 | `main.c` | `zos_spawn_init()` before anything else | set `_BPX_SHAREAS=YES`, `_BPX_JOBNAME` | inherited |
| P4 | `jobs.c` | `zos_spawn_child()` before the fork loop in `exchild()` | take the no-fork path when possible | inherited |
| P5 | `doc/ZOS-NOTES.md` | new: the cost model and how to measure | rationale | inherited |

## Planned edits (not made yet)

Found by reading the tree and the z/OS reference books. Each is
**open** until made and built on both platforms.

### Build

| # | Item | Decision |
| - | ---- | -------- |
| B1 | `configure`: detect `__MVS__`, set `-D_ALL_SOURCE`, add z/OS objects | The oksh configure is a `sh` script; add a case rather than a second build system |
| B2 | `_BPX_JOBNAME` value is `OKSH` | rename to `ZKSH` |
| B3 | `PROG`/`KSHELL` name in `configure` | `zksh` |
| B4 | Link `-lcurses` vs z/OS terminfo/ncurses | verify which library z/OS supplies for the editing code |

### Character set

| # | File | Item | Decision |
| - | ---- | ---- | -------- |
| C1 | `lex.c`, `tree.h` | in-band `QUOTE`/`QUOTES` control bytes in words | audit; if they collide with EBCDIC characters, adopt zash's parallel origin-mark array |
| C2 | `table.c` | builtin/keyword tables assumed ASCII-sorted or contiguous | verify sort is done with `strcmp`, not assumed order |
| C3 | `expand.c` | range patterns `[a-z]` | verify against IBM-1047 collation |
| C4 | `emacs.c`, `vi.c` | hard-coded ASCII control characters | zash solved this in libedit with `EL_*` constants; oksh's editor code needs the same treatment or must defer to libedit |

### Compiler and headers (Open XL C/C++ 2.1)

| # | File | Item | Decision |
| - | ---- | ---- | -------- |
| P6 | many | `<sys/param.h>` does not exist on z/OS | **done** — `check_include_file`, guarded include, `MAXLOGNAME` probed separately (`HAVE_MAXLOGNAME`) |
| P7 | `confstr.c`, `exec.c`, `main.c`, `portable.h` | no `<paths.h>` on z/OS; `_PATH_BSHELL`/`_PATH_DEFPATH`/`_PATH_STDPATH` | **done** — `check_include_file(paths.h)`, guarded includes, existing `#ifndef` fallbacks now apply |
| P8 | `edit.c` | `_POSIX_VDISABLE` undefined | **done** — `portable.h` defines it as 0, as POSIX directs |
| P9 | `emacs.c`, `var.c` | zopen ncurses `term.h` includes `<ncursesw/ncurses_dll.h>`, so the parent of `include/ncursesw` must be on the include path | **done** — toolchain records `ZKSH_CURSES_EXTRA_INCLUDE` |
| P10 | `history.c`, `portable.h` | `flock()` needs `<sys/file.h>` and `_XPLATFORM_SOURCE` on z/OS; absent systems need a no-op | **done** — `HAVE_FLOCK` probed, `<sys/file.h>` included for `__MVS__`, `flock` falls back to 0 |
| P11 | `jobs.c`, `portable.h` | no `WCOREDUMP` on z/OS (a BSD bit in the wait status) | **done** — `HAVE_WCOREDUMP` probed; falls back to 0, so the shell never claims a core dump |
| P12 | `portable.h`, `CMakeLists.txt` | `timeradd`/`timersub` exist under `_XPLATFORM_SOURCE`, `timerclear` does not | **done** — each timer macro probed separately, `_XPLATFORM_SOURCE` added to build and checks |
| P13 | `path.c`, `exec.c` | `_PATH_DEFPATH` and default `PATH` | z/OS default `/bin:/usr/bin` plus `/usr/local/bin` |
| P14 | `exec.c` | `execve` `ENOEXEC` fallback shell | point at `zksh` or `/bin/sh`, deliberately |
| P15 | `c_ulimit.c` | `getrlimit`/`setrlimit` resource names | z/OS supports address space, file size, CPUTIME; map, document the rest |
| P16 | `mail.c` | `MAIL`/`MAILPATH` stat checks | verify `stat()` on `/u/...` mailboxes |
| P17 | `tty.c`, `jobs.c` | `tcsetpgrp` under a line-mode OMVS session | must degrade without error |
| P18 | `signame.c`, `siglist.c` | signal name table | verify z/OS signal names match the table |

### Language

| # | Item | Decision |
| - | ---- | -------- |
| L1 | `${v/pat/rep}`, `${v//pat/rep}` | first addition; pattern syntax is D2 in `direction.md` |
| L2 | `${v^^}`, `${v,,}` | decide with L1 |

## Deleted prior work

- The FreeBSD `bin/sh` import (2026-11-02) and its git history were
  deleted on 2026-11-05 before any port edit was made. Nothing from
  it is reused. Pin, if ever needed: `freebsd/freebsd-src`
  `release/15.1.0`, `96841ea08dcfa84b954a32dc5ae1a26c28966cf4`.
