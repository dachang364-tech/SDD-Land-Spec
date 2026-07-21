---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

初始化当前项目的 SDD 基础结构；只创建项目级骨架与运行时模板资产，不创建任何版本。

## Preconditions

1. 检查 `docs/CONSTITUTION.md` 是否存在。
2. 如果 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 已存在，保留现有文件并继续初始化；`docs/CONSTITUTION.md` 已存在不再是停止条件，以便确保或恢复缺失 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 资产。
3. 如果 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 缺失或不完整，重新执行 `/sdd:init` 仅补齐缺失的模板资产；保留现有项目模板和标准文件，不得覆盖用户定制。

## Template Packs

- 展示可选模板包列表：通过 `sdd_list_template_packs <plugin_root>` 解析并展示 Plugin `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/` 下的可选模板包列表。
- 支持模板包选择机制，例如 `backend`、`frontend`。
- 当前仅实现 `backend`。
- 若用户选择未实现模板包，直接失败并说明当前不可用。
- 如果用户未显式切换，则使用默认模板包：通过 `sdd_default_template_pack` 获取默认模板包标识。
- 使用 `sdd_copy_template_pack <plugin_root> <project_root> <pack_name>` 将所选模板包中的 `research / PRD / Spec / Plan / dr` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。
- `/sdd:init` 会物化 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`。
- 重复执行只补齐缺失文件，不覆盖用户已定制模板。
- 不要求把“用户选择了哪个模板包”写入项目元数据文件。

## Steps

1. Create project-level directories:
   - `docs/versions/`
   - `docs/archive/`
   - `${CLAUDE_PROJECT_DIR}/.sdd/`
2. 仅当 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 缺失时，复制 `CONSTITUTION.default.md`；如果 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 已存在，则保留现有文件，不覆盖用户内容。
3. 将所选模板包中的 `research / prd / spec / plan / dr` 运行时模板与标准文件物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。
4. 不创建任何版本目录或版本级 `state.json`。
5. 不创建 `prd/prd.md`、`research/*.md`、`spec/*.md`、`plan/*.md` 或 `dr/*.md` 等正文文件。
6. 不修改 `CLAUDE.md` 或 `AGENTS.md`。
7. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
8. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。

## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/versions/
docs/archive/
${CLAUDE_PROJECT_DIR}/.sdd/templates/
```

## State semantics

- 完成后项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 创建。
