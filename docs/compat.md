# Differences from the z/OS `sh`

zksh is a Korn shell, so it is *by design* not a drop-in for the
z/OS `sh`. This file separates the differences that are the point from
the ones that are accidents.

## This is expected and intended

| Area | z/OS `sh` | zksh |
| ---- | --------- | ---- |
| Language | POSIX + some Korn features | ksh88: `(( ))`, `set -A`, `typeset`, `[[ ]]`, `print`, `select`, coprocs |
| Line editing | none | emacs/vi (compiled; not yet pty-tested) |
| History | `fc` re-execution only | full history, `history`, `fc`, `!!` |
| `$[...]` | accepted | accepted only under `set -o zos` |
| `print`, `whence`, `typeset`, `let` | builtins (some) | builtins (ksh88 semantics) |
| `autoload`, `functions`, `writedown`, `stop` | builtins | not provided |
| `_TAG_REDIR_OUT/ERR` | supported | **planned** (D: port from zash) |
| Login flag | `-L` | `-L` and `-l` |

## This is a migration hazard

| Script uses | z/OS `sh` | zksh | Action |
| ----------- | --------- | ---- | ------ |
| `${v/pat/rep}` | no | **no** | add it (planned); until then use `${v#...}` |
| `$[...]` | yes | no (unless `set -o zos`) | rewrite as `$(( ))` |
| `function name { }` | no | yes | fine |
| `set -A` | no | yes | fine |
| `echo -n` | yes | yes | fine |
| `echo -e` | yes | only with `set -o zos` | use `print` / `printf` |
| `[ x = y ]` vs `[[ ]]` | `[` | both | fine |

## Exit status

POSIX 0..255. z/OS programs can return larger values; both shells
truncate, and a script testing `$? -eq 4100` does not work on either.
Not emulated.

## Testing

Add a case to `tests/zos/compat/` naming the z/OS `sh` result and run
it on both shells on z/OS. A difference that cannot be removed gets a
row here; one that can gets fixed and the row removed.
