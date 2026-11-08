# Budget

Rule 3 in [direction.md](direction.md): a feature must pay for itself.
This file sets the price. Measured on the base commit of the fsh tree
(2026-11-05, Linux x86-64, clang 22); re-measure `make bench` once it
exists.

## What changed from the ash-based budget

The first version of this file set 24,000 lines for an ash-sized
shell. The base is now oksh, which is **28,036 lines before any z/OS
work**, and refusing Level 1 constructs to get under the old number
would break every pdksh script. The budget is therefore rebased on
the real import, and its *purpose* is restated: it now buys
**reviewability and stability**, not minimalism. A ksh is not small;
this one has to stay *knowable*.

## Size

| Measure | Budget | At import | Headroom |
| ------- | ------ | --------- | -------- |
| C and headers, all files | **31,000 lines** | 27,842 (2026-11-06) | 3,158 |
| Files (`.c`/`.h`) | **65** | 57 | 8 |
| Lines in `zos_spawn.c` + `zos_builtins.c` + `sys_zos.c` | **1,500** | 548 (`zos_spawn.c` 236 + `zos_builtins.c` 312; `sys_zos.c` not written) | 952 |
| Builtin names | **70** | 50 (2026-11-06; 44 before the six z/OS builtins) | 20 |
| Lines in a single new function | **150** | — | — |
| Editor code (`emacs.c` + `vi.c` + `edit.c`) | **no growth** | 5,319 | 0 |

The "at import" figures in this table were first written from memory
and two were wrong, which is exactly what rule 3 forbids. Re-measured
2026-11-06 with `wc -l` over `src/*.c src/*.h` and a count of the
`{` entries in `kshbuiltins[]` and `shbuiltins[]`:

- editor code is **5,319** lines (`emacs.c` 1,991, `vi.c` 2,207,
  `edit.c` 1,121), not 5,715. It has not changed: no editing feature
  was added, which is the budget's actual requirement.
- builtins were **44**, not 55; the six z/OS ones make 50.
- the tree is **27,842** lines in 57 files, under the 31,000 ceiling by
  3,158.

The 2,964-line headroom is the whole language and z/OS budget. The
four z/OS builtins (`tso`, `alloc`, `free`, `zosclass`) and the
`${v/pat/rep}` expansion fit; a second expansion engine does not.

Editor code gets **zero** headroom: `emacs.c`, `vi.c` and `edit.c`
are the three largest files after the parser and evaluator, and they
are feature-complete. New editing features belong in libedit's
`.editrc`, not in the shell.

## Build

| Measure | Budget | Notes |
| ------- | ------ | ----- |
| Clean build, Linux, `-j8` | 60 s | oksh's Makefile, no generators |
| Clean build, z/OS, `-j4` | 180 s | `make zos`, separate objects |
| Incremental after `eval.c` | 10 s | 28k-line units are slower to compile |
| `make check` on Linux | 60 s | |

## Binary

| Measure | Budget | At import |
| ------- | ------ | --------- |
| stripped, Linux x86-64 | **600 KB** | 295,232 bytes (288 KB; 2026-11-06, Release) |
| stripped, z/OS XPLINK64 | **1.0 MB** | unmeasured |

The stripped binary is already well under budget because oksh links
`libcurses` dynamically. **Watch this**: if libedit is ever linked
statically (as zash does), the number roughly triples.

## Runtime

| Measure | Budget | At import |
| ------- | ------ | --------- |
| `fsh -c ':'`, best of 30 | 5 ms | 0.54 ms (2026-11-06, Release) |
| Peak RSS, empty profile | 3 MB | 2.33 MB |
| Interactive start to prompt | 10 ms | unmeasured |

## What each number protects

- **Lines and files** — reviewability. 31k is the ceiling for this
  tree to be read by one person and checked against `language.md`.
- **z/OS layer size** — the layer is the part we write and maintain;
  capping it keeps the port from becoming a fork of a fork of a fork.
- **Zero editor growth** — this is where shells historically bloat
  (1,000–2,300 lines per editor in bindings alone). libedit already
  does the work.
- **Build time** — edit–compile–test cycles on two hosts.
- **Binary and startup** — z/OS address-space and script-loop cost.
- **RSS** — a shell that competes with the application is the wrong
  shell for batch.

## Overruns

An overrun is written down, not forbidden. In the commit that breaks a
budget, add a row with the measured number, the cause and the plan. A
row with no plan is removed at the next review.

| Date | Budget | Measured | Cause | Plan |
| ---- | ------ | -------- | ----- | ---- |
| 2026-11-05 | 24,000 lines (ash base) | 28,036 | Base changed from FreeBSD ash to oksh; budget rebased above | Accepted as a new baseline |
