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

1. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
2. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
3. Do not create `.sdd/state.json`.
4. 不创建任何版本目录或版本级 state.json。
5. Do not create `prd.md`, `specs/*.md`, `plans/*.md`, or `decisions/*.md`.
6. Do not modify `CLAUDE.md` or `AGENTS.md`.
7. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
8. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。

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
