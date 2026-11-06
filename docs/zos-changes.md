# z/OS-specific behaviour

The z/OS layer: what zksh adds because it is on z/OS, and how each
piece is switched. **Status: mostly designed, partly inherited, none
compiled on z/OS yet.** Where a piece exists (from the `zos_spawn.c`
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

| Builtin | Status | Behaviour |
| ------- | ------ | --------- |
| `tso` | planned | Run a TSO/E command. Fast path in-process if possible (`IKJTSOEV`), else `tsocmd`. zash defers to `tsocmd` today. |
| `alloc` | planned | Allocate an MVS data set / DD from the shell. Only the shell can, because allocations are not inherited by children. |
| `free` | planned | Free what `alloc` (or a parent's JCL) provided. |
| `zosclass` | planned | Print `omvs`, `telnet`, `rlogin` or `batch` from `_BPX_TERMPATH` and `isatty`. |
| `chtag` | planned | `chtag -p` in-process from `struct stat.st_tag`; all other forms defer to `/bin/chtag` (zash has this). |
| `extattr` | planned | Common `+a/-a` forms in-process; defer otherwise (zash has the shape). |

Off z/OS, all of these exit 2 with "only available on z/OS" (zash's
behaviour, worth keeping: a script can test for them).

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
