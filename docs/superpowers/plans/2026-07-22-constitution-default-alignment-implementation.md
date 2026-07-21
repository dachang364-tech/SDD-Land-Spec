# CONSTITUTION.default.md Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `CONSTITUTION.default.md` 收敛为与当前 SDD 工作流一致的默认项目级流程宪法，补齐模板治理与 review 治理规则，并消除 DR 终态表述冲突。

**Architecture:** 本次实现只修改默认宪法文件本身，不触碰 skill、script、README、tests 或其他文档。实现方式是重组现有章节，新增“模板治理”和“review 治理”高层规则，统一 DR 终态为 `closed`，并用纯流程级语言表达规则，避免引入模板路径、schema、agent、打包或测试细节。

**Tech Stack:** Markdown, repository governance docs, SDD constitution rules.

## Global Constraints

- 目标文件只允许是 `CONSTITUTION.default.md`；本次实现不得修改其他文件。
- `CONSTITUTION.default.md` 只保留项目级默认流程约束，不得引入模板路径、schema、agent、打包、测试或脚本实现细节。
- 必须补齐“运行时模板单一事实来源”与“review 是正式 gate”两类高层规则。
- 必须明确 `research / prd / dr -> quality`，`spec / plan -> quality -> feasibility`。
- 必须明确 `dr` 不进入 `feasibility review`。
- 必须明确 review 失败或阻断时不得自动推进状态。
- 必须统一 DR 合法状态与终态表述，删除 `committed` 作为 DR 终态的表述，仅保留 `closed`。
- 现有主流程门控、DR 分类、lightweight fix DR 与 code verification 的核心意图必须保留，不得被削弱。

---

### Task 1: 重写默认宪法结构并收敛高层规则

**Files:**
- Modify: `CONSTITUTION.default.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-22-constitution-default-alignment-design.md` 中确认的高层规则与非目标边界。
- Produces: 一份自洽、只包含项目级默认流程约束的 `CONSTITUTION.default.md`，章节结构调整为：阶段门控、文档状态、模板治理、review 治理、DR 流程、Plan 约束、Skill 身份、Subagent / Code Worker 约束、Hook 行为、错误处理、用户修改。

- [ ] **Step 1: 先写出失败检查脚本并人工对照当前文件**

在终端中逐条执行以下检查命令，确认当前默认宪法还不满足新设计：

```bash
grep -n 'committed' CONSTITUTION.default.md
grep -n 'quality review' CONSTITUTION.default.md
grep -n 'feasibility review' CONSTITUTION.default.md
grep -n '运行时模板' CONSTITUTION.default.md
```

预期人工结论：

```text
- 当前文件仍出现 DR 终态冲突：既有 `closed`，又有 `committed`。
- 当前文件没有单独的“模板治理”章节。
- 当前文件没有单独的“review 治理”章节。
- 当前文件没有明确 `research / prd / dr -> quality` 与 `spec / plan -> quality -> feasibility`。
```

- [ ] **Step 2: 运行失败检查，确认缺口真实存在**

Run:

```bash
grep -n 'committed' CONSTITUTION.default.md && ! grep -n 'quality review' CONSTITUTION.default.md && ! grep -n '运行时模板' CONSTITUTION.default.md
```

Expected:

```text
- 输出中至少出现 `committed` 所在行。
- `quality review` 与 `运行时模板` 在当前文件中查不到。
- 这说明当前文件尚未对齐新设计。
```

- [ ] **Step 3: 用完整正文重写 `CONSTITUTION.default.md`**

将 `CONSTITUTION.default.md` 全文替换为以下内容：

```md
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
```

- [ ] **Step 4: 运行检查，确认新文本满足设计约束**

Run:

```bash
! grep -n 'committed' CONSTITUTION.default.md
grep -n '## 3. 模板治理' CONSTITUTION.default.md
grep -n '## 4. Review 治理' CONSTITUTION.default.md
grep -n '`research`、`prd`、`dr` 只进入 `quality review`' CONSTITUTION.default.md
grep -n '`spec`、`plan` 必须先通过 `quality review`，再进入 `feasibility review`' CONSTITUTION.default.md
grep -n '运行时结构与质量规则必须以项目内运行时模板为唯一事实来源' CONSTITUTION.default.md
```

Expected:

```text
- `committed` 无输出。
- 上述新增章节与规则都能被准确匹配到。
```

- [ ] **Step 5: 做最终人工复核，确认没有下沉到实现细节**

人工检查 `CONSTITUTION.default.md`，确认以下词项不应作为规则正文出现：

```text
- `.sdd/templates/`
- `doc-reviewer`
- `schema`
- `JSON`
- `package`
- `tests/`
```

并确认以下设计目标已达成：

```text
- 只保留项目级流程约束。
- DR 终态只保留 `closed`。
- review gate 与状态推进的关系已明确。
- 模板治理只写原则，不写路径实现。
```

- [ ] **Step 6: Commit**

```bash
git add CONSTITUTION.default.md docs/superpowers/plans/2026-07-22-constitution-default-alignment-implementation.md
git commit -m "docs: align default constitution with review governance"
```

---

## Self-Review

### Spec coverage

- Task 1 覆盖了章节重组。
- Task 1 覆盖了模板治理与 review 治理高层规则。
- Task 1 覆盖了 DR 终态统一为 `closed`。
- Task 1 覆盖了“不引入实现细节”的边界检查。

### Placeholder scan

- 无 `TBD`、`TODO`、`implement later`。
- 所有步骤都给出了准确文件路径、命令和预期结果。
- 唯一修改目标明确限制为 `CONSTITUTION.default.md`。

### Type consistency

- review 链路统一为：`research / prd / dr -> quality`，`spec / plan -> quality -> feasibility`。
- DR 状态统一为：`drafting / accepted / closed`。
- `review`、`verification`、`accept`、`dismiss`、`done`、`closed` 的关系在计划中保持一致。
