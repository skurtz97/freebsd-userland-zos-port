# Vendored dependencies

The vendor trees are **git submodules**, not sets of files in this
repository, so the superproject records only a gitlink and the pin in
`.gitmodules`. They are part of the build, not only references.

```sh
git submodule update --init --recursive
```

Run that once after cloning. If the submodule is missing,
`bench/build-refs.sh` stops with that command in its error message.

## Why only FreeBSD sh remains

The vendor trees existed to answer one question: how fast is zksh
compared with the shells it could have been built on? On 2026-11-07
that question was answered. FreeBSD sh was the fastest on the
CPU-bound workloads (`arith`, `case`, `func`, `str`) and competitive
on process-heavy ones; oksh, dash and ksh93 no longer had anything to
teach us that was worth carrying as a checkout.

The oksh, dash and ksh93 submodules were therefore removed. The oksh
source pin is still recorded in `docs/merge.md` because oksh is the
lineage of `src/`; it is not a vendored build and is not needed on
disk to rebuild zksh. Keeping the reference trees would only make the
main repository heavier and its status noisier.

## Pin

| Directory | Repository | Pin | Licence |
| --------- | ---------- | --- | ------- |
| `freebsd-sh/` | <https://github.com/skurtz97/freebsd-userland-zos-port-src> | commit `2bc9d53`, tag `freebsd-15.1.0` | BSD-3-Clause / BSD-2-Clause, per file |

`freebsd-sh/` is the dedicated **FreeBSD userland port source for
z/OS** repository, starting with `bin/sh`. It is not the whole FreeBSD source
tree. It contains only the parts needed to build `bin/sh`: `bin/sh`,
`bin/kill`, `bin/test`, and `usr.bin/printf`, plus the Linux benchmark
adapter. Its upstream pin is FreeBSD `release/15.1.0`, commit
`96841ea08dcfa84b954a32dc5ae1a26c28966cf4`.

The compat files under `freebsd-sh/compat/` are not from FreeBSD
upstream:

| File | Origin |
| ---- | ------ |
| `compat/bsd.h` | zksh-written shim for FreeBSD/BSD typedefs and libc extensions Linux lacks |
| `compat/btemp.c` | zksh-written signal-name table, `sig2str`/`str2sig`, and `fwopen` via `fopencookie` |
| `compat/setmode.c` | OpenBSD `setmode.c` (same UCB BSD licence as FreeBSD's copy), needed for `umask -S` |
| `compat/strlcpy.c` | OpenBSD strlcpy/strlcat implementation (ISC-style UCB licence) |

`freebsd-sh/patches/0001-linux-build.patch` changes two things for
Linux:

1. `mktokens` and `mkbuiltins` use a GNU-compatible `mktemp` template.
2. `expand.c` computes `d_namlen` with `strlen(d_name)`; Linux
   `struct dirent` has no FreeBSD `d_namlen` field.

Nothing in the parser, evaluator or builtin implementations is
patched. FreeBSD's `filecomplete.h` is a libedit extension Linux's
libedit does not ship, so this build uses `-DNO_HISTORY`; line editing
and `fc`/`bind` are absent from this benchmark shell. That does not
affect the non-interactive workloads.

## Build

From the repository root:

```sh
git submodule update --init --recursive

./bench/build-refs.sh              # build if missing/stale
./bench/build-refs.sh --force      # rebuild
```

Or through CMake:

```sh
./configure --release && cmake --build build -j8
cmake --build build --target refshells
```

The FreeBSD sh build uses the C compiler directly and needs no
autotools. The result is:

```text
build-refs/bin/freebsd-sh
```

## Benchmark

```sh
cmake --build build --target bench
```

or directly:

```sh
bench/run.sh build/zksh build-refs/bin/freebsd-sh
```

Use `-n N` for more runs and `-v` to see every run. The benchmark
reports best-of-N wall time, so it measures the shell and not a single
scheduler hiccup.

## Updating the pin

The submodule checkout is the pin. Make the change in
`skurtz97/freebsd-userland-zos-port-src` first, push it, then update the
submodule checkout and record the new gitlink:

```sh
git -C vendor/freebsd-sh fetch
git -C vendor/freebsd-sh checkout <commit>
git add vendor/freebsd-sh .gitmodules
```

Do not edit files inside the submodule to make a zksh build pass; the
change belongs in the port repository. Update this table and
`docs/merge.md` in the same commit.
