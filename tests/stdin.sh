# Script on stdin: a command that reads stdin gets the text after it.
cat >"$T/s1" <<'EOT'
read x
data-line
echo "read [$x]"
EOT
"$SH" < "$T/s1"
cat <<'EOT' | "$SH"
read x
data-line
echo "read [$x]"
EOT
# a child reading a regular file gets exactly the next line (a shell's
# read must not consume past it; head is not required to seek back)
cat >"$T/child.sh" <<'EOT'
read l; echo "child [$l]"
EOT
cat >"$T/s2" <<'EOT'
"$SH" "$T/child.sh"
skipped line
echo after-child
EOT
"$SH" < "$T/s2"
# multi-line compound command, then read
cat <<'EOT' | "$SH"
if true; then
  echo in-if
fi
read y
line-for-y
echo "y=[$y]"
EOT
cat >"$T/s3" <<'EOT'
if true; then
  echo in-if
fi
read y
line-for-y
echo "y=[$y]"
EOT
"$SH" < "$T/s3"
# two commands on one line: offset lands after the line, not mid-line
cat <<'EOT' | "$SH"
echo a; read z
zline
echo "z=[$z]"
EOT
cat >"$T/s4" <<'EOT'
echo a; read z
zline
echo "z=[$z]"
EOT
"$SH" < "$T/s4"
# in-process redirect of fd 0 must not seek the redirected file
# (long first line so a wrong lseek on it would succeed and land mid-line)
awk 'BEGIN { for (i = 0; i < 120; i++) printf "r"; print ""; print "r2" }' > "$T/other"
cat >"$T/s5" <<'EOT'
{ read a; read b; } < "$T/other"; echo "${#a} $b"; read c
cline
echo "c=[$c]"
EOT
T=$T "$SH" < "$T/s5"
