---
name: plan
description: 基于已批准 spec 或已接受 code-class DR 创建或更新实现计划。用户执行 `/sdd:plan <work-item>` 时使用。
---

# /sdd:plan

在唯一 active version 下创建或修订增量 Implementation Plan，路径位于 `docs/versions/vX.Y.Z/plan/`。

## 前置条件

1. 读取 `docs/CONSTITUTION.md`；如果缺失，停止并提示用户先运行 `/sdd:init`。
2. 要求 `docs/versions/` 存在；如果缺失，停止并提示用户先运行 `/sdd:init`。
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. 如果 0 active version，停止并提示用户先运行 `/sdd:new vX.Y.Z`。
5. 如果存在多个 active version 或状态不一致，停止并报告项目状态不一致。
6. 如果目标 version 已 archived，则直接失败。
7. 仅按语法解析 `<work-item>`，不得靠语义猜测。

## 模式识别

1. 如果 `<work-item>` 匹配 `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$`，使用 code-class DR mode。
2. 如果 `<work-item>` 匹配 `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`，直接拒绝：`文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. 如果 `<work-item>` 看起来像 DR（以三位数字和连字符开头），但不是合法完整 DR ID，即不符合 `001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>` 形式，则显式失败：`无效 DR ID。` 不得落回 spec mode。
4. 其他情况使用 spec mode。

## Plan 编号分配

1. 检查 `docs/versions/vX.Y.Z/plan/[0-9][0-9][0-9]-*.md`。
2. 提取数字前缀。
3. 使用当前最大值之后的下一个三位零填充编号；如果还没有 plan，则使用 `001`。
4. 不要让用户选择 `NNN`，也不要复用已有编号。

## Spec 模式

- `<work-item>` 可以是 spec 文件名、`spec/<spec-name>.md`，或能唯一定位到某个已批准 spec 的功能名。
- 要求目标 spec 状态为 `approved`；如果没有已批准 spec，停止并提示用户先运行 `/sdd:spec` 并完成审批。
- 输出路径：`docs/versions/vX.Y.Z/plan/NNN-<slug>.md`。
- 若同名 plan 已终态，禁止直接修改，必须转 `DR`。
- 若同名 plan 未终态，也需用户确认后更新。

## Code-class DR 模式

- 读取 `docs/versions/vX.Y.Z/dr/<dr-id>.md`。
- Require `状态：accepted`, `class: code`, `plan_required: yes`, `code_required: yes`.
- 如果 `plan_required: no`，则拒绝并提示用户运行 `/sdd:code <dr-id>`。
- 输出路径：`docs/versions/vX.Y.Z/plan/NNN-<dr-id>.md`。

## 技术规划对话

1. 读取相关且已批准的 spec。
2. 在 code-class DR mode 下读取对应 DR。
3. 探索当前代码结构。
4. 识别受影响的模块和文件区域。
5. 提出 2 到 3 种方案。
6. 推荐其中一种，并说明权衡。
7. 确认架构边界、数据与控制流、文件影响、测试策略、风险和约束。
8. 如果无法写出具体文件、测试命令、实现步骤或验收映射，则继续对话，不得输出占位 plan。
9. 只有在用户确认后，才生成 plan。
10. 若创建新 slug plan，按正常流程创建。
11. 若更新同名文档，先读取 plan 当前状态；若已终态，禁止直接修改，必须转 `DR`；若未终态，也需用户确认后更新。

## Plan 质量规则

- 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/` 下的模板与标准。
- 生成必须使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`，并读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/quality.standard.md`。
- 同时读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/feasibility.standard.md`。
- `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/quality.standard.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/feasibility.standard.md` 任一缺失，则直接失败，不降级到 Plugin 内置资产。
- 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
- reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/` 中的模板与标准，与生成阶段使用同一套项目级有效资产。

## Review

- 写入前显式判断目标文件：目标文件不存在：视为 create；存在：视为 update。
- create：写入后必须显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程；该流程调用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner，并沿用 `/sdd:review` 的 `doc-reviewer` agent JSON 调用合同。拿不到有效结果不能继续后续流程；新建文档拿不到有效 review 结果时保持 `draft`。
- update：修改已有文档时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
- `PostToolUse Hook` 仅保留运行时兼容合同，不是本 Skill 的 review 主触发职责。
- runner 对 `plan` 自动按顺序触发 `quality -> feasibility`；每个 mode 的机器结果均须先通过 schema 校验。
- `quality` JSON 无效、admission check 失败、`blocked: true` 或 `requires_user_confirmation: true` 时，停止，不执行 `feasibility`，聚合已执行结果为一份回执，并保留 `draft`。
- 只有 `quality` 的有效结果未阻断且无需确认时才执行 `feasibility`。`feasibility` 在 `plan` 上比 `spec` 更严格；它返回 `blocked: true`、需要确认或无效 JSON 时保留 `draft`，高杠杆技术决策仍必须等待用户确认。
- 仅在所有应执行 reviewer 结果有效、未阻断且无需用户确认后，才能请求普通审批或将状态从 `draft` 推进为 `planned`；确认项写回后必须重新复审。
- review 阻断、需要用户确认或模板资产缺失时不得绕过 gate 推进流程。

- `Implementation Tasks` 必须是可由 agentic worker 直接执行的 TDD 手册，不是概要 TODO。
- 每个 task 必须包含精确 `Files`、`Interfaces`、`Acceptance Mapping` 和 checkbox steps。
- 测试步骤包含实际测试代码或 contract assertion、运行命令和 expected FAIL/PASS 输出。
- 实现步骤包含足够具体的代码、替换片段、文件内容或修改说明。
- commit 步骤包含具体 `git add` 路径和 `git commit -m` 信息。
- 最终 plan 不得保留占位符（`TBD`、`TODO`、`待定`、`待补充`、`path/to/file` 等）。
- 写出 plan 前必须执行自检：spec coverage、placeholder scan、type/naming consistency，记录在 `## 7. Self-Review`。

## 文档引用

- plan 引用 spec 时，关系应为 `implements`。
- plan 引用 code-class DR 时，关系应为 `implements`。
- plan 引用其他 plan、历史 plan 或历史 DR 作为背景时，关系可为 `references`。
- 引用同版本文档时，只写相对 Markdown link，不写版本 locator。
- 引用跨版本文档时，必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:plan/001-archive.md`。
- plan 不得使用 `modifies`、`replaces`、`deprecates`。
- 如果发现需要改变功能契约，停止当前 plan 生成流程，先创建或修订 DR / spec。

## 状态流转

- 初始状态为 `- 状态：draft`。
- 用户审批后切换为 `- 状态：planned`。
- 不把任何 DR 改为 closed；不改变 code-class DR 状态（保持 accepted）。

## 边界

- 不创建 active version、不修改 state.json、不修改 spec、不修改 DR 状态、不修改 code、不归档版本、不重开 closed DR、不改写 done plan。
