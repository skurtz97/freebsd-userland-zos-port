#!/bin/sh
# Build the vendored FreeBSD sh reference for Linux benchmarking.
#
#   bench/build-refs.sh                 # build if missing/stale
#   bench/build-refs.sh --force         # rebuild
#   bench/build-refs.sh --clean         # remove build-refs/ first
#   bench/build-refs.sh -j 4
#   FSH_REF_BUILD=/path bench/build-refs.sh
#
# Only FreeBSD sh remains as a benchmark reference. oksh, dash and ksh93
# were removed after the 2026-11-07 comparison: FreeBSD sh was fastest
# on the CPU-bound workloads, which was the question the vendor trees
# existed to answer. The oksh source pin remains in docs/merge.md; it is
# the lineage of src/, not a vendored build.
#
# The source is a git submodule. Initialize it once after cloning:
#
#   git submodule update --init --recursive
#
# The tree is copied to the build directory before its build runs, so
# neither the submodule nor this repository's CMake build is modified.
# The binary is collected in:
#
#   $FSH_REF_BUILD/bin/freebsd-sh
#
# This target is Linux/Unix only. It is not part of the z/OS build.
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
out=${FSH_REF_BUILD:-$root/build-refs}
force=0
if command -v nproc >/dev/null 2>&1; then
	jobs=$(nproc)
else
	jobs=4
fi

usage() {
	cat <<EOF
usage: $0 [-j N] [--force] [--clean] [--out DIR]
EOF
}

while [ $# -gt 0 ]; do
	case $1 in
	-j) [ $# -ge 2 ] || { usage >&2; exit 2; }; jobs=$2; shift 2 ;;
	-j*) jobs=${1#-j}; shift ;;
	--force|-f) force=1; shift ;;
	--clean) rm -rf "$out"; shift ;;
	--out) [ $# -ge 2 ] || { usage >&2; exit 2; }; out=$2; shift 2 ;;
	--out=*) out=${1#--out=}; shift ;;
	--help|-h) usage; exit 0 ;;
	*) echo "$0: unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

case $jobs in
''|*[!0-9]*) echo "$0: -j needs a positive integer" >&2; exit 2 ;;
esac
[ "$jobs" -gt 0 ] || { echo "$0: -j needs a positive integer" >&2; exit 2; }

mkdir -p "$out/bin" "$out/log" "$out/src"

require_submodule() {
	if [ ! -e "$root/vendor/$1/.git" ]; then
		echo "build-refs: vendor/$1 is not initialized" >&2
		echo "  git submodule update --init --recursive" >&2
		exit 1
	fi
}

need_build() {
	# $1 = binary name, $2 = vendor source directory
	[ "$force" -eq 1 ] && return 0
	[ -x "$out/bin/$1" ] || return 0
	if find "$2" -type f -newer "$out/bin/$1" -print -quit |
		grep -q .; then
		return 0
	fi
	return 1
}

copy_tree() {
	# Copy without .git or prior build products from the source tree.
	rm -rf "$2"
	mkdir -p "$2"
	(cd "$1" && tar --exclude=.git -cf - .) | (cd "$2" && tar xf -)
}

run_logged() {
	# $1 = log file, rest = command. Appends; the caller truncates.
	log=$1
	shift
	if ! "$@" >>"$log" 2>&1; then
		echo "build-refs: command failed: $*" >&2
		echo "build-refs: last 60 lines of $log" >&2
		tail -60 "$log" >&2 || true
		exit 1
	fi
}

build_freebsd_sh() {
	src=$out/src/freebsd-sh
	log=$out/log/freebsd-sh.log
	echo "build-refs: freebsd-sh (vendor/freebsd-sh, freebsd-userland-zos-port)"
	copy_tree "$root/vendor/freebsd-sh" "$src"
	: >"$log"
	(
		cd "$src"
		# The Linux adapter is a patch plus three small compat files.
		# The patch touches only the generated-file tools and one
		# dirent field, never the parser or evaluator.
		run_logged "$log" patch -p1 -i "$src/patches/0001-linux-build.patch"
		cd "$src/bin/sh"
		cc=${CC:-cc}
		cflags=${CFLAGS:--O2 -g}
		defs="-D_GNU_SOURCE -DNO_HISTORY -DSHELL -I. -Ibltin -I../../compat -include ../../compat/bsd.h"
		# shellcheck disable=SC2086
		run_logged "$log" "$cc" $cflags $defs -o mknodes mknodes.c
		# shellcheck disable=SC2086
		run_logged "$log" "$cc" $cflags $defs -o mksyntax mksyntax.c
		run_logged "$log" ./mknodes nodetypes nodes.c.pat
		run_logged "$log" ./mksyntax
		run_logged "$log" sh mktokens
		run_logged "$log" sh mkbuiltins .
		for f in alias.c arith_yacc.c arith_yylex.c cd.c bltin/echo.c \
		    error.c eval.c exec.c expand.c histedit.c input.c jobs.c \
		    ../../bin/kill/kill.c mail.c main.c memalloc.c miscbltin.c \
		    mystring.c options.c output.c parser.c \
		    ../../usr.bin/printf/printf.c redir.c show.c \
		    ../../bin/test/test.c trap.c var.c builtins.c nodes.c \
		    syntax.c ../../compat/strlcpy.c ../../compat/btemp.c \
		    ../../compat/setmode.c; do
			# shellcheck disable=SC2086
			run_logged "$log" "$cc" $cflags $defs -c "$f"
		done
		# shellcheck disable=SC2086
		run_logged "$log" "$cc" -o sh ./*.o
	)
	cp "$src/bin/sh/sh" "$out/bin/freebsd-sh"
	chmod 755 "$out/bin/freebsd-sh"
}

require_submodule freebsd-sh
if need_build freebsd-sh "$root/vendor/freebsd-sh"; then
	build_freebsd_sh
fi

echo
echo "Reference shell in $out/bin:"
if [ -x "$out/bin/freebsd-sh" ]; then
	printf '  %-28s ' "$out/bin/freebsd-sh"
	printf 'FreeBSD bin/sh (no version builtin)\n'
fi
