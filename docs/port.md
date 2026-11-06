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

**B1-B4 below are superseded**, kept so the reasoning is not lost: the
oksh `configure` script was replaced by the CMake build
(`docs/build.md`), and the z/OS branch named in B1 lives in
`cmake/toolchain-zos.cmake` rather than in `configure`. B2 landed
(P13/P24 era). Nothing in this table is outstanding.

| # | Item | Decision |
| - | ---- | -------- |
| B1 | ~~`configure`: detect `__MVS__`, set `-D_ALL_SOURCE`, add z/OS objects~~ | superseded: CMake, `cmake/toolchain-zos.cmake`. The macros are in `CMakeLists.txt` (ZKSH_ZOS) and `cmake/checks.cmake`, in both on purpose |
| B2 | `_BPX_JOBNAME` value is `OKSH` | **done** -- `ZKSH` |
| B3 | `PROG`/`KSHELL` name in `configure` | **done** -- the target is `zksh` |
| B4 | Link `-lcurses` vs z/OS terminfo/ncurses | **done** -- zopen's static `libncursesw.a` by path, found by the toolchain (P9, P24) |

### Character set

| # | File | Item | Decision |
| - | ---- | ---- | -------- |
| C1 | `lex.c`, `tree.h` | in-band `QUOTE`/`QUOTES` control bytes in words | audit; if they collide with EBCDIC characters, adopt zash's parallel origin-mark array |
| C2 | `table.c` | builtin/keyword tables assumed ASCII-sorted or contiguous | verify sort is done with `strcmp`, not assumed order |
| C3 | `expand.c` | range patterns `[a-z]` | verify against IBM-1047 collation |
| C4 | `emacs.c`, `vi.c` | hard-coded ASCII control characters; `case '\r': case '\n':` collapse to one value on z/OS | **partly done** — the colliding labels are gone (a value test instead); `CTRL(x) ((x) & 0x1F)` is still ASCII-only |


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
| P13 | `misc.c`, `portable.h`, build | `setgroups()` needs `_OPEN_SYS` on z/OS, and `<grp.h>` was included only on Linux | **done** — `_OPEN_SYS` added to build and checks, `<grp.h>` included unconditionally |
| P14 | `src/zos_spawn.c`, `CMakeLists.txt` | duplicate `zos_spawn.c` -- one at `src/`, one at `src/zos/`, both compiled | **done** -- `src/zos/` copy removed; `main.c`/`jobs.c` `#include "zos_spawn.h"` from `src/` |
| P15 | `zos_spawn.c`, build | `setenv()` needs `_UNIX03_SOURCE` on z/OS | **done** -- macro added to build and probes. **Retracted:** `_UNIX03_SOURCE` must not be set at all; see P24 |
| P15d | `main.c`, `checks.cmake` | `__sysconf`/`__fopen_ascii` unresolved at link, from a header, not from our code | **done** -- `confstr` probe forced off on z/OS. The forcing is right, the **reason was wrong**: `__sysconf` does not come from `confstr.c`, it comes from `libncursesw.a` (P24) |
| P15c | `zos_spawn.c` | `setenv` undeclared without `_UNIX03_SOURCE`, and `_UNIX03_SOURCE` breaks the static link | **done** -- no `setenv` at all: `putenv()` with static strings, which needs no feature macro. Kept: it is correct on its own terms, and independent of the link failure |
| B2 | `zos_spawn.c` | `_BPX_JOBNAME` said `OKSH` | **done** -- `ZKSH` |
| P15b | build, `trap.c`, `strsignal.c` | the link failed with IEW2456E for `__fopen_ascii`, `__sysconf`, `strsignal` | **done** — `_UNIX03_SOURCE` dropped; `_POSIX_C_SOURCE=200809L` instead; `strsignal` probed with an `oksh_strsignal` fallback. **Partly retracted:** the two `__` symbols were ncurses's, not `_UNIX03_SOURCE`'s; only the `strsignal` half of this entry was ever the real cause (P24) |
| P16 | `portable.h` | z/OS has no `st_mtim` (only `st_mtime`) and no `sig_t` typedef | **no change needed** — checks answer correctly, existing fallbacks apply |
| P17 | `path.c`, `exec.c` | `_PATH_DEFPATH` and default `PATH` | z/OS default `/bin:/usr/bin` plus `/usr/local/bin` |
| P18 | `exec.c` | `execve` `ENOEXEC` fallback shell | point at `zksh` or `/bin/sh`, deliberately |
| P19 | `c_ulimit.c` | `getrlimit`/`setrlimit` resource names | z/OS supports address space, file size, CPUTIME; map, document the rest |
| P20 | `mail.c` | `MAIL`/`MAILPATH` stat checks | verify `stat()` on `/u/...` mailboxes |
| P21 | `tty.c`, `jobs.c` | `tcsetpgrp` under a line-mode OMVS session | must degrade without error |
| P22 | `signame.c`, `siglist.c` | signal name table | verify z/OS signal names match the table |
| P23 | `c_test.h`, `edit.h` | neither header is self-contained | **done** -- the clang-format run (62cbee2) sorted includes and thereby moved `c_test.h`/`edit.h` in front of `sh.h` in `c_test.c`, `exec.c`, `syn.c`, `edit.c`, `emacs.c`, `vi.c`; both headers only worked because the includer had already pulled in the definition. `c_test.h` now forward-declares `struct XPtrV`, `edit.h` includes `<stdbool.h>`. Measured: reverting them fails the build with `unknown type name 'XPtrV'` and `unknown type name 'bool'` |
| P24 | `CMakeLists.txt`, `src/zos/link_driver.c` | the z/OS link failed with IEW2456E for `__fopen_ascii` and `__sysconf` | **done, pending z/OS confirmation** -- see below |

### P24: what actually failed to link, and why

The earlier entries blamed `_UNIX03_SOURCE` and `confstr()`. Both were
wrong. Bisected on the z/OS host against the real object set:

```
var.c.obj alone                                -> clean link
var.c.obj + libncursesw.a (either zopen copy)  -> __sysconf, __fopen_ascii
```

Those two are Language Environment services that the zopen ncurses
archives reference. They are resolved when `ibm-clang64` puts the LE
C runtime linkage on the link command -- which it does when a **C
source file** is among the inputs. CMake links objects only, so an
archive that expects the CRT comes up short. Hence
`src/zos/link_driver.c`: an empty translation unit whose only purpose
is to be a source file on the link line. It is a link flag in the only
form CMake passes through unchanged. Do not delete it for looking
empty.

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
