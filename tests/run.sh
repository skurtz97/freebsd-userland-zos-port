#!/bin/sh
# shellcheck shell=sh
# Usage: tests/run.sh SHELL   -- run each tests/*.sh under SHELL and
# compare stdout+stderr with tests/*.out.  -v prints diffs.
verbose=0
if [ "$1" = -v ]; then verbose=1; shift; fi
sh_under_test=${1:?usage: run.sh [-v] shell}
case $sh_under_test in
*/*) sh_under_test=$(cd "$(dirname "$sh_under_test")" && pwd)/$(basename "$sh_under_test") ;;
esac
dir=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d 2>/dev/null) || { T=${TMPDIR:-/tmp}/zash-test.$$; mkdir "$T"; } || exit 1
trap 'rm -rf "$T"' EXIT
SH=$sh_under_test
export T SH
zos=0
[ "$(uname)" = OS/390 ] && zos=1
# FSH_ENCODE names the charset the shell under test reads (IBM-1047 on
# z/OS).  The test scripts are ASCII and correctly tagged UTF-8, but an
# EBCDIC shell cannot parse ASCII bytes as shell syntax, so each test is
# converted before the shell sees it.  Written for /bin/sh: no $( )
# beyond the one above (matched by CMake's own usage), no local.
: ${FSH_ENCODE=}
fail=0
for t in "$dir"/*.sh; do
	# run.sh is this runner and run-c.sh is its per-test wrapper (the one
	# that decodes IBM-1047 on z/OS); neither is a test, and both would
	# be picked up by the glob without this guard.
	case $t in */run.sh|*/run-c.sh) continue ;; esac
	exp=${t%.sh}.out
	out=$T/$(basename "$t").got
	sed "s#\$T#$T#g" "$exp" > "$T/expected"
	# On z/OS an ASCII-mode zash writes ASCII and autoconversion
	# tags a new file ISO8859-1, so its bytes never match the
	# IBM-1047 expected output.  Pre-tagging the file IBM-1047 makes
	# autoconversion translate on write; truncation keeps the tag.
	: > "$out"
	[ "$zos" -eq 1 ] && chtag -tc IBM-1047 "$out"
	# The script the shell reads, in the shell's charset.  A copy is
	# used so the tree keeps its ASCII originals (AGENTS.txt 3: a
	# test file of ASCII text is properly tagged UTF-8 and must not be
	# converted in place to hide a defect).
	src=$t
	if [ -n "$FSH_ENCODE" ]; then
		src=$T/$(basename "$t")
		iconv -f ISO8859-1 -t "$FSH_ENCODE" < "$t" > "$src" || src=$t
	fi
	(cd "$T" && "$sh_under_test" "$src") > "$out" 2>&1
	if cmp -s "$out" "$T/expected"; then
		[ "$verbose" -eq 1 ] && echo "ok   $t"
	else
		echo "FAIL $t" >&2
		[ "$verbose" -eq 1 ] && diff "$T/expected" "$out" >&2
		fail=1
	fi
done
exit "$fail"
