# Direction

Decided 2026-11-05. This document records the shape of fsh and the
reason for each choice, so that a later feature request can be tested
against a rule instead of relitigated. It is the constitution; the
other documents are statutes.

**Revision note (2026-11-05, same day):** the base changed from
FreeBSD ash to **oksh**. The ash-first recommendation could not
survive contact with the two existing trees: oksh already had the ksh
surface (28k lines nobody has to write) and the z/OS spawn layer
proven and documented, and zash — not FreeBSD ash — was the working
z/OS implementation. See "Lineage" below.

## What fsh is

**fsh is oksh (pdksh / ksh88 lineage), ported to z/OS UNIX, with a
z/OS layer aggressive enough to be a dialect.**

It is a real Korn shell. It is not bash, and it does not try to be:
where bash adds features, fsh refuses them (see `language.md`,
Level 3). It is *more POSIX than bash* because ksh88's POSIX core is
precise, and *loudly non-POSIX* where z/OS demands it.

The z/OS work it inherits from the two prior trees:

| Idea | Came from | What it gives us |
| ---- | --------- | ---------------- |
| `spawnp()` for external commands, fork only for shell code | oksh `zos_spawn.c` + `doc/ZOS-NOTES.md` | no address-space copy per command; the main z/OS performance win |
| `_BPX_SHAREAS=YES` for the fork path | oksh `zos_spawn.c` | cheap shared daughters for pipelines and subshells |
| `SPAWN_SETGROUP\|SPAWN_NEWPGROUP` | oksh `zos_spawn.c` | job control without the `setpgid`/`tcsetpgrp` race |
| Charset-neutral word representation (no in-band control bytes) | zash `DESIGN.md` | EBCDIC correctness by construction rather than patched |
| `tso`, `chtag -p`, `extattr` builtins | zash `zos_builtins.c` | z/OS convenience in-process |
| `_TAG_REDIR_OUT/ERR/IN`, MVS data set redirection | zash `sys_zos.c` | the documented z/OS `sh` semantics |
| ASCII/EBCDIC pipe and file tagging, `cvtprobe` | zash `sys_zos.c`, `tools/` | converts the "which code page is this stream" problem into a measured one |

## The three rules (unchanged)

**Rule 1 — a closed language.** Everything on the lists in
`language.md`; nothing else. Refusal is a message, not a guess.
Where oksh already parses a construct, it stays: refusing it would
break every existing pdksh script.

**Rule 2 — z/OS is a layer, not a fork of the parser.**
Builtins (`tso`, `alloc`, `free`, `zosclass`), profile files, and
`set -o zos`. No z/OS-specific changes to parsing or expansion.

**Rule 3 — a feature pays for itself.** `budget.md` is enforced. The
editor files get zero headroom; the z/OS layer is capped at 1,500
lines total.

## Lineage decision, and what we rejected

| Candidate | Verdict | Why |
| --------- | ------- | --- |
| **oksh (chosen)** | Base | Real ksh88 surface, job control, traps, coprocs, emacs/vi, 28k lines already written and maintained. `zos_spawn.c` already hooks it correctly. |
| zash | **Reference implementation** | Fresh 7.2k-line ash: charset-neutral words, fd plans, z/OS tagging. Its best ideas move here as a layer. **Not archived or moved**: `~/src/zash` stays in place, untouched, because it has its own remote and its own libedit work. |
| FreeBSD ash (imported, then lost) | Gone; pin recorded | Smallest engine, but ash-first means writing the ksh surface ourselves. The tree was deleted 2026-11-05 before any port work. `lib/README.upstream` in this tree records only the pin; no file from it is reused. |
| mksh / ksh93u+m | Rejected | mksh is another ksh (no gain); ksh93 is 4.1 MB plus libast and EPL-2.0. |

## What "more POSIX than bash" means concretely

| Area | bash | fsh |
| ---- | ---- | ---- |
| `set -o` names | many synonyms, unknown names sometimes ignored | only documented ksh names; unknown is an error |
| `local` vs `typeset` | two implementations | `typeset`; `local` is the same code |
| `$(( ))` | arbitrary precision runtime | 64-bit `intmax_t`, wrapping, documented |
| `echo` | option parsing varies by build | ksh88 `print`; `echo -e` only under `set -o zos` |
| `[` | bash builtin with extensions | POSIX `test` plus `[[ ]]` as a *separate* construct |
| arithmetic subscripts | side effects vary | documented, no surprises |

## What "aggressively non-POSIX on z/OS" means

- **`tso` is a builtin.** Not a script, not a deferred spawn: it can
  grow an in-process TSO/E interface (`IKJTSOEV`) instead of
  `tsocmd`, which is impossible for an external script.
- **`alloc` / `free` are builtins.** MVS allocations are not
  inherited across `fork`, and a child cannot see its parent's
  allocations, so only the shell itself can manage them usefully.
- **`zosclass`** reports the session kind (`omvs`, `telnet`,
  `rlogin`, `batch`) so profiles can branch.
- **Line mode is first-class.** Under OMVS there is no raw mode; we
  provide numbered history and `!!`/`!n` rather than a degraded
  full-screen editor.
- **Profiles are z/OS profiles:** `/etc/profile`, `$HOME/.profile`,
  `$ENV`, and `sh -L` as the login flag.

There is no POSIX-only build with these removed. A site that wants
pure POSIX runs the system `sh`; `compat.md` says so.

## Consequences already accepted

- **The name `fsh` is new** and deliberately does not reuse the name
  of the AT&T ksh88-based z/OS `sh` (UCS/DFKSH). No man page is
  installed yet: the copied oksh page was removed because it described
  the old base, not fsh or the FreeBSD userland direction. Default
  install is `/usr/local/bin/fsh`.
- **28,036 lines at import.** The binary is 269 KB stripped and
  starts in 0.4 ms, so the size is review cost, not runtime cost.
- **`${v/pat/rep}` is missing** from pdksh and must be added; it is
  the first language task in `status.md`.
- **FreeBSD ash is gone from disk** (deleted 2026-11-05 with its git
  history). The pin is recorded in `docs/port.md`; a file can be
  re-fetched from it if ever needed as a reference.
- **`~/src/zash` is left in place** as the reference implementation,
  with its remote intact. It is not vendored here and is not built
  by this project.

## Open decisions

| # | Question | State |
| - | -------- | ----- |
| D1 | Install as `fsh` only, or also as `sh`? | open — default: `fsh` only |
| D2 | `${v/pat/rep}` pattern syntax: ksh glob or POSIX bracket expressions? | **decided 2026-11-06: ksh glob** — see `language.md` Level 2 |
| D3 | `alloc`/`free`: DSN, DD, TSO ALLOC, or all three? | open |
| D4 | Line-mode editor: numbered history + `!!` (ksh `fc` exists), or libedit dumb-terminal profile? | open |
| D5 | Keep `oksh` as the upstream to rebase on, or fork permanently at 7.9? | open — default: rebase |
