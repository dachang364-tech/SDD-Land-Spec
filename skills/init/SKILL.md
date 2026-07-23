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
4. 如果 `${CLAUDE_PROJECT_DIR}/CLAUDE.md` 缺失，允许本次初始化补齐项目级 Claude Code 协作说明；如果 `${CLAUDE_PROJECT_DIR}/CLAUDE.md` 已存在，则必须完整保留原文件，不覆盖、不合并。
5. `AGENTS.md` 不属于 `/sdd:init` 管理范围；无论存在与否，都不创建、不修改、不删除。

## Template Packs

- 展示可选模板包列表：调用 `sdd_list_template_packs "$plugin_root"` 获取模板包列表，列表必须来自 Plugin `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/` 的真实目录结果。
- 将模板包列表展示给用户并请求选择；用户必须先看到可用列表，再做一次模板包选择。
- 如果用户未显式切换，则使用默认模板包：如果用户未显式切换，则调用 `sdd_default_template_pack` 取得默认值；当前默认值为 `backend`。
- 校验所选值属于可用模板包；若用户选择不在可用列表中，直接失败。
- 当前运行时只实现 `backend`；若用户选择的可用模板包不是 `backend`，直接失败并说明当前未实现。
- 若用户选择未实现模板包，直接失败并说明当前不可用。
- 只有在模板包选择完成后才调用 `sdd_copy_template_pack`。
- 使用 `sdd_copy_template_pack <plugin_root> <project_root> <pack_name>` 将所选模板包中的 `research / PRD / Spec / Plan / dr` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。
- `/sdd:init` 会物化 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`。
- 重复执行只补齐缺失文件，不覆盖用户已定制模板。
- 如果 `sdd_copy_template_pack` 返回非零，停止并报告失败；不得输出初始化成功结果。
- 不要求把“用户选择了哪个模板包”写入项目元数据文件。

## Steps

1. 解析 `plugin_root=${CLAUDE_PLUGIN_ROOT}` 与 `project_root=${CLAUDE_PROJECT_DIR}`。
2. 加载模板 helper，确保后续可调用 `sdd_list_template_packs`、`sdd_default_template_pack`、`sdd_copy_template_pack` 与 `sdd_ensure_project_claude`。
3. Create project-level directories:
   - `docs/versions/`
   - `docs/archive/`
   - `${CLAUDE_PROJECT_DIR}/.sdd/`
4. 仅当 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 缺失时，复制 `CONSTITUTION.default.md`；如果 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 已存在，则保留现有文件，不覆盖用户内容。
5. 仅当 `${CLAUDE_PROJECT_DIR}/CLAUDE.md` 缺失时，调用 `sdd_ensure_project_claude "$plugin_root" "$project_root"` 复制 `${CLAUDE_PLUGIN_ROOT}/assets/project/CLAUDE.md`；如果 `${CLAUDE_PROJECT_DIR}/CLAUDE.md` 已存在，则保留现有文件，不覆盖、不合并。
6. 如果 `sdd_ensure_project_claude` 返回非零，停止并报告失败，不输出初始化成功结果。
7. 不处理 `AGENTS.md`；无论 `${CLAUDE_PROJECT_DIR}/AGENTS.md` 是否存在，都不创建、不修改、不删除。
8. 调用 `sdd_list_template_packs "$plugin_root"` 获取模板包列表。
9. 将模板包列表展示给用户并请求选择。
10. 如果用户未显式切换，则调用 `sdd_default_template_pack` 取得默认值 `backend`。
11. 校验所选值属于可用模板包；若不是则失败。
12. 若所选值不是 `backend`，直接失败并说明当前仅实现 `backend`。
13. 复制 `CONSTITUTION.default.md`、`${CLAUDE_PROJECT_DIR}/CLAUDE.md` 与模板资产时，只在缺失时写入；不得覆盖用户已有内容。
14. 只有在模板包选择完成后才调用 `sdd_copy_template_pack "$plugin_root" "$project_root" "$selected_pack"`。
15. 如果 `sdd_copy_template_pack` 返回非零，停止并报告失败，不输出初始化成功结果。
16. 全部成功后，将所选模板包中的 `research / prd / spec / plan / dr` 运行时模板与标准文件物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。
17. 不创建任何版本目录或版本级 `state.json`。
18. 不创建 `prd/prd.md`、`research/*.md`、`spec/*.md`、`plan/*.md` 或 `dr/*.md` 等正文文件。
19. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
20. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。

## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/versions/
docs/archive/
${CLAUDE_PROJECT_DIR}/CLAUDE.md
${CLAUDE_PROJECT_DIR}/.sdd/templates/
```

## State semantics

- 完成后项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 创建。
