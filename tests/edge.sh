# shellcheck disable=SC2030,SC2031
set -- "a b" "" c
printf '<%s>' "$@"; echo
# Unquoted $@ is the point of this test: it exercises field splitting.
# shellcheck disable=SC2068
printf '<%s>' $@; echo
printf '<%s>' "$*"; echo
set --
printf '<%s>' "$@" x; echo
e=
# Unquoted $e must disappear; that is what is being tested.
# shellcheck disable=SC2086
printf '<%s>' $e "" "$e"; echo
IFS=:
v="a:b::c"
# Unquoted $v must split on IFS; that is what is being tested.
# shellcheck disable=SC2086
printf '<%s>' $v; echo
IFS=' 	
'
# echo's backslash handling is the subject here, not printf's.
# shellcheck disable=SC2028,SC1001
echo 'single "dq" \n' "double 'sq' \$HOME \\ \"" \x
echo "nested $(printf '%s' "in $(printf '%s' deep)")"
{ echo to-stderr >&2; } 2>&1 | cat
( echo err >&2 ) 2>/dev/null; echo swallowed
sh -c 'echo out; echo err >&2' 2>&1 >/dev/null | sed 's/^/got:/'
exec 3>"$T/fd3.txt"; echo via3 >&3; exec 3>&-; cat "$T/fd3.txt"
eval 'q=evald; echo $q'
dotvar=
echo 'dotvar=fromdot' >"$T/dot.sh"
# shellcheck source=/dev/null
. "$T/dot.sh"
echo "$dotvar"
fact() { if [ "$1" -le 1 ]; then echo 1; else echo $(( $1 * $(fact $(($1-1))) )); fi; }; fact 10
# The pipeline's subshell is the subject: x must not survive it.
echo builtin | read -r x; echo "subshell read: x=${x-unset}"
for i in 1 2 3; do for j in a b; do [ "$j" = b ] && continue 2; echo "$i$j"; done; done
# x=1 is an environment assignment for the child; the parent stays unset.
x=1 sh -c 'echo child x=$x'; echo "parent x=${x-unset}"
: "${def:=assigned}"; echo "$def"
echo "${novar:+alt}[]" "${def:+alt}"
cat <<-EOT
	tabs stripped $def
	EOT
echo "$(printf 'trail\n\n\n')|"
printf '%s\n' / /tmp | while read -r d; do echo "dir:$d"; done
! false && echo negated
echo "exit test"; (exit 7); echo "rc=$?"
set -e; false || true; echo still-here
sh -c 'set -e; false; echo NOT'; echo "set-e rc=$?"
