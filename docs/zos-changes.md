# z/OS-specific behaviour

The z/OS layer: what zksh adds because it is on z/OS, and how each
piece is switched. **Status: process creation inherited and unverified; builtins
written and tested only off z/OS; tagging and MVS data sets still to
come.** Where a piece exists (from the `zos_spawn.c`
work), it says so.

Every item below has an off switch so a site can restore stock
behaviour: `set -o zos` turns z/OS dialect *on*; `_ZOS_*` environment
variables switch individual mechanisms.

## Process creation (inherited, unverified on z/OS)

| Item | Behaviour | Source |
| ---- | --------- | ------ |
| `spawnp()` for external commands | No fork, no address-space copy; fd map, signal state and process group passed to `SPAWN_SETGROUP\|SPAWN_NEWPGROUP` | `zos_spawn.c`, from `3d04c43` |
| Fork only for shell code | Subshells, pipeline stages that are builtins/functions, `$( )` with shell code, coprocs | same |
| `_BPX_SHAREAS=YES` | Set at startup so leftover forks are shared daughters | `zos_spawn_init()` |
| `_OKSH_SHAREAS=NONE` | Leave `_BPX_SHAREAS` alone | `zos_spawn.c` |
| `_BPX_JOBNAME=OKSH` | Batch display name | `zos_spawn.c` — **to rename ZKSH** |

## Builtins

All six exist in `src/zos_builtins.c` and are registered in
`kshbuiltins[]`. **Status: built and tested off z/OS; the `__MVS__`
bodies have never been compiled.** Off z/OS each one prints
"only available on z/OS" and returns 2, which `tests/zos.sh` checks;
that is the contract a script can test for.

| Builtin | Status | Behaviour |
| ------- | ------ | --------- |
| `tso` | written, unbuilt | `tso command [arg ...]` runs a TSO/E command via `tsocmd`. The in-process path (`IKJTSOEV`) is deliberately not attempted: it needs authorization, and getting it wrong takes the TSO session down instead of returning an error. |
| `alloc` | written, unbuilt | `alloc "dsn('HLQ.DS') new catalog"`. Arguments are joined and passed as one quoted operand to `tsocmd ALLOC`, because TSO/E ALLOC wants a single operand string. |
| `free` | written, unbuilt | `free "dsn('HLQ.DS')"`, `free dd(NAME)`, `free all` -- one quoted operand to `tsocmd FREE`. |
| `zosclass` | written, unbuilt | Prints one word: `omvs`, `telnet`, `rlogin` or `batch`. No arguments, so it composes as `case $(zosclass) in`. `batch` when stdin is not a tty (TSO line mode); otherwise `_BPX_TERMPATH` decides between telnet, rlogin and omvs. |
| `chtag` | written, unbuilt | `chtag -p file ...` in process from `struct stat.st_tag` (a `stat()`, no spawn); every other form defers to `/bin/chtag`. |
| `extattr` | written, unbuilt | Defers to `/bin/extattr`. The in-process `+a/-a/+p/+s/+l` forms are not written; the name exists so scripts can rely on it. |

"Defers" means: build a command line and run it through `command()`,
so the utility gets the shell's PATH, redirections and exit status.
Each argument is quoted on the way (a `/` and a `'` are the two that
matter here), never concatenated raw -- the same rule applies on EBCDIC
as on ASCII.

Never compiled on z/OS, so these are the first things a build there
will challenge (`VERIFY` in the source): the `<_Ccsid.h>` header name
and `__toCSName()` signature, `st_tag.ft_ccsid`/`ft_txtflag`, and that
`tsocmd` and `/bin/chtag` exist under those names.

## Redirection

| Item | Status | Behaviour |
| ---- | ------ | --------- |
| `_TAG_REDIR_OUT`, `_TAG_REDIR_ERR` = `TXT` \| `BIN` | planned | Deferred tag (`F_SETTAG`, CCSID 0) on untagged regular targets. |
| `_TAG_REDIR_IN` | planned | `F_CONTROL_CVT` on/off. |
| `> //'HLQ.DS'`, `> //DD:NAME` | planned | Pump child that `fopen`s the data set. Costs a fork; output pumps not waited on (race). |
| ASCII-mode pipes tagged IBM-1047 | planned | zoslib's ISO8859-1 default leaves EBCDIC readers seeing ASCII (zash measured this). |

## Profiles and session

| Item | Behaviour |
| ---- | --------- |
| `/etc/profile`, `$HOME/.profile` | read on login, as z/OS does |
| `$ENV` | read by every interactive shell |
| `-L` | login shell, as z/OS does (`-l` also accepted) |
| `$ZOSH_ETC/profile.d/` | site additions, sourced in order (planned) |
| Prompt | `PS1='$LOGNAME:$PWD: >'` default until set (planned) |

## Line mode

OMVS is line mode only; `isatty()` is false under TSO. The rule:
read whole lines, never enter raw mode, and provide numbered history
and `!!`/`!n` instead of a full-screen editor. libedit is still used
when a telnet/rlogin terminal gives a real tty. See D4 in
`direction.md`.

## Where the code lives

- `zos_spawn.c` / `zos_spawn.h` — process creation (present).
- `zos_builtins.c` — `tso`, `alloc`, `free`, `zosclass`, `chtag`,
  `extattr` (planned; port zash's file as a starting point).
- `sys_zos.c` — tagging, redirection, input sniffing (planned).
- New builtins must be added to `builtins[]` in `c_ksh.c`/`c_sh.c`
  and to `configure`'s object list if a new file is used.
