# zksh documentation

These documents describe the shell as it stands. They are the
project's working memory: when the design changes, the document
changes in the same commit as the code. Parts not built yet are
marked **planned**.

| Document | Covers | State |
| -------- | ------ | ----- |
| [direction.md](direction.md) | the constitution: three rules, lineage, what is refused | decided |
| [status.md](status.md) | what works today, what is next | living |
| [language.md](language.md) | the closed language set, verified against the build | living |
| [budget.md](budget.md) | enforced size, build, binary and runtime budgets | living |
| [build.md](build.md) | CMake and Ninja on both hosts, options, what replaced oksh's configure | living |
| [merge.md](merge.md) | what came from oksh, zash and FreeBSD ash, and why | living |
| [zos-changes.md](zos-changes.md) | the z/OS builtins and dialect | mostly planned |
| [compat.md](compat.md) | differences from the z/OS `sh` | living |
| [port.md](port.md) | every edit to the oksh base | living |

## Shape

```mermaid
flowchart TB
    OKSH["oksh 7.9 (src/)<br/>pdksh / ksh88<br/>parser, eval, jobs, editor"]
    SPAWN["src/zos/zos_spawn.c<br/>spawnp first, fork for shell code"]
    ZB["src/zos/zos_builtins.c<br/>tso chtag extattr (phase 1)"]
    TAG["src/zos/sys_zos.c<br/>tagging, //DSN (phase 1)"]
    INT["history, completion, prompt<br/>libedit (phase 2)"]
    OKSH --> ZKSH["zksh"]
    SPAWN --> ZKSH
    ZB --> ZKSH
    TAG --> ZKSH
    INT --> ZKSH
```

## What zksh is not

Not AT&T ksh88 (the UCS/DFKSH shell behind z/OS `/bin/sh`), not
ksh93, not bash, not a POSIX-only shell. Those distinctions are
decision-relevant and are argued in [direction.md](direction.md).
