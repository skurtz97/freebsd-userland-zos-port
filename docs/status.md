# Status

What works today, what is only designed, and what comes next.

Last rewritten: 2026-11-05, when the base changed to oksh.

## Implemented and verified on Linux

Built 2026-11-05 with clang 22, `./configure && make -j8`, and each
item below run through `./zksh -c`:

| Part | State |
| ---- | ----- |
| ksh88 language | `(( ))`, `set -A` arrays, `typeset`, `local`, `print`, `[[ ]]`, `let`, `whence`, `select` |
| Arithmetic | 64-bit `intmax_t`, `$(( ))` and `(( ))` |
| Functions, locals | `typeset` scoping verified (`in=local`, `out=global`) |
| Pipelines, command substitution | verified |
| `trap` | verified (USR1) |
| Job control | `set -m`, `&`, `wait`, job notification verified |
| Binary | 804 KB unstripped, 269 KB stripped |
| Startup | 0.43 ms (`-c ':'`, best of 30) |
| RSS | 2.33 MB |

## Present but not exercised here

- Co-processes (`|&`, `read -p`, `print -p`): in the source, untested.
- `select`: parses, not driven interactively.

## Verified on Linux, 2026-11-06

The three "unverified" claims of 2026-11-05 were settled by driving the
shell through a real pty (`pty.fork()`, python), not by reading code:

| Claim | Result |
| ----- | ------ |
| emacs/vi line editing | **works.** `^P` recalled the previous line without echoing it and re-ran it. The mode chosen was *vi*, because this machine exports `VISUAL=nvim` -- oksh's `V_VISUAL` handling is correct, and a user with no `VISUAL`/`EDITOR` gets emacs (`change_flag(FEMACS, ...)` in `main.c`). The earlier "the editor does not engage" reading was a test artifact: with `FMONITOR` off there is no `tty_state`, so raw mode cannot be entered. |
| job control | **works.** `sleep 30 &` printed `[1] <pid>`, `jobs` reported `[1] + Running`, `kill %1` stopped it. |
| `select` | parses; not driven interactively. |

`${v/pat/rep}` and its three siblings were added the same day; see
[docs/language.md](language.md) Level 2 for the rules and
`tests/param.sh` for the proof.

## Verified on z/OS (2026-11-06)

Host: z/OS 3.2 (CBT 29.00), Open XL C/C++ 2.1 (`ibm-clang64`, clang 18),
CMake 3.31 + Ninja from zopen, ncurses 6.6 wide static, zoslib.

| Part | State |
| ---- | ----- |
| Build | `bash ./configure --zos --release && cmake --build build-zos -j4` -- 0 errors, no binder messages, no duplicate-definition warning |
| Binary | 3,493,888 bytes, XPLINK 64-bit, static ncurses + zoslib |
| `-c` scripts | `print`, `echo $(( ))`, `set -A`, `typeset` scoping, `[[ ]]`, `for`, command substitution, `trap` + `kill -USR1` all verified |
| External commands | `zksh -c 'uname -a'` runs and its output reaches the parent |
| ctest | 4/4 -- `smoke_print`, `smoke_arith`, `smoke_array`, `smoke_typeset` |

Two facts that are not optional reading before writing a test here:

- **zksh's own output is IBM-1047.** `zksh -c 'print hi' > f` leaves
  bytes `88 89 15` in `f`, which `iconv -f IBM-1047` reads as `hi`.
  A z/OS program that writes EBCDIC is correct; do not "fix" it to
  ASCII for a test's convenience. `tests/run-c.sh` decodes instead.
- **External commands write ASCII**, because zopen's programs convert
  to ISO8859-1 when the destination is untagged. So
  `zksh -c 'print hi | cat' > f` puts ASCII `68 69 0A` in `f`, and a
  redirect that mixes builtin and external output mixes encodings.
  This is the `_TAG_REDIR_*` gap below, now measured rather than
  expected.

## Not verified on z/OS

- The `spawnp()` path in `zos_spawn.c` is compiled and linked; that it
  is the path actually taken, and its cost model, are unmeasured.
  (`doc/ZOS-NOTES.md` P1-P5 remain claims.)
- Job control (`set -m`, `&`, `wait`, notifications), co-processes.
- Line editing: linked against ncurses, never driven through a pty.
- `tso`, `alloc`, `free`, `zosclass`, `chtag`, `extattr`: written
  (`src/zos_builtins.c`), built on Linux where they answer "only
  available on z/OS" with status 2. Their `__MVS__` branch has **never
  been compiled**, let alone run.
- `_TAG_REDIR_*` and MVS data set redirection (still to port).

## Gaps against the direction

| Gap | Consequence | Next |
| --- | ----------- | ---- |
| `${v/pat/rep}` | **done** 2026-11-06: ksh-glob patterns (D2 decided), `tests/param.sh` | draft the `${v^^}`/`${v,,}` decision next (refused for now) |
| `tso`/`alloc`/`free`/`zosclass`/`chtag`/`extattr` | builtins exist and are tested off z/OS; the z/OS bodies have never compiled | first z/OS build of `src/zos_builtins.c` |
| No `_TAG_REDIR_*` | redirected files untagged | port from zash `sys_zos.c` |
| No MVS data set redirection | `> //'HLQ.DS'` unsupported | port from zash |
| In-band `QUOTE` bytes in words | EBCDIC risk | audit; consider zash's origin-mark array |
| no `ctest` gate over the script suite | regressions were invisible to CI | **done** 2026-11-06: CTest case `regression` runs `tests/run.sh` over all seven scripts |

## Next milestone

**Reached 2026-11-06**: `${v/pat/rep}` works, in all four documented
forms, with `tests/param.sh` as the proof -- and the script suite is now
gated by `ctest`. Next: compile `src/zos_builtins.c` on z/OS and correct
whatever the compiler says about `<_Ccsid.h>`, `st_tag` and `tsocmd`.

## Open items

- **D1 install name** — `zksh` only, or also `sh`?
- **D2** pattern syntax for `${v/pat/rep}` -- **decided 2026-11-06: ksh
  glob** (see docs/language.md).
- **D3** `alloc`/`free` scope.
- **D4** line-mode editing.
- **D5** rebase on oksh upstream, or fork permanently at 7.9.
- **Remote.** This tree has no remote yet. That is the first thing to
  fix; the previous tree was lost because it had none.
