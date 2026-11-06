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
- emacs/vi line editing: compiled in, not driven through a pty here.
- `select`: parses, not driven interactively.

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
- `tso`, `alloc`, `free`, `zosclass` (not written yet), `_TAG_REDIR_*`,
  MVS data set redirection.

## Gaps against the direction

| Gap | Consequence | Next |
| --- | ----------- | ---- |
| `${v/pat/rep}` missing | bash-era scripts fail with "bad substitution" | first language task; pattern syntax undecided (D2) |
| `tso`/`alloc`/`free`/`zosclass` absent | z/OS convenience missing | port zash's `zos_builtins.c` shape, add `alloc`/`free` |
| No `_TAG_REDIR_*` | redirected files untagged | port from zash `sys_zos.c` |
| No MVS data set redirection | `> //'HLQ.DS'` unsupported | port from zash |
| In-band `QUOTE` bytes in words | EBCDIC risk | audit; consider zash's origin-mark array |
| No test runner beyond oksh's | no regression gate | decide harness |

## Next milestone

**Reached 2026-11-06**: the z/OS build produces a shell that runs
`./build-zos/zksh -c 'print hi'`, and every fix is in
[port.md](port.md). The next milestone is `${v/pat/rep}` with a test
that fails today.

## Open items

- **D1 install name** — `zksh` only, or also `sh`?
- **D2** pattern syntax for `${v/pat/rep}`.
- **D3** `alloc`/`free` scope.
- **D4** line-mode editing.
- **D5** rebase on oksh upstream, or fork permanently at 7.9.
- **Remote.** This tree has no remote yet. That is the first thing to
  fix; the previous tree was lost because it had none.
