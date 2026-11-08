# The build

CMake and Ninja are the build on both hosts. They run on this z/OS now
(the zrx project dropped them in 2026-11-01 because zopen's CMake and
Ninja did not run with Open XL 2.1's C++ runtime; that no longer
holds).

**Status:** Phase 0. Built and passing `ctest` on both Linux and z/OS
(2026-11-06).

## Quick start

```sh
./configure                 # shim over cmake -B build
cmake --build build -j8
./build/zksh -c 'print hello'
ctest --test-dir build
```

## Presets

| Command | Result |
| ------- | ------ |
| `./configure` | Debug, warnings on, build/ |
| `./configure --release` | Release, build/ |
| `./configure --enable-small` | `-DSMALL` |
| `./configure --disable-curses` | no line editing |
| `./configure --cc=clang` | explicit compiler |
| `./configure --build-dir=build-x` | out of tree, as many as you like |
| `./configure --zos` | z/OS toolchain file, `-DFSH_ZOS=ON` |
| `./configure --ninja` | Ninja generator |

By hand:

```sh
cmake -S . -B build-san -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"
cmake --build build-san -j8
```

## What was replaced

oksh's `configure` was a 1,445-line `sh` script that probed the
compiler and then wrote a `Makefile` and `pconfig.h`, both into the
source directory, with `-w` (all warnings off) in the default flags.
The oksh vendor checkout was removed after the benchmark; its source
pin is in [merge.md](merge.md). The probe behaviour that matters is
now only in `cmake/checks.cmake` and `cmake/pconfig.h.in`.

| oksh configure | now |
| -------------- | --- |
| writes `pconfig.h` | `cmake/checks.cmake` + `cmake/pconfig.h.in` |
| writes `Makefile` | `CMakeLists.txt` |
| `-w` | `-Wall -Wextra`; `FSH_STRICT=ON` adds `-Werror` |
| `-fuse-ld=lld` | not set; the toolchain default is used |
| `-lcurses` probe | `find_package(Curses)`, wide ncurses on z/OS |
| `-D_GNU_SOURCE` | set for Linux targets |
| no z/OS branch | `cmake/toolchain-zos.cmake`, `FSH_ZOS` |

## Two rules the checks follow

1. **`__dead` is never defined unconditionally.** z/OS `<sys/cdefs.h>`
   may provide it, and a redefinition is fatal. `cmake/pconfig.h.in`
   guards it with `#ifndef __dead`.
2. **Checks use the same feature-test macros as the build.** The first
   CMake build failed on `setresuid`/`setresgid` because the checks
   ran without `-D_GNU_SOURCE` while the build had it, so
   `HAVE_SETRESUID` was 0 and the prototypes stayed hidden. Both now
   include it.

The `-w` removal immediately found real warnings in the base
(`c_test.c`, `c_ulimit.c`, `emacs.c`, `c_sh.c`, `edit.c`). They are
visible, not yet fixed; `FSH_STRICT` will not pass until they are.

## z/OS

```sh
bash ./configure --zos --release --build-dir=build-zos
cmake --build build-zos -j4
./build-zos/zksh -c 'print hello'
ctest --test-dir build-zos --output-on-failure
```

**Run `configure` with bash, not `/bin/sh`.** The system `sh` rejects
the script (`FSUM7332 syntax error: got (`) -- it does not implement
`$( )`. zopen's bash and oksh both run it.

`ctest` also needs bash: `tests/run-c.sh` is a UTF-8-tagged script and
`/bin/sh` refuses those with or without `_BPXK_AUTOCVT` (measured). The
tests decode the shell's IBM-1047 output through `iconv` before
matching their ASCII expectations, so a failing test means a real
failure, not an encoding mismatch.

`cmake/toolchain-zos.cmake` selects `ibm-clang64` (Open XL 2.1,
clang based), names the system `FSH-ZOS` so a local
`cmake/Platform/FSH-ZOS.cmake` answers instead of CMake printing
"System is unknown", and searches the zopen tree for headers and
libraries. It does **not** pass `-m64` (Open XL defaults to 64-bit
XPLINK) and does **not** pass `-march`: a binary built for a higher
level will not run on a lower one, so `-DFSH_ZOS_ARCH=z16` is opt-in.

Curses is the awkward part. zopen installs only static archives, wide
(`--enable-widec`) character, headers in `include/ncursesw`, so
CMake's `FindCurses` -- which looks for `-lncursesw` by name and does
not search `include/ncursesw` -- finds nothing and the build drops
line editing with only a warning. The toolchain therefore locates
`curses.h` and `libncursesw.a` itself and passes them to the
`CMakeLists.txt` check, which skips `find_package` when they are
already set and links the archive by path.

Observed layout (2026-11-05):

```
/usr/local/zopen/usr/local/include/ncursesw/curses.h
/usr/local/zopen/usr/local/lib/libncursesw.a
/usr/local/zopen/usr/local/zopen/ncurses/ncurses-<ver>.zos/{include/ncursesw,lib}
```

Override with `-DFSH_CURSES_PREFIX=<dir>` or the two
`-DCURSES_INCLUDE_PATH=` / `-DCURSES_LIBRARY=` variables. Configure
prints which one won:

```
-- zksh: z/OS ncurses at /usr/local/zopen/usr/local/lib/libncursesw.a
-- zksh: ncurses headers at /usr/local/zopen/usr/local/include/ncursesw
```
