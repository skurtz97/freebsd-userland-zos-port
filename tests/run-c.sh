#!/bin/sh
# Run the shell under test and decode its output for the expectations in
# this directory.
#
# Why: on z/OS the shell writes IBM-1047, as every program on the system
# does -- that is the correct behaviour, measured, and it is not going
# to change to suit a test. The expectations here are ASCII, so the
# output is converted on the way past. ZKSH_DECODE names the source
# encoding; when it is empty the output is already what the test wants
# and this script is a wrapper with nothing to do.
#
#   run-c.sh <path-to-shell> <args...>
#
# Deliberately /bin/sh-compatible: no $( ), no local, no $'...'.

shell=$1
shift

if [ -n "$ZKSH_DECODE" ]; then
	"$shell" "$@" | iconv -f "$ZKSH_DECODE" -t ISO8859-1
else
	"$shell" "$@"
fi
