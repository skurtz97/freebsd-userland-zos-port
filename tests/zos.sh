# The z/OS dialect builtins exist on every host, and off z/OS each one
# answers "only available on z/OS" with status 2 (docs/zos-changes.md).
#
# The names matter as much as the behaviour: a script written on z/OS
# must fail with a clear message on Linux, not with "not found" from a
# path search -- "not found" is indistinguishable from a typo, and it
# sends the reader looking in the wrong place.
for b in tso alloc free zosclass chtag extattr; do
	whence -v "$b"
done
if [ "$(uname)" = OS/390 ]; then
	# On z/OS the builtins are real; -p reads a tag with a stat().
	chtag -p /dev/null >/dev/null && echo chtag-ok
	case $(zosclass) in
	omvs | telnet | rlogin | batch) echo "zosclass-ok" ;;
	*) echo "zosclass-bad: $(zosclass)" ;;
	esac
else
	# Off z/OS: status 2 and a message naming the reason.  The message
	# goes to stderr, so the status is what is checked here.
	for b in tso alloc free zosclass chtag extattr; do
		"$b" x 2>/dev/null
		echo "$b=$?"
	done
fi
