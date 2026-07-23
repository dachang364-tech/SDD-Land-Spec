# CONSTITUTION

> SDD Plugin 项目级流程强制约束。用户可以修改本文件；修改后，本文件即为当前项目新的流程宪法。

## 1. 阶段门控
- must: SDD 主流程必须按 `/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive` 推进。
- must: `/sdd:spec` 必须在 `prd.md` 存在后执行。
- must: feature plan 必须在 `spec.md` 状态为 `approved` 后生成。
- must: `/sdd:code` 可以执行状态为 `planned` 或 `coding` 的 plan，也可以执行符合条件的 lightweight fix DR。
- must: 受 SDD 管理的文档创建、更新、review、实现与归档都必须经过对应 gate，不能绕过。
- must: 后续阶段只能建立在前置阶段已满足最小门控条件之上。

## 2. 文档状态
- must: SDD 管理的状态行只能使用 `- 状态：<value>` 格式。
- must: spec 状态只能是 `draft` 或 `approved`。
- must: plan 状态只能是 `draft`、`planned`、`coding` 或 `done`。
- must: DR 状态只能是 `drafting`、`accepted` 或 `closed`。
- should: 状态推进应由对应 SDD Skill 完成，不应手工直接改状态。

## 3. 模板治理
- must: 受 SDD 管理的文档，其运行时结构与质量规则必须以项目内运行时模板为唯一事实来源。
- must: skill 内置模板、示例文本或其他静态资源不能作为运行时事实来源。
- must: 若运行时模板缺失，相关 skill 必须视为前置条件不满足，不得静默回退到其他模板来源。
- must: `docs/CONSTITUTION.md` 是 SDD 正式流程、状态、review 与门控规则的事实来源。
- should: 项目根 `CLAUDE.md` 只承载 Claude Code 协作上下文与进入 SDD 工作流前的提醒，不应复制或替代本宪法正文。

## 4. Review 治理
- must: review 是受管文档工作流中的正式 gate，不是可选附加动作。
- must: `research`、`prd`、`dr` 只进入 `quality review`。
- must: `spec`、`plan` 必须先通过 `quality review`，再进入 `feasibility review`。
- must: `dr` 不进入 `feasibility review`。
- must: review 失败或阻断时，不得自动推进文档状态、plan 状态或 DR 状态。
- must: review 通过只表示 gate 已满足，不等于自动 accept、dismiss、done 或 closed。

## 5. DR 流程
- must: 会影响代码实现的变更必须使用代码类 DR：`fix`、`feat`、`chg` 或 `arch`。
- must: 只影响文档表达且不改变系统行为的变更可以使用文档类 DR：`spec`、`doc` 或 `typo`。
- must: 代码类 DR 必须使用 `code_required: yes`；代码类 DR 默认使用 `plan_required: yes`，但简单实现 bug 的轻量 fix DR 可以使用 `plan_required: no`。
- must: 轻量 fix DR 必须是 `fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`，并只能在 `/sdd:code` verification 通过后关闭。
- must: 文档类 DR 必须使用 `plan_required: no` 和 `code_required: no`。
- must: 代码类 DR 必须先 `accepted`，才能生成对应 Implementation Plan。
- must: 代码类 DR 在 spec 修订完成后不得关闭，必须保持 `accepted`，直到关联 plan 完成并通过 verification，或轻量 fix DR 通过 `/sdd:code` verification。
- must: DR 新建或更新后的质量门控属于正式流程前置，但不替代 accept 或 dismiss 决策。
- may: typo 类修订可以按项目约定跳过 DR。

## 6. Plan 约束
- must: plan 是增量实施记录，文件名必须带版本内递增序号 `NNN-`。
- must: Implementation Tasks 是 Technical Design 的执行展开，不是独立设计层。
- must: 如果实现过程中需要改变技术方案、架构边界、模块影响、数据流 / 控制流、测试策略或实现范围，应通过代码类 DR 创建新的增量 plan。
- must: 当前存在 `coding` plan 时，不把新功能或行为变更直接塞进正在 coding 的原 plan。

## 7. Skill 身份
- must: SDD Skill 执行前必须读取本文件，并将其作为本次 Skill 的项目流程约束上下文。
- must: 若用户请求与本文件冲突，Skill 必须先指出冲突；除非用户先修改本文件，否则不直接执行冲突操作。
- must: 各 Skill 只做自己职责范围内的事情。

## 8. Subagent / Code Worker 约束
- must: subagent 或 code worker 不应自行推进 SDD 文档状态，除非当前 `/sdd:code` Skill 明确要求。
- must: code worker 必须按 plan 执行，并在完成前运行 verification。

## 9. Hook 行为
- must: MVP Hook 只守护 L1 路径 → 前置文档状态门控。
- must: Hook 失败时使用退出码 2，并输出中文错误说明。
- must: Hook 不做文档质量判断、不解析本文件 must / should、不拦截 `src/**`。

## 10. 错误处理
- must: Skill 失败时不得破坏上一稳定文档状态。
- must: review 失败或阻断时，相关文档必须保持当前稳定状态，不得自动推进到下一状态。
- should: 执行失败或 verification 失败时，plan 保持 `coding`，关联 DR 保持 `accepted`。

## 11. 用户修改
- may: 用户可以修改本文件以改变项目流程约束。
- should: 修改本文件后，后续 SDD Skill 应以修改后的内容为准。
