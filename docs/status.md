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

## Inherited, not compiled on z/OS

- `zos_spawn.c` / `zos_spawn.h` and `doc/ZOS-NOTES.md`: commit
  `3d04c43` (branch `zos-spawn` in `~/src/oksh`). Gated on `__MVS__`
  and compiled to an empty object on Linux (verified: 0 bytes).
- Hooks in `main.c` (`zos_spawn_init`) and `jobs.c` (`exchild`).

Every statement about z/OS behaviour in these documents is from
documentation until a real build says otherwise.

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

Make `make` on z/OS produce a shell that runs `./zksh -c 'print hi'`,
and log every fix in [port.md](port.md). The second milestone is
`${v/pat/rep}` with a test that fails today.

## Open items

- **D1 install name** — `zksh` only, or also `sh`?
- **D2** pattern syntax for `${v/pat/rep}`.
- **D3** `alloc`/`free` scope.
- **D4** line-mode editing.
- **D5** rebase on oksh upstream, or fork permanently at 7.9.
- **Remote.** This tree has no remote yet. That is the first thing to
  fix; the previous tree was lost because it had none.
