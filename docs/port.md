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
| B1 | ~~`configure`: detect `__MVS__`, set `-D_ALL_SOURCE`, add z/OS objects~~ | superseded: CMake, `cmake/toolchain-zos.cmake`. The macros are in `CMakeLists.txt` (FSH_ZOS) and `cmake/checks.cmake`, in both on purpose |
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
| P9 | `emacs.c`, `var.c` | zopen ncurses `term.h` includes `<ncursesw/ncurses_dll.h>`, so the parent of `include/ncursesw` must be on the include path | **done** — toolchain records `FSH_CURSES_EXTRA_INCLUDE` |
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
| P24 | `cmake/toolchain-zos.cmake`, `CMakeLists.txt` | the z/OS link failed with IEW2456E for `__fopen_ascii` and `__sysconf` | **done** -- the missing libraries are zoslib's; see below |

### P24: what actually failed to link, and why

The earlier entries blamed `_UNIX03_SOURCE` and `confstr()`. Both were
wrong, and so was the first fix attempted here.

**Wrong fix, kept in the record.** The theory was that `ibm-clang64`
adds the Language Environment C runtime linkage only when a C source
file is on the link command, so an empty translation unit
(`src/zos/link_driver.c`) would bring it back. It linked nothing: the
same two symbols failed with the driver's object in the target. The
file is deleted and the CMake block with it. An empty `.c` that is
supposed to change link behaviour is a claim about the driver, not a
measurement.

**Measured cause.** Reproduced on the host with a four-line curses
program, so zksh is not involved at all:

```
$ ibm-clang64 t.c -I.../include/ncursesw -I.../include
$ ibm-clang64 t.obj /usr/local/zopen/usr/local/lib/libncursesw.a -o t
  IEW2456E SYMBOL __sysconf UNRESOLVED. MEMBER COULD NOT BE INCLUDED
  FROM THE DESIGNATED CALL LIBRARY.
```

`nm -u libncursesw.a` names the unresolved symbols:
`__fopen_ascii`, `__sysconf`, `__strerror_ascii`. Those are **zoslib**
functions -- the zopen tree's ASCII-runtime shims -- not Language
Environment services, and not anything `_UNIX03_SOURCE` controls. The
ncurses package's own `pkg-config --libs ncursesw` says so:

```
-L.../ncurses/lib -Wl,-bcompress=yes -m64 -L.../zoslib/zoslib/lib
  .../celquopt.s.o -lncursesw -lzoslib .../celquopt.s.o -lzoslib-supp
```

Bisected to the minimum for a C caller:

```
libncursesw.a + -lzoslib                -> __cxa_guard_abort, std::to_string
libncursesw.a + -lzoslib -lzoslib-supp  -> links
```

So `libzoslib.a` supplies the ASCII runtime and `libzoslib-supp.a` the
C++ support that ncurses' C++ members reference; `celquopt.s.o` is for
C++ exception qualifiers and is not needed here.

The toolchain now locates zoslib next to the ncurses package, sets
`FSH_CURSES_LINK_ITEMS`, and warns loudly rather than producing an
archive that cannot bind. `-DFSH_ZOSLIB_LIBDIR=<dir>` overrides.

### Formatter hazard (found with P23)

`clang-format` sorts includes. oksh's headers are not self-contained and
many `.c` files relied on `sh.h` coming first, so a format run can
break the build in ways that look like compiler problems. When a format
commit is made, build afterwards, and treat any new
"unknown type name" as a header that needs its own include or forward
declaration.

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

| P25 | `trap.c` | `strcasecmp()`/`strncasecmp()` were undeclared | **done** -- added `<strings.h>`, which is where POSIX declares them. oksh never noticed: glibc's `<string.h>` declares them under `_GNU_SOURCE`, and zopen's shared include tree happened to declare them too. Narrowing the ncurses include path (P9) removed the accident and the z/OS build said so: `call to undeclared library function 'strcasecmp' ... ISO C99 and later do not support implicit function declarations` |

| P26 | `portable.h`, `cmake/checks.cmake`, `cmake/pconfig.h.in` | `reallocarray()`, `setresuid()`, `setresgid()` were undeclared in `history.c` and `misc.c` once `HAVE_*` became true | **done** -- "the symbol links" and "a header declares it" are two questions, and z/OS answers them differently: the shell links zoslib (ncurses needs it), zoslib supplies these symbols, and no system header declares them. Every function in `FSH_FUNCS` that links now also gets `HAVE_x_DECL` from a compile-only probe (`(void)fn;`), and `portable.h` declares the prototype unless both macros are set. Found immediately after the probe fix in P25/P27 |
| P27 | `cmake/checks.cmake` | `check_function_exists()` reported every function absent on every platform | **done** -- the loop pre-set `HAVE_x` to 0 "so a stale cached answer cannot survive", but the module runs only `if(NOT DEFINED ...)`, so the probes were skipped and a skip is indistinguishable from "not found". Fedora: `HAVE_STRLCAT` undef although glibc has it. Now `unset()` (normal and CACHE) before each check. On z/OS the probes also link `FSH_CURSES_LINK_ITEMS`, because the shell does |

## Feature edits (2026-11-06)

Edits to base files that add a documented language feature, rather than
making an existing one compile on z/OS.

| # | File | Edit | Reason | State |
| - | ---- | ---- | ------ | ----- |
| L1 | `lex.c` | new lexer state `SREBSUB`: after `${var`, an unquoted `/`, `//`, `/#` or `/%` starts the replacement qualifier; the *next* unquoted `/` is emitted as `OREPSUB` and the rest is the replacement | `${v/pat/rep}` did not exist in pdksh; docs/language.md Level 2 | **done**, tested (`tests/param.sh`) |
| L2 | `tree.h` | new control code `OREPSUB` (12) separating pattern from replacement | the replacement is not a pattern, so the split must be explicit rather than found by scanning expanded text | **done** |
| L3 | `tree.c` | `wdscan()`, `wdstrip()`, the trees printer and `snptreef()` all know `OREPSUB` (`/` when printing back, nothing when stripping) | a new control code that the word walkers ignore corrupts every enclosing word | **done** |
| L4 | `eval.c` | `varsub()` recognises `/` and the three anchored forms; `c == '/'` expands the word instead of skipping it (it is not in `C_SUBOP2`, which is what made the first attempt a silent no-op); `replacesub()` does the substitution; arrays and `$*`/`$@` are refused like `${v#pat}` | the feature itself | **done** |
| L5 | `sh.h`, `c_ksh.c` | prototypes and `builtins[]` entries for the six z/OS builtins | `tso`, `alloc`, `free`, `zosclass`, `chtag`, `extattr` (docs/zos-changes.md) | **done** off z/OS (status 2); z/OS paths unverified |
| L6 | `zos_builtins.c` (new) | the z/OS dialect builtins | see docs/zos-changes.md | **done** off z/OS; the `__MVS__` branch has never been compiled |

Two things this cost, recorded so they are not relearned:

- `gmatch_()`'s `has_globbing()` **only understands MAGIC-escaped
  patterns**. Passing it a `debunk()`ed `@(X)` makes it fall back to
  `strcmp` and never match. The trims work because they hand it the raw
  `ds` bytes; `replacesub()` must do the same, and `debunk()` is only
  for printing.
- `Xinit()` allocates from `ATEMP`, the same area the caller's pattern
  and replacement often live in, so a naive implementation corrupts its
  own arguments mid-scan. `replacesub()` copies them first.

## P28 / P29 (2026-11-07): the first z/OS compile of `zos_builtins.c`, and a script-reading defect

| # | File | Edit | Reason | State |
| - | ---- | ---- | ------ | ----- |
| P28 | `CMakeLists.txt`, `cmake/checks.cmake`, `src/zos_builtins.c` | `_OPEN_SYS_FILE_EXT` added to the z/OS feature-macro stack | `struct stat`'s `st_tag` (`ft_ccsid`, `ft_txtflag`) does not exist without it. AGENTS.txt 2a says the macros are the first thing to check and lists each one with the interface it hides; this one was missing, so `zos_builtins.c` had never compiled: `no member named 'st_tag' in 'struct stat'` (5 errors). The CRTL reference's `__chattr` example states the `#define` line. Added to the target **and** the probes (2a: "add the macros to both or the probe lies") | **done**: `zos_builtins.c` compiles and links on z/OS for the first time |

### P29: zksh cannot run a *tagged* script on z/OS

Found while checking that the newly-built `tests/zos.sh` passed. It
did not, and neither did any other script in the suite — `ctest`'s
`regression` case was failing on z/OS, and the "4/4 green" in
docs/status.md covered only the four `-c` smoke tests.

**Measured, on a clean build of the committed tree, with a script that
holds EBCDIC bytes (`97 99 89 95 A3 40 D6 D2 15` = `print OK`):**

| File tag | Result |
| -------- | ------ |
| untagged | `OK`, status 0 — **works** |
| `IBM-1047` | `f.sh[2]: pri: not found`, status 127 — **fails** |

**Why.** Reading a *tagged* file inside zksh returns **ASCII** bytes,
even though zksh is a native EBCDIC program (`'A'` compiles to `0xC1`,
`'\n'` to `0x15`, `' '` to `0x40`, all checked). Instrumenting
`getsc_line()` and a bare `open()`+`read()` in `main.c` showed the same
nine bytes for `print OK\n` (`70 72 69 6e 74 20 4f 4b 0a`) where the
file holds `97 99 89 95 a3 40 d6 d2 15`. So automatic conversion is
converting **EBCDIC to ASCII** for this program, and every comparison
against a string literal then fails: `\n` is `0x15` in the code and
`0x0a` in the buffer, so the newline is not a separator, the line never
ends, and the leftover fragment becomes a command name.

Established while narrowing it:

- A standalone `ibm-clang64` program reading the same file gets the
  true EBCDIC bytes, with or without zoslib linked, so the conversion
  is not "zoslib's `open()`".
- `_BPXK_AUTOCVT=ON`, `OFF`, empty and unset all convert; so does
  `_TAG_REDIR_IN=BIN`. It is the **file tag** that decides, not the
  environment variable.
- `shf_open()`'s `fcntl(fd, F_DUPFD, FDBASE)` is innocent: `dup()`,
  `dup2()` and `F_DUPFD` all preserve the raw EBCDIC bytes.
- `F_CONTROL_CVT` (`_OPEN_SYS_FILE_EXT`), `F_SETTAG` and `__chattr()`
  are the documented controls. The unsettled question is *which*
  mechanism is converting and why it chose ASCII as the target.

**Ordered next steps, cheapest first:**

1. `setlocale(LC_ALL, "")` early in `main()`. The z/OS UNIX User's
   Guide (BPXA400, "Shell scripts") says a script's code page must
   match the locale it runs in; zksh never calls `setlocale()`, so the
   conversion target has nothing but a default to go on.
2. `fcntl(fd, F_CONTROL_CVT, 0)` after `shf_open()`'s `open()`, if
   step 1 is not the whole answer. That is zash's `_TAG_REDIR_IN`
   mechanism, and docs/zos-changes.md already lists porting it.
3. Only if both fail: whether the shell should call `setlocale()` at
   all, or whether z/OS wants scripts to be untagged. `_BPXK_AUTOCVT`'s
   three settings are `ON`, `OFF` and `ALL`; the shell may need to
   scrub it for its own reads.

**Consequence for everything else in this tree.** Every `tests/*.sh` is
UTF-8-tagged (that is what git and `chmod` leave, and it is correct:
they are ASCII text), so the suite cannot pass on z/OS until this is
fixed. The tests are not wrong and must not be re-tagged to hide it —
AGENTS.txt 3 says a file's character set is its chtag, and a test file
of ASCII text is properly tagged UTF-8. Do not "fix" this by converting
the test scripts to IBM-1047.
