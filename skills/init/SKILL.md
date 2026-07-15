---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

Initialize the current project for SDD. Create the project-level skeleton only; do not create any version.

## Preconditions

1. Check whether `docs/CONSTITUTION.md` exists.
2. If `docs/CONSTITUTION.md` exists, stop and say: `docs/CONSTITUTION.md 已存在；已初始化，请运行 /sdd:status 查看当前状态。`

## Steps

1. Run `scripts/install-deps.sh`.
2. If dependency installation fails, stop and ask the user to run `scripts/install-deps.sh` manually.
3. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
4. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
5. Do not create `.sdd/state.json`.
6. 不创建任何版本目录或版本级 state.json。
7. Do not create `prd.md`, `specs/*.md`, `plans/*.md`, or `decisions/*.md`.
8. Do not modify `CLAUDE.md` or `AGENTS.md`.

## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
```

## State semantics

- 完成后项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 创建。
