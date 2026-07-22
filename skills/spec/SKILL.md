---
name: spec
description: 创建或更新功能规格文档。用户执行 `/sdd:spec` 时使用。
---

# /sdd:spec

在唯一 active version 下创建或修订功能规格文档 `docs/versions/vX.Y.Z/spec/<spec-name>.md`。

## 前置条件

1. 读取 `docs/CONSTITUTION.md`；如果缺失，停止并提示用户先运行 `/sdd:init`。
2. 要求 `docs/versions/` 存在；如果缺失，停止并提示用户先运行 `/sdd:init`。
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. 如果 0 active version，停止并提示用户先运行 `/sdd:new vX.Y.Z`。
5. 如果存在多个 active version 或状态不一致，停止并报告项目状态不一致。
6. 要求 `docs/versions/vX.Y.Z/prd/prd.md` 已存在；如果缺失，停止并提示用户先运行 `/sdd:prd`。
7. 默认目标可为 `spec/spec.md`；同一版本也允许存在多个 `spec/<spec-name>.md`。
8. 如果目标 spec 已存在，必须先询问用户是覆盖、更新还是取消。
9. 如果目标 version 已 archived，则直接失败。

## 对话

1. 读取 active version 的 PRD。
2. 确认目标 spec 文件名。
3. 澄清功能边界、约束、用户故事、业务规则、输入输出、异常与边界场景、验收标准以及非目标。
4. 列出可关联的已接受 document-class DR（`spec`、`doc`、`typo`）。
5. 列出可关联的已接受 code-class DR（`spec_change: yes`，或 `spec_change: maybe` 且需要 spec 更新）。
6. 询问是否需要关联一个或多个 DR。

## 文档引用

将正式关系写入统一的 `## 文档引用` 表：

- 引用当前版本 PRD：`[prd.md](../prd/prd.md)`，关系通常为 `derives_from`。
- 引用当前版本 DR：`[<dr-id>](../dr/<dr-id>.md)`。
- 引用同版本其他 spec：`[<spec-name>.md](./<spec-name>.md)`。
- 引用旧版本 spec/PRD/plan/DR：必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:spec/archive.md`。
- 引用 project-level requirements：必须同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
- `## 文档引用` 是 spec 的正式引用关系来源。
- 不再使用独立 `## 关联 DRs` 作为权威关系表；如需 DR 汇总只能作为辅助阅读信息，且不得与 `## 文档引用` 冲突。

## 步骤

1. 读取 `prd/prd.md`。
2. 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 下的模板与标准。
3. 读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/template.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/quality.standard.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/feasibility.standard.md`。
4. 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
5. reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 中的模板与标准，与生成阶段使用同一套项目级有效资产。
6. 写出 `docs/versions/vX.Y.Z/spec/<spec-name>.md`，并以 `- 状态：draft` 开始。

## Review

- 写入前显式判断目标文件：目标文件不存在：视为 create；存在：视为 update。
- create：成功写入后必须显式调用 `/sdd:review <doc-path>`；`spec` 的 review mode 为 `quality -> feasibility`。新建文档拿不到有效 review 结果时保持 `draft`；若被阻断、需要用户确认或项目模板资产缺失，也保持 `draft`，不得绕过 gate 推进流程。
- update：修改已有文档时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
- 当前 Skill 不承担隐式 review 触发；显式 `/sdd:review <doc-path>` 负责 review 编排、每个 mode 的 schema 校验，并自动按顺序触发 `quality -> feasibility`。
- `quality` JSON 无效、admission check 失败、`blocked: true` 或 `requires_user_confirmation: true` 时，停止，不执行 `feasibility`，聚合已执行结果为一份回执，并保留 `draft`。
- 只有 `quality` 的有效结果未阻断且无需确认时才执行 `feasibility`。`feasibility` 默认弱阻断：未阻断的风险只进入聚合回执；若它返回 `blocked: true`、需要确认或无效 JSON，则保留 `draft`。
- 仅在所有应执行 reviewer 结果有效、未阻断且无需用户确认后，才请求用户审批或提出修改意见。
- 用户确认审批后，将状态切换为 `approved`；reviewer 的候选改写或确认项必须先由用户明确确认、写回并重新复审，普通审批不得绕过。

## DR 状态处理

- 关联 document-class DR 且本次修订完成该 DR：用户确认 spec 后可关闭该 DR，设置 `closed_reason: document-updated` 并写入 `closed_at`；document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`。
- 关联 code-class DR：spec 变为 `approved` 后，该 code-class DR 必须保持 `accepted`，不得因 spec 修订完成而关闭。
- code-class DR 下一步按 `plan_required` 输出：`plan_required: yes` → `/sdd:plan <dr-id>`；`plan_required: no` → `/sdd:code <dr-id>`。

## 边界

- 不创建 active version、不修改 state.json、不创建 plan、不修改 code、不归档版本、不读取 git log。
- 如果 spec 引用 plan，按引用检查规则作为 warning 级例外，并在 `说明` 中解释原因。

## 失败行为

如果用户不批准，spec 保持 `draft`。
