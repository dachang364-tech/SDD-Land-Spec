# SDD Plugin

SDD Plugin provides an MVP Specification Driven Development workflow for Claude Code.

## Commands

- `/sdd:init`
- `/sdd:new vX.Y.Z`
- `/sdd:research <topic>`
- `/sdd:prd`
- `/sdd:spec`
- `/sdd:plan <work-item>`
- `/sdd:code <NNN|work-item>`
- `/sdd:dr <tag> <title>`
- `/sdd:dr accept <id>`
- `/sdd:dr dismiss <id> <reason>`
- `/sdd:status`
- `/sdd:doctor`
- `/sdd:archive`

## Install dependencies

```bash
scripts/install-deps.sh
```

## Workflow

```text
/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive
```

Code-affecting changes use:

```text
/sdd:dr fix|feat|chg|arch <title> → /sdd:dr accept <id> → /sdd:plan <id> → /sdd:code <NNN|id>
```
