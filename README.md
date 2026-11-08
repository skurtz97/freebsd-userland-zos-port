# freebsd-userland-zos-port

**A true z/OS Korn shell.** oksh (pdksh / ksh88 lineage) brought to
z/OS UNIX System Services, with a z/OS layer aggressive enough to be a
dialect: `tso`, `alloc`, `free`, `chtag`-aware redirection,
`spawnp()`-first process creation, and profiles that look like z/OS
profiles rather than Unix ones.

The name says what it is. It is not AT&T's `ksh88` (the UCS/DFKSH
shell behind `/bin/sh` on z/OS), it is not bash, and it is not a
POSIX-only shell. See [docs/direction.md](docs/direction.md).

> **Status:** builds and runs on both Linux and z/OS, ksh88 surface
> verified, `ctest` green on both (2026-11-06). The z/OS dialect layer
> (`tso`/`alloc`/`free`, `_TAG_REDIR_*`, MVS data sets) is still to
> come. See [docs/status.md](docs/status.md).

## Why

z/OS ships one POSIX shell (`sh`, System V with some Korn features)
and tcsh. Neither is a Korn shell. Scripts written for ksh on other
platforms — `typeset`, `set -A`, `[[ ]]`, `(( ))`, `print`,
`select` — either fail or need rewriting. fsh is those scripts'
home on z/OS, plus the line editing and history that the z/OS `sh`
does not have.

## What it is built from

| Source | Role |
| ------ | ---- |
| [oksh 7.9](https://github.com/ibara/oksh) | The shell. pdksh lineage: ksh88 language, job control, traps, coprocs, emacs/vi editing. 28,036 lines. |
| `zos_spawn.c` (prior work, in this tree) | `spawnp()` process creation on z/OS; fork only for shell code. |
| `~/src/zash` (prior work, separate repo) | Reference implementation for the z/OS layer: charset-neutral words, `tso`/`chtag`/`extattr`, `_TAG_REDIR_*`, MVS data set redirection. Its ideas move here; it is not vendored. |

## Build

### Linux

```sh
./configure --prefix=/usr/local
make -j8
./fsh -c 'print hello'
```

oksh uses a `configure` script that writes a Makefile; there are no
generated sources and no C tools to build first.

### z/OS

```sh
./configure --prefix=/usr/local --cc=ibm-clang64
make
```

Requires IBM Open XL C/C++ 2.1 (`ibm-clang64`), or legacy XL C/C++
(`xlc`) with `./configure --zos --xlc`. **This has not been attempted
yet.** `configure` currently has no z/OS detection: it
compiles `zos_spawn.o` unconditionally (which is harmless on Linux,
being empty, but is not the same as *configuring* for z/OS), and it
does not add `-D_ALL_SOURCE`. Whether that flag is needed at all is
for the first build to decide, not for this README to assert. See
[docs/port.md](docs/port.md), items B1–B4.

## Using it

The shell reads the z/OS profile files in the z/OS order:
`/etc/profile`, `$HOME/.profile` on login, `$ENV` for interactive
shells. It accepts `-L` for a login shell as well as ksh's `-l`.

z/OS builtins (planned, see [docs/zos-changes.md](docs/zos-changes.md)):

```sh
tso "oput source.c(hello) '/u/me/source/hello.c'"
alloc "dsn('HLQ.TEMP.DATA') new catalog"
free 'HLQ.TEMP.DATA'
```

## Language

The language is a **closed set**, documented in
[docs/language.md](docs/language.md): everything ksh88/oksh already
accepts, plus a named list of additions (starting with
`${v/pat/rep}`, which pdksh never had), minus a named list of bash
features we refuse. A construct outside the set is an error naming
the document, never a silent misparse.

## Documentation

| Document | Covers |
| -------- | ------ |
| [docs/direction.md](docs/direction.md) | the constitution: three rules, lineage decisions |
| [docs/status.md](docs/status.md) | what works today, what is next |
| [docs/language.md](docs/language.md) | the accepted language, verified against the built shell |
| [docs/budget.md](docs/budget.md) | the enforced size, build, binary and runtime budgets |
| [docs/zos-changes.md](docs/zos-changes.md) | the z/OS builtins and dialect |
| [docs/compat.md](docs/compat.md) | differences from the z/OS `sh` |
| [docs/port.md](docs/port.md) | every edit to the oksh base, with its reason |

`AGENTS.txt` has the short version for automated contributors.

## Licence

oksh's public-domain terms; the source pin is recorded in
`docs/merge.md`. Our changes are under the same terms. This is not
oksh, not pdksh, and not AT&T ksh.
