# The language: what fsh accepts

fsh's language is a closed set. It is **pdksh/oksh's ksh88 surface**,
audited, with a named list of what we add and a named list of what we
remove or refuse. A construct that is not on a list is rejected with a
message naming this document, never guessed at.

This file was rewritten on 2026-11-05 after the base changed from
FreeBSD ash to oksh. The previous version described an ash base and
was wrong about several things oksh already does (and one it does
not: `${v/p/r}`). It is the authority; `direction.md` is the reason.

Verified against the built shell on Linux, 2026-11-05
(`./fsh -c ...`); each row below marked *verified* was exercised.

## Level 0 — POSIX sh (always on, verified present)

- Quoting: `\`, `'`, `"`, here-documents (`<<`, `<<-`).
- Expansion: `${name}`, `${name:-w}`, `:=`, `:?`, `:+`, `#`, `##`,
  `%`, `%%`, `$(...)`, `` `...` ``, `$((...))`.
- Special parameters: `$?`, `$$`, `$!`, `$-`, `$#`, `$*`, `$@`,
  `$0`..`$9`, `${10}`.
- Control flow: `if`, `case`, `for`, `while`, `until`, `{ }`,
  `( )`, `!`, `&&`, `||`, pipes, `&`.
- Redirection: all POSIX forms, `<>`, `>&-`, `n>&m`.
- Functions: `name() { ... }`, `function name { ... }` (ksh form).
- Builtins: `:`, `.`, `alias`, `bg`, `break`, `cd`, `chdir`,
  `command`, `continue`, `echo`, `eval`, `exec`, `exit`, `export`,
  `false`, `fc`, `fg`, `getopts`, `hash`, `jobs`, `kill`, `pwd`,
  `read`, `readonly`, `return`, `set`, `shift`, `test`, `[`,
  `times`, `trap`, `true`, `type`, `ulimit`, `umask`, `unalias`,
  `unset`, `wait`.

## Level 1 — ksh88 surface (already in oksh; keep, verified)

| Feature | Form | Verified |
| ------- | ---- | -------- |
| Arithmetic command | `((expr))`; status 0 if non-zero | yes |
| Arithmetic `for` | `for ((i=0;i<n;i++)); do ...; done` | yes |
| Indexed arrays | `set -A a one two three`, `${a[2]}`, `${#a[*]}`, `a[3]=x` | yes |
| `typeset` | `typeset [-iuxr] [-l] [-R n] [-L n] [-Z n] [name[=val]]` | yes |
| `local` | alias for `typeset` inside a function | yes |
| `print` | `print [-Rnprsu[n]] [-f fmt]` | yes |
| `let` | `let x=x+1` | yes |
| `whence` | `whence [-pv] name` | yes |
| `[[ ]]` | ksh88 pattern tests (`==`, `!=`, `-eq`, `-f`, `&&`, `\|\|`) | yes |
| `select` | `select v in list; do ...; done` | yes (present) |
| `set -o` | ksh names: `allexport errexit monitor noclobber noexec noglob nounset verbose vi emacs xtrace` | yes |
| `trap` | POSIX semantics, ksh function-scope behaviour | yes |
| Job control | `set -m`, `bg`, `fg`, `jobs`, process groups | yes |
| `cd old new`, `cd -`, `CDPATH` | z/OS `sh` has `cd old new`; keep it | yes |
| Co-process (present) | `cmd |&`, `read -p`, `print -p` | present, untested |

## Level 2 — added for z/OS (not in ksh88)

| Feature | Form | Status |
| ------- | ---- | ------ |
| `ULTRIX`-free parameter substitution | `${v/pat/rep}`, `${v//pat/rep}`, `${v/#pat/rep}`, `${v/%pat/rep}` | added 2026-11-06, below |
| Case modification | `${v^^}`, `${v,,}` | refused for now; see below |
| `read -t sec`, `read -u fd` | timeout and fd | present in ksh88? verify on z/OS |
| z/OS builtins | `tso`, `alloc`, `free`, `zosclass`, `chtag`, `extattr` | `tso`/`chtag`/`extattr` in zash, to port |

The `${v/pat/rep}` gap is the single most likely "why doesn't my
script work" complaint, because bash, mksh and ksh93 all have it and
pdksh never did. It was added on 2026-11-06; the rules below are the
decision (D2 in `direction.md`), and `tests/param.sh` is the proof.

### `${v/pat/rep}`: the four forms and the pattern syntax

| Form | Replaces |
| ---- | -------- |
| `${v/pat/rep}` | the **first** match of `pat` anywhere in `$v` |
| `${v//pat/rep}` | **every** match |
| `${v/#pat/rep}` | `pat` only when it matches at the **beginning** |
| `${v/%pat/rep}` | `pat` only when it matches at the **end** |

`pat` follows the **same** rules as every other pattern in the
language: ksh glob, matched unanchored as a substring for the plain
and `//` forms. `.` and `*` mean what they mean in `case` and in
`${v#pat}` -- `*` matches any run of characters, `?` any one,
`[...]` / `[!...]` a set, and quoting a metacharacter makes it literal.
That is the decision (D2): **ksh glob, not POSIX bracket-expression
regex**. A second pattern dialect inside one shell is exactly what
Rule 1 forbids, and the `#`/`%`/`##`/`%%` operators already users of
this syntax would otherwise disagree with it.

Consequences worth knowing, because they differ from bash:

- The replacement is **literal text**, not a back-reference: `${v/a/&}`
  inserts `&`, it does not re-insert the match. `&` is not special.
- An empty `pat` is an error (`bad substitution`), not "match anywhere":
  bash inserts the replacement between every character, which no
  script has ever wanted and which would make a typo catastrophic.
- An empty `rep` deletes the match: `${v/pat/}` has an empty
  replacement part, which is different from the `${v/pat}` form bash
  also accepts. fsh requires the second `/` and rejects `${v/pat}`
  as a bad substitution, so a deletion is always written explicitly.
- `${v/pat/rep}` on an unset variable is empty unless `set -u`, which
  is the same rule as `${v:-}` and the other substitutions.
- **Not on `$*`, `$@`, `${a[*]}` or `${a[@]}`.** `${a[*]/x/y}` is a bad
  substitution, like `${a[*]#x}` already is. The element-by-element
  form is a separate expansion path; adding it means threading the
  replacement through it, and no script in the wild needs it more than
  a loop: `for e in "${a[@]}"; do ...; done`. Refusing loudly beats
  half-working.

### Case modification: refused

`${v^^}`, `${v,}`, `${v,,}`, `${v~}` are **not** accepted. They are a
bash 4 / ksh93 feature, they interact badly with a locale-dependent
case mapping (and z/OS has several code pages), and `${v:u}`-style
functions are a two-line script: `v=$(print -n "$v" | tr a-z A-Z)`.
If they are ever added, they are added here first.

## Level 3 — refused, with reason

| Construct | Why refused |
| --------- | ----------- |
| Associative arrays (`typeset -A`) | ksh93/bash only; large cost, rare in scripts |
| `nameref` (`typeset -n`) | scoping hazards |
| Discipline functions, `typeset -C` | ksh93 finance features |
| `${!var}` indirect expansion | bash only |
| `globstar`, `extglob`, `xpg_echo` | bash features; outside the charter |
| `$[...]` | z/OS `sh` extension; accepted only under `set -o zos` |

## Errors, not surprises

A rejected construct produces a message with the document and an
alternative:

```
fsh: [[ ]] is not supported
```

The important property is the same as before: a user can trust that a
script which parses is a script that means what it says. Where oksh
*already* provides a construct, refusing it now would be a
regression against every pdksh script in existence, so Level 1 is
kept in full even where it exceeds the ash-sized budget. That is the
price of the ksh base, and it is recorded in `budget.md`.
