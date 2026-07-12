---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

Initialize current project for SDD Plugin MVP.

## Preconditions

1. Check whether `docs/CONSTITUTION.md` exists.
2. If `docs/CONSTITUTION.md` exists, stop and say: `docs/CONSTITUTION.md 已存在；已初始化，请运行 /sdd:status 查看当前状态。`

## Steps

1. Run `scripts/install-deps.sh`.
2. If dependency installation fails, stop and ask the user to run `scripts/install-deps.sh` manually.
3. Create directories:
   - `docs/requirements/`
   - `docs/archive/`
4. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
5. Do not create `.sdd/state.json`.
6. 不要创建 .sdd/state.json。
7. Do not create any version directory.
8. Do not create `prd.md`, `spec.md`, or plan files.
9. Do not modify `CLAUDE.md` or `AGENTS.md`.

## Output

Report created paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/archive/
```
