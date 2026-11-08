n=0; while read -r a b c d; do n=$((n+a)); done < data.txt; echo $n >/dev/null
: "$b$c$d"
