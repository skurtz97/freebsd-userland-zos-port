# The merge: what came from where

One project, freebsd-userland-zos-port, from three trees. This file records the provenance
of every part so that "best of all the shells" is a list rather than
a claim.

| Source | Kept as | State |
| ------ | ------- | ----- |
| `ibara/oksh` oksh-7.9 (`15f69e4`) | `src/`, names unchanged | the engine |
| z/OS spawn work from `~/src/oksh` (`3d04c43`) | `src/zos/zos_spawn.c` | carried, unverified on z/OS |
| `~/src/zash` (own repo, `cbe8b62`) | donors, below | its ideas move here |
| FreeBSD `bin/sh` (deleted 2026-11-05) | nothing | pin recorded only |
| `~/src/zrx` | **out of scope** — a REXX compiler | — |

## What each shell contributed, and why

zash cannot be the engine: its own `DESIGN.md` "Not yet" list is job
control, `trap`, `kill` builtin, `getopts`, `printf` builtin,
`command`, `alias`, `ulimit`, `times` — all of which oksh already has.
So oksh is the engine and zash is the donor for everything z/OS and
everything interactive.

### From zash (phase 1 and later)

| Part | zash file | Why it wins over oksh's own |
| ---- | --------- | --------------------------- |
| `_TAG_REDIR_OUT/ERR/IN`, MVS data set redirection, IBM-1047 pipe tagging, untagged-input sniffing | `sys_zos.c` (394 lines) | oksh has none; this is measured behaviour, with `tools/cvtprobe.c` to re-measure |
| `tso`, `chtag -p` (native via `st_tag`), `extattr`, plus `alloc`, `free`, `zosclass` written for fsh | `zos_builtins.c` (125 lines donor) | oksh has none. Adapted 2026-11-06 into `src/zos_builtins.c` (312 lines) against oksh's own structures: `command()` for the deferral, `bi_errorf()`'s existing name prefix, one argument-quoting helper. The donor's `struct fdplan`/`sys_spawn` belong to zash and were not carried over. |
| bash-compatible `PS1`/`PS2` escapes (`\u \h \w \$ \e`, `\[ \]`) | `zprompt.c` (206 lines) | oksh's prompt has no escapes at all |
| Quote-aware completion: commands, builtins, functions, `$var`, files; PATH mtime cache | `complete.c` (494 lines) | oksh completes nothing |
| `HISTFILE`, `HISTSIZE`/`HISTFILESIZE`/`HISTCONTROL`, crash-safe append, SIGHUP save | `zhistory.c` (574 lines) | oksh has `fc` and a history list, not this |
| NetBSD libedit + z/OS port (`port/zos/`, `charset.c`, EBCDIC constants verified by probe) | `libedit/` (24 files) | oksh's built-in editor is `edit.c`/`emacs.c`/`vi.c` (5,706 lines) — Phase 2 decides |
| Test suite and 9 benchmarks | `tests/`, `bench/` | oksh's `make test` prints "No tests" |
| `cvtprobe` | `tools/cvtprobe.c` | — |

### From oksh (the base, already in)

Job control with process groups, `trap`, `getopts`, `printf`,
`alias`, `ulimit`, `times`, `command`, `typeset`, `set -A`, `let`,
`whence`, `print`, `[[ ]]`, `select`, arithmetic assignment,
co-processes, full ksh88.

### Adopted as an idea only

**zash's charset-neutral word representation** — raw text plus a
parallel origin-mark array, instead of oksh's in-band `QUOTE` control
bytes. It is welded to zash's own parser and evaluator; adopting it
means rewriting `lex.c`, `expand.c` and `tree.c`, which is a third
shell, not a port. It becomes a *reference* if oksh's in-band bytes
prove wrong under EBCDIC (port item C1).

## Phases

| Phase | Content | State |
| ----- | ------- | ----- |
| 0 | Repository structure and the CMake build. Sources moved to `src/`, names unchanged; oksh's `configure` and man pages were used as references; zash's donors staged | **done** — Linux build verified, behaviour identical to the pre-move build |
| 1 | z/OS layer: `tso`/`chtag`/`extattr` as builtins; `sys_zos.c` redirection; MVS data sets | staged |
| 2 | Interaction: `zhistory`/`complete`/`zprompt` on libedit; **replaces oksh's built-in editor** | not started |
| 3 | Close out `~/src/zash`: archive the repo, point it at fsh | not started |

## Rebase rule

Upstream oksh file names never change, and upstream files stay in
`src/`. Our code goes in `src/` under fsh names (`zos_builtins.c`,
`zos_spawn.c`), in `tests/`, `tools/`, `cmake/`, and the not-yet-built
donors stay in `src/zos/` as `.ref` files so the source glob never
compiles them. A rebase against a new oksh tag is therefore the
same `git mv` in reverse plus the ledger in `docs/port.md`.

## Vendored benchmark references (2026-11-07, later cleaned up)

The vendor trees existed to answer one question: how fast is fsh
against the shells it could have been built on? The 2026-11-07
benchmark answered it. FreeBSD sh was fastest on the CPU-bound
workloads (`arith`, `case`, `func`, `str`) and competitive on the
process-heavy ones. oksh, dash and ksh93 had no further information
worth carrying as checkouts, so their submodules were removed.

Only `vendor/freebsd-sh` remains. It is the submodule
`skurtz97/freebsd-userland-zos-port-src`, the FreeBSD userland port for
z/OS starting with `bin/sh`; its FreeBSD source pin is
`release/15.1.0`, commit
`96841ea08dcfa84b954a32dc5ae1a26c28966cf4`. The oksh source pin above
is still the lineage of `src/`; it is not a vendored build.

## Disasters this file remembers

The first project tree (an earlier FreeBSD ash port, then at
`~/src/freebsd-sh-port-zos`) was deleted on 2026-11-05 with its
entire git history. It had no remote. Every tree in this merge now
has one.
