---
name: prd
description: 创建或更新产品需求文档。用户执行 `/sdd:prd` 时使用。
---

# /sdd:prd

在唯一 active version 下创建或更新 `docs/versions/vX.Y.Z/prd/prd.md`。

## 前置条件

1. 读取 `docs/CONSTITUTION.md`；如果缺失，停止并提示用户先运行 `/sdd:init`。
2. 要求 `docs/versions/` 存在；如果缺失，停止并提示用户先运行 `/sdd:init`。
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. 如果 0 active version，停止并提示用户先运行 `/sdd:new vX.Y.Z`。
5. 如果存在多个 active version 或状态不一致，停止并报告项目状态不一致。
6. 目标文件固定为 `docs/versions/vX.Y.Z/prd/prd.md`。
7. 如果目标 version 已 archived，则直接失败。

## 对话

1. 与用户讨论当前版本的业务背景、目标用户、问题陈述、范围和成功标准。
2. 确认是否需要引用本版本下的 research 文档作为背景材料。
3. 如果 `prd/prd.md` 已存在，先与用户讨论并确认后更新同一文件。

## 输出

使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md` 写出 `docs/versions/vX.Y.Z/prd/prd.md`。

- 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md` 和同目录下的质量标准。
- 生成前必须读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md` 和 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/quality.standard.md`。
- 如果 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/` 下必要文件缺失，则直接失败并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
- 一个版本只有一个正式 PRD：`docs/versions/vX.Y.Z/prd/prd.md`。
- 如果 `prd/prd.md` 不存在，则创建。
- 如果 `prd/prd.md` 已存在，默认不直接覆盖；必须先与用户确认，再更新同一文件。
- `prd` 不走 `DR` 变更门。
- 不强制 `## 文档引用` 表，由模板与标准定义结构要求。
- 不写 `- 状态：` 行。

## Review

- 写入前显式判断目标文件：目标文件不存在：视为 create；存在：视为 update。
- create：写入后必须显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程；该流程调用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner，并沿用 `/sdd:review` 的 `doc-reviewer` agent JSON 调用合同。拿不到有效结果不能继续后续流程。
- update：修改已有文档时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
- `PostToolUse Hook` 仅保留运行时兼容合同，不是本 Skill 的 review 主触发职责。
- runner 对 `prd` 只执行 `quality`，不接入 `feasibility`。
- reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/` 中的模板与标准。
- 用户确认并完成有效复审前，不得绕过该结果推进流程；如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。

## 边界

- 不创建 active version、不修改 state.json、不创建 spec/plan/DR、不归档版本。
