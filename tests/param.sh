# shellcheck shell=sh disable=SC3041,SC3060,SC2154
# ${v/pat/rep} and its three siblings -- the ksh-glob replacement
# operators documented in docs/language.md (D2 decision, 2026-11-06).
#
# Before this, every line here was "bad substitution".
v=/usr/local/bin/x
print -- "${v/local/LOCAL}"   # first match
print -- "${v//l/L}"          # every match
print -- "${v/#\//ROOT}"      # anchored at the beginning: the leading /
print -- "${v/%x/EXE}"        # anchored at the end
print -- "${v/#bin/BIN}"      # anchored: no match, unchanged
print -- "${v/%bin/BIN}"      # anchored: no match, unchanged

# The pattern is a ksh glob, the same one `case' uses.
p=a.b.c.d
print -- "${p/./-}"           # first literal dot
print -- "${p//./-}"          # all dots
print -- "${p/[.]/X}"         # bracket expression
print -- "${p//[!.]/.}"       # negated class: keep dots
print -- "${p/*b/B}"          # '*' is a glob: shortest match from 0
print -- "${p//?[.]/-}"       # '?' is a glob

# A quoted metacharacter is literal.
print -- "${p//'*'/star}"     # no literal '*' present: unchanged

# An empty replacement deletes.
print -- "${p/.d/}"

# A replacement is literal: its metacharacters are not re-interpreted.
print -- "${p//./*}"          # '*', not "everything"

# Adjacent matches.  The first version of this code advanced one
# character too many after each replacement, which is invisible when
# matches are separated (as they are in ${v//l/L} above, where the l's
# of /usr/local are not adjacent) and obvious here.  A test that cannot
# catch its own bug is not a test.
h=hello
print -- "${h//l/L}"          # heLLo -- both l's
h=llll
print -- "${h//l/L}"          # LLLL
h=aaa
print -- "${h//a/}"           # empty: every match deleted
print -- "${h/a/X}"           # Xaa -- first only

# Matches must not eat neighbours.
h=abcabc
print -- "${h//abc/-}"        # --
print -- "${h/abc/-}"         # -abc

# Unset and empty behave like the other substitutions.
unset u
print -- "[${u/a/b}]"
u=
print -- "[${u/a/b}]"

# Arrays are refused, like the other non-value operators on them.
# The message names the shell's input line, which differs between a
# script file and -c, so only the status is checked.  A subshell keeps
# the error from ending the script.
set -A arr one two three
( print -- "${arr[*]/o/0}" ) 2>/dev/null
echo "array rc=$?"
