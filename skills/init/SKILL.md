---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

Initialize the current project for SDD. Create the project-level skeleton only; do not create any version.

## Preconditions

1. Check whether `docs/CONSTITUTION.md` exists.
2. 如果 `docs/CONSTITUTION.md` 已存在，保留现有文件并继续初始化；`docs/CONSTITUTION.md 已存在` 不再是停止条件，以便确保或恢复缺失 `.sdd/templates/` 资产。
3. 如果 `.sdd/templates/` 缺失或不完整，重新执行 `/sdd:init` 以恢复模板资产；不要仅因 `docs/CONSTITUTION.md` 已存在而停止。

## Steps

1. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
   - `.sdd/`
2. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
3. 展示可选模板包列表：通过 `sdd_list_template_packs <plugin_root>` 解析并展示 Plugin `assets/template-packs/` 下的可选模板包列表。
4. 如果用户未显式切换，则使用默认模板包：通过 `sdd_default_template_pack` 获取默认模板包标识。
5. 使用 `sdd_copy_template_pack <plugin_root> <project_root> <pack_name>` 将所选模板包中的 `PRD / Spec / Plan` 模板与标准完整展开到 `.sdd/templates/`。
6. 不创建任何版本目录或版本级 state.json。
7. 不要求把“用户选择了哪个模板包”写入项目元数据文件。
8. 不创建 `prd.md`、`specs/*.md`、`plans/*.md` 或 `decisions/*.md`。
9. 不修改 `CLAUDE.md` 或 `AGENTS.md`。
10. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
11. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。

## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
.sdd/templates/
```

## State semantics

- 完成后项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 创建。
