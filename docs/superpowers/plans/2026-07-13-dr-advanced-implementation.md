# DR Advanced Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the remaining DR Advanced behavior from `docs/superpowers/specs/2026-07-13-dr-advanced-spec.md`, including `/sdd:triage`, lightweight fix DR execution, Markdown cross-document links, and contract coverage.

**Architecture:** Keep the plugin file-driven: behavior is defined by Claude Code Skill markdown files, templates under `skills/*/references/`, README/constitution user-facing contracts, and shell contract tests. This plan treats `docs/superpowers/specs/2026-07-13-dr-advanced-spec.md` section 10 as incremental constraints on existing skills, not a rewrite of `/sdd:dr`, `/sdd:spec`, `/sdd:plan`, or `/sdd:code`. The existing DR Advanced workflow already covers much of the field model, so implementation focuses on the missing deltas.

**Tech Stack:** Claude Code Skills markdown, Markdown templates, Bash contract tests using `tests/test-common.sh`, existing SDD status-line conventions.

## Global Constraints

- Do not introduce `.sdd/state.json` or any centralized state store.
- State lines must keep the format `- 状态：<value>`.
- Historical DR files are not migrated automatically.
- Keep one main DR template at `skills/dr/references/dr.md.tmpl`.
- Cross-document references among spec, plan, and DR must use standard Markdown links with relative paths.
- Section numbers and headings may remain plain text after file links; do not require Markdown anchor links.
- `/sdd:triage` must not create DRs, accept DRs, close DRs, modify spec, modify plan, modify code, or change plan state.
- `/sdd:triage` must use minimal context and progressive reads; it must not default to scanning the whole active version, all plans, all decisions, or all code.
- Lightweight fix DR is allowed only for code-class `fix` DRs with `plan_required: no` and `code_required: yes`.
- `## 10. 对既有 Skill 的增量行为要求` in the spec defines incremental constraints on existing skills, not a full redefinition of those skills.

---

## File Structure

- Create `skills/triage/SKILL.md`: defines `/sdd:triage` as a read-only diagnostic skill with classification, confidence, evidence, recommended path, and optional paths.
- Modify `skills/dr/SKILL.md`: keep existing create/accept/dismiss responsibilities, add lightweight fix guidance, Markdown link requirements, and `plan_required: no` next-step handling.
- Modify `skills/dr/references/dr.md.tmpl`: keep existing DR Advanced fields and empty `影响资产` table; do not add fake placeholder asset rows to every new DR.
- Modify `skills/spec/SKILL.md`: keep existing spec generation behavior, add Markdown link requirements for `关联 DR` and make document-class closing reason explicit.
- Modify `skills/spec/references/spec.md.tmpl`: change the `关联 DRs` table to link-oriented columns.
- Modify `skills/plan/SKILL.md`: keep existing feature/code-class DR modes, add Markdown link requirements and maintain rejection of document-class and `plan_required: no` DRs.
- Modify `skills/plan/references/plan.md.tmpl`: make `关联 DR` link-oriented.
- Modify `skills/code/SKILL.md`: add direct lightweight fix DR execution mode while preserving existing plan execution mode.
- Modify `README.md`: document `/sdd:triage`, lightweight fix, and Markdown link behavior at user-facing level.
- Modify `CONSTITUTION.default.md`: update DR constraints so lightweight fix DR does not conflict with `plan_required: yes` default for code-class DRs.
- Modify `tests/test-skill-contracts.sh`: add static contract assertions for all new and changed behavior.

---

### Task 1: Add `/sdd:triage` Skill Contract

**Files:**
- Create: `skills/triage/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: active SDD version directory, `docs/CONSTITUTION.md`, relevant spec/plan/DR/code context selected by the user question.
- Produces: read-only `/sdd:triage` contract with classifications `code implementation issue`, `plan issue`, `spec issue`, `new requirement / change request`, `explanation only`, `unclear, needs user choice`.

- [ ] **Step 1: Write failing contract assertions**

Add `triage` to the skill existence loop in `tests/test-skill-contracts.sh`:

```bash
for skill in init new research prd spec plan code dr triage status doctor archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done
```

Add these assertions after the existing `/sdd:dr` assertions:

```bash
assert_contains "skills/triage/SKILL.md" "description: Triage user questions after implementation, review, or testing"
assert_contains "skills/triage/SKILL.md" "不创建 DR"
assert_contains "skills/triage/SKILL.md" "不修改 spec"
assert_contains "skills/triage/SKILL.md" "不修改 plan"
assert_contains "skills/triage/SKILL.md" "不修改 code"
assert_contains "skills/triage/SKILL.md" "不改变 plan 状态"
assert_contains "skills/triage/SKILL.md" "不替用户选择后续路径"
assert_contains "skills/triage/SKILL.md" "必须等待用户确认后"
assert_contains "skills/triage/SKILL.md" "不得一次性读取整个 active version 目录"
assert_contains "skills/triage/SKILL.md" "不得默认读取所有 `plans/*.md`"
assert_contains "skills/triage/SKILL.md" "不得默认读取所有 `decisions/*.md`"
assert_contains "skills/triage/SKILL.md" "不得默认读取代码"
assert_contains "skills/triage/SKILL.md" "/sdd:triage --deep"
assert_contains "skills/triage/SKILL.md" "code implementation issue"
assert_contains "skills/triage/SKILL.md" "spec 和 plan 基本正确，但当前代码实现偏离预期"
assert_contains "skills/triage/SKILL.md" "plan issue"
assert_contains "skills/triage/SKILL.md" "spec issue"
assert_contains "skills/triage/SKILL.md" "new requirement / change request"
assert_contains "skills/triage/SKILL.md" "unclear, needs user choice"
assert_contains "skills/triage/SKILL.md" "置信度：low | medium | high"
assert_contains "skills/triage/SKILL.md" "已读取依据"
assert_contains "skills/triage/SKILL.md" "请确认你要走哪条路径。"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL because `skills/triage/SKILL.md` does not exist yet.

- [ ] **Step 3: Create the triage skill**

Create `skills/triage/SKILL.md` with this content:

```markdown
---
name: triage
description: Triage user questions after implementation, review, or testing. Use for /sdd:triage and /sdd:triage --deep.
---

# /sdd:triage

Triage user questions before choosing whether to create a DR, revise spec, revise plan, change code, or explain existing behavior.

## Scope

`/sdd:triage` is a read-only diagnostic skill. It recommends a path and waits for the user to choose. It does not execute the chosen path.

It applies when the user asks questions such as:

- “这个是不是有问题？”
- “为什么这里这样实现？”
- “这里是不是应该改？”
- “这个行为和我预期不一样。”
- “这个 plan 当时是不是漏了什么？”
- “spec 里是不是应该说明这个边界？”

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Identify the smallest useful locator from the user question: feature name, section number, DR ID, plan filename, observed symptom, or code path.
4. Read minimal active-version structure information, such as spec, plans, and decisions filenames.
5. Read only the candidate spec section, plan, DR, or code files needed for the question.
6. Do not modify files.

## Hard rules

- 不创建 DR。
- 不接受 DR。
- 不关闭 DR。
- 不修改 spec。
- 不修改 plan。
- 不修改 code。
- 不改变 plan 状态。
- 不替用户选择后续路径。
- 必须向用户说明推荐路径和可选路径。
- 必须等待用户确认后，才能建议进入其他 skill。

## Token control

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `plans/*.md`。
- 不得默认读取所有 `decisions/*.md`。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。
- 必须优先使用用户提供的功能名、小节号、DR ID、plan 文件名、错误现象或相关文件路径来缩小范围。

Recommended read order:

1. Understand the user question and ask for a locator if needed.
2. Read minimal active-version structure information, such as spec, plans, and decisions filenames.
3. Read only the relevant spec section.
4. Read only the relevant plan.
5. Read only the relevant DR.
6. Read code only when needed to compare implementation against spec or plan.
7. If evidence is insufficient, output a low-confidence triage and state what context is missing.

## Depth

```text
/sdd:triage
```

Default lightweight triage. Read necessary docs only and do not scan all code.

```text
/sdd:triage --deep
```

Deep triage. Read more relevant plan, DR, or code context, but still only after narrowing the candidate range.

## Classification

Output one classification:

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 基本明确，但 plan 拆解、实现策略、任务边界或验收安排有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

## Analysis order

1. Does the approved spec clearly describe the expected behavior?
2. Does the plan correctly cover the relevant spec behavior?
3. Does the current implementation match the plan and spec?
4. Does the question expose a missing or ambiguous spec rule?
5. Is the user asking for a new requirement or behavior change?
6. Is the user asking only for an explanation of existing behavior?

## Output format

```text
我的判断：这是 <分类>。
置信度：low | medium | high
已读取依据：
- <spec 小节或文件>
- <plan 文件，如有>
- <DR 文件，如有>
- <代码文件，如有>
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

## Recommended paths

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且可轻量修复 | `fix DR -> code -> verification` |
| B | 代码实现问题，但需要 plan | `fix DR -> plan -> code -> verification` |
| C | plan 问题 | `fix DR -> revised plan -> code -> verification` |
| D | spec 问题 | `fix/spec DR -> spec -> plan -> code -> verification` |
| E | 新需求或行为变更 | `new feat/chg DR -> spec -> plan -> code -> verification` |
| F | 仅解释现有行为 | `explain only -> no DR` |

## Original DR handling

- If the original feature/chg/arch DR has completed `/sdd:code` and the question appears during review or follow-up discussion, use a new DR by default.
- If the original DR is closed, do not reopen it.
- If the original DR has not completed implementation and the issue is still in the same plan/code execution scope, the current flow can continue, but explain this choice to the user.
- A new DR may link to the original DR; do not use `supersedes` for ordinary bug-fix relationships unless the new DR replaces the original decision.
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for the triage existence and contract assertions.

- [ ] **Step 5: Commit**

```bash
git add skills/triage/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: add triage skill contract"
```

---

### Task 2: Add Markdown Link Contracts for Spec, Plan, and DR

**Files:**
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/spec/references/spec.md.tmpl`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/plan/references/plan.md.tmpl`
- Modify: `skills/dr/SKILL.md`
- Modify: `skills/dr/references/dr.md.tmpl`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: DR IDs, plan filenames, spec paths.
- Produces: Markdown-link contract for `关联 DR`, `关联 DRs`, and `影响资产` references using relative paths.

- [ ] **Step 1: Write failing link assertions**

Add these assertions to `tests/test-skill-contracts.sh` near the related skill sections:

```bash
assert_contains "skills/spec/SKILL.md" "写入 `关联 DR` 表格时，应使用 Markdown 链接格式"
assert_contains "skills/spec/references/spec.md.tmpl" "| DR | tag | class | spec_change | 状态 | 关联小节 |"
assert_contains "skills/spec/references/spec.md.tmpl" "| --- | --- | --- | --- | --- | --- |"
assert_contains "skills/spec/SKILL.md" "[<dr-id>](../decisions/<dr-id>.md)"
assert_contains "skills/plan/SKILL.md" "写入 `关联 DR` 时，使用 Markdown 链接格式"
assert_contains "skills/plan/references/plan.md.tmpl" "- 关联 DR：null"
assert_contains "skills/plan/SKILL.md" "[<dr-id>](../decisions/<dr-id>.md)"
assert_contains "skills/dr/SKILL.md" "影响资产"
assert_contains "skills/dr/SKILL.md" "使用 Markdown 链接格式"
assert_contains "skills/dr/SKILL.md" "[spec.md](../specs/spec.md)"
assert_contains "skills/dr/SKILL.md" "[<plan-file>.md](../plans/<plan-file>.md)"
assert_contains "skills/dr/SKILL.md" "[<dr-id>](./<dr-id>.md)"
assert_contains "skills/dr/references/dr.md.tmpl" "| 资产 | 章节 / ID |"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL on at least one Markdown-link assertion because the templates still use older plain text forms.

- [ ] **Step 3: Update `skills/spec/references/spec.md.tmpl`**

Replace the `## 9. 关联 DRs` table with an empty link-oriented table. Do not add fake placeholder DR rows to the template:

```markdown
## 9. 关联 DRs
| DR | tag | class | spec_change | 状态 | 关联小节 |
| --- | --- | --- | --- | --- | --- |
```

- [ ] **Step 4: Update `skills/plan/references/plan.md.tmpl`**

Replace the existing `关联 DR` metadata line with the neutral default:

```markdown
- 关联 DR：null
```

When a plan is generated from a DR, `skills/plan/SKILL.md` must require replacing `null` with a Markdown link such as `[<dr-id>](../decisions/<dr-id>.md)`.

- [ ] **Step 5: Keep `skills/dr/references/dr.md.tmpl` free of fake asset rows**

Do not add example `spec`, `plan`, or `decision` rows to `skills/dr/references/dr.md.tmpl`. Keep the current empty table shape so each new DR records only real affected assets:

```markdown
## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |
```

The Markdown-link examples belong in `skills/dr/SKILL.md`, not in every generated DR file.

- [ ] **Step 6: Update skill instructions**

Add this sentence to `skills/spec/SKILL.md` in the code-class and document-class DR association rules:

```markdown
写入 `关联 DR` 表格时，应使用 Markdown 链接格式，例如 `[<dr-id>](../decisions/<dr-id>.md)`；章节号和标题可以放在链接后作为普通文本。
```

Add this sentence to `skills/plan/SKILL.md` under `## Plan content`:

```markdown
写入 `关联 DR` 时，使用 Markdown 链接格式，例如 `[<dr-id>](../decisions/<dr-id>.md)`；不要强制使用 Markdown anchor 链接到具体章节。
```

Add this sentence to `skills/dr/SKILL.md` under create mode steps:

```markdown
写入 `影响资产` 或引用 spec、plan、decision 时，使用 Markdown 链接格式，例如 `[spec.md](../specs/spec.md)`、`[<plan-file>.md](../plans/<plan-file>.md)`、`[<dr-id>](./<dr-id>.md)`；章节号和标题可以作为普通文本放在链接后。
```

- [ ] **Step 7: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for Markdown-link assertions.

- [ ] **Step 8: Commit**

```bash
git add skills/spec/SKILL.md skills/spec/references/spec.md.tmpl skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/dr/SKILL.md skills/dr/references/dr.md.tmpl tests/test-skill-contracts.sh
git commit -m "docs: require markdown links across SDD documents"
```

---

### Task 3: Add Lightweight Fix DR Flow

**Files:**
- Modify: `skills/dr/SKILL.md`
- Modify: `skills/code/SKILL.md`
- Modify: `skills/spec/SKILL.md`
- Modify: `CONSTITUTION.default.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: accepted `fix` DR with `class: code`, `spec_change: no`, `plan_required: no`, `code_required: yes`.
- Produces: `/sdd:code <dr-id>` lightweight execution mode that closes the DR after implementation and verification, without generating or completing a plan.

- [ ] **Step 1: Write failing lightweight fix assertions**

Add these assertions to `tests/test-skill-contracts.sh`:

```bash
assert_contains "skills/dr/SKILL.md" "简单实现 bug 可以由用户选择轻量 fix 流程"
assert_contains "skills/dr/SKILL.md" 'plan_required: no`：运行 `/sdd:code <id>`'
assert_contains "skills/code/SKILL.md" "description: Execute an SDD implementation plan or eligible lightweight fix DR"
assert_contains "skills/code/SKILL.md" "If input matches a code-class DR id"
assert_contains "skills/code/SKILL.md" "plan_required: no"
assert_contains "skills/code/SKILL.md" "lightweight fix DR"
assert_contains "skills/code/SKILL.md" "no plan status is changed"
assert_contains "skills/code/SKILL.md" "DR remains accepted"
assert_contains "skills/spec/SKILL.md" "closed_reason: document-updated"
assert_contains "CONSTITUTION.default.md" "代码类 DR 默认使用 `plan_required: yes`"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL on lightweight fix assertions.

- [ ] **Step 3: Update `/sdd:dr` guidance**

In `skills/dr/SKILL.md`, add this paragraph after the tag defaults table:

```markdown
简单实现 bug 可以由用户选择轻量 fix 流程：`tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不使用轻量 fix，应保持 `plan_required: yes` 并生成新的增量 Implementation Plan。
```

In accept mode next-step guidance, replace the two code-class lines with these three lines:

```markdown
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 决定 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
```

Keep the existing `spec_change: maybe` and `class: document` guidance.

- [ ] **Step 4: Update `/sdd:code` scope, lookup, and preconditions**

In the frontmatter of `skills/code/SKILL.md`, replace the description with:

```markdown
description: Execute an SDD implementation plan or eligible lightweight fix DR. Use for /sdd:code.
```

Update the opening summary so it says:

```markdown
Execute an existing Implementation Plan, or execute an accepted lightweight fix DR when `plan_required: no` and `code_required: yes`.
```

In `skills/code/SKILL.md`, replace `## Plan lookup` with:

```markdown
## Work item lookup

1. If input is `NNN`, match `docs/vX.Y.Z/plans/NNN-*.md` and use plan execution mode.
2. If input is a complete plan basename, match the same `.md` basename and use plan execution mode.
3. If input is feature name, match by plan suffix and use plan execution mode.
4. If input matches a code-class DR id `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, first check for a matching plan by suffix. If no plan matches, read `docs/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when `plan_required: no`.
5. If zero plans match and no eligible lightweight fix DR matches, stop and ask the user to run `/sdd:plan <work-item>` or confirm a lightweight fix DR.
6. If multiple plans match, stop and ask the user to use plan number, for example `/sdd:code 002`.
```

Then add this section before `## Execution mode`:

```markdown
## Lightweight fix DR mode

This mode is only for simple implementation bugs that conform to the existing spec and do not require an Implementation Plan.

Preconditions:

```text
DR 状态为 accepted
DR `class` is `code`
DR `tag` is `fix`
DR `spec_change: no`
DR `plan_required: no`
DR `code_required: yes`
```

Steps:

1. Execute the local code fix with the chosen Superpowers sub-skill.
2. Run `superpowers:verification-before-completion`.
3. When execution succeeds and verification passes, change the DR from `accepted` to `closed`.
4. Set DR `closed_reason: committed`.
5. Set DR `closed_at` to current UTC timestamp.
6. Because no plan exists in lightweight fix DR mode, no plan status is changed.

Failure behavior:

```text
DR remains accepted
no plan status is changed
```
```

- [ ] **Step 5: Update constitution default**

Replace this line in `CONSTITUTION.default.md`:

```markdown
- must: 代码类 DR 必须使用 `plan_required: yes` 和 `code_required: yes`。
```

with:

```markdown
- must: 代码类 DR 必须使用 `code_required: yes`；代码类 DR 默认使用 `plan_required: yes`，但简单实现 bug 的轻量 fix DR 可以使用 `plan_required: no`。
```

Add this line after it:

```markdown
- must: 轻量 fix DR 必须是 `fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`，并只能在 `/sdd:code` verification 通过后关闭。
```

- [ ] **Step 6: Update document-class DR closing reason in `/sdd:spec`**

In `skills/spec/SKILL.md`, replace the document-class DR closing sentence so document-only revisions do not use the code-oriented committed reason:

```markdown
If associated document-class DRs were completed by this revision, change each associated DR from `accepted` to `closed`, set `closed_reason: document-updated`, and set `closed_at` to current UTC timestamp. document-class DRs may close after document revision, and document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`.
```

- [ ] **Step 7: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for lightweight fix assertions.

- [ ] **Step 8: Commit**

```bash
git add skills/dr/SKILL.md skills/code/SKILL.md skills/spec/SKILL.md CONSTITUTION.default.md tests/test-skill-contracts.sh
git commit -m "feat: support lightweight fix DR flow"
```

---

### Task 4: Clarify Incremental Skill Boundaries and Triage Interop

**Files:**
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/code/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: existing skill contracts for spec, plan, and code.
- Produces: explicit text that DR Advanced additions are incremental and that triage recommendations connect to downstream skills only after user confirmation.

- [ ] **Step 1: Write failing boundary assertions**

Add these assertions to `tests/test-skill-contracts.sh`:

```bash
assert_contains "skills/spec/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/plan/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/code/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/spec/SKILL.md" "如果来自 `/sdd:triage` 的用户选择"
assert_contains "skills/plan/SKILL.md" "如果来自 `/sdd:triage` 的用户选择"
assert_contains "skills/code/SKILL.md" "如果来自 `/sdd:triage` 的用户选择"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL on boundary assertions.

- [ ] **Step 3: Add boundary note to `/sdd:spec`**

Add this section after `## Preconditions` in `skills/spec/SKILL.md`:

```markdown
## DR Advanced 增量约束

This skill keeps its existing responsibility: create or revise `docs/vX.Y.Z/specs/spec.md`. DR Advanced only adds association rules for accepted document-class DRs and spec-changing code-class DRs.

如果来自 `/sdd:triage` 的用户选择指向 spec revision, follow the same preconditions and do not modify plan or code in this skill.
```

- [ ] **Step 4: Add boundary note to `/sdd:plan`**

Add this section after `## Preconditions` in `skills/plan/SKILL.md`:

```markdown
## DR Advanced 增量约束

This skill keeps its existing responsibility: generate an Implementation Plan. DR Advanced only adds code-class DR mode constraints, document-class DR rejection, `plan_required: yes`, and Markdown link requirements.

如果来自 `/sdd:triage` 的用户选择指向 plan revision, generate a new incremental plan for the accepted code-class DR; do not reopen a closed DR and do not rewrite a completed plan.
```

- [ ] **Step 5: Add boundary note to `/sdd:code`**

Add this section after `## Preconditions` in `skills/code/SKILL.md`:

```markdown
## DR Advanced 增量约束

This skill keeps its existing responsibility: execute a planned/coding plan or an eligible lightweight fix DR. DR Advanced only adds DR-aware closing rules, lightweight fix DR mode, and verification-gated state transitions.

如果来自 `/sdd:triage` 的用户选择指向 code execution, require either a planned/coding plan or an accepted lightweight fix DR. Do not revise spec or plan in this skill.
```

- [ ] **Step 6: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for incremental-boundary assertions.

- [ ] **Step 7: Commit**

```bash
git add skills/spec/SKILL.md skills/plan/SKILL.md skills/code/SKILL.md tests/test-skill-contracts.sh
git commit -m "docs: clarify DR advanced skill boundaries"
```

---

### Task 5: Update README User-Facing Workflow

**Files:**
- Modify: `README.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: final skill behavior from Tasks 1-4.
- Produces: README documentation for `/sdd:triage`, lightweight fix, and Markdown links.

- [ ] **Step 1: Write failing README assertions**

Add these assertions near the existing README assertions in `tests/test-skill-contracts.sh`:

```bash
assert_contains "README.md" "/sdd:triage"
assert_contains "README.md" "用户疑问分诊"
assert_contains "README.md" "轻量 fix DR"
assert_contains "README.md" "Markdown 链接"
assert_contains "README.md" "最终由用户选择"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL because README does not yet document triage and lightweight fix flow.

- [ ] **Step 3: Update README feature overview**

Add this bullet to `## 功能概览`:

```markdown
- 对实现后、验收中或测试中的用户疑问执行 `/sdd:triage` 分诊，只推荐后续路径，最终由用户选择
```

- [ ] **Step 4: Update README change flow**

After the existing sentence `只修代码且不改契约时，fix DR 通常使用...`, add:

```markdown
对于简单实现 bug，可以使用轻量 fix DR：`fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。轻量 fix 不生成 Implementation Plan，但仍必须通过 `/sdd:code <id>` 执行并完成 verification 后才能关闭 DR。

用户在实现后、验收中或测试中提出疑问时，应先运行 `/sdd:triage` 判断问题更可能属于 code、plan、spec、新需求或仅解释。`/sdd:triage` 只输出分类、置信度、已读取依据、原因、推荐路径和可选路径，不创建 DR、不修改 spec、不修改 plan、不修改 code。

spec、plan、DR 之间的引用应使用 Markdown 链接，例如 `[feat-0001-example](../decisions/feat-0001-example.md)`。章节号和标题可以作为普通文本放在链接后，不强制使用 Markdown anchor。
```

- [ ] **Step 5: Add triage command row**

Add this row to the command table:

```markdown
| `/sdd:triage [--deep]` | 对用户疑问进行分诊，推荐后续路径并等待用户选择 |
```

- [ ] **Step 6: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for README assertions.

- [ ] **Step 7: Commit**

```bash
git add README.md tests/test-skill-contracts.sh
git commit -m "docs: document DR triage workflow"
```

---

### Task 6: Final Contract Review and Spec Coverage

**Files:**
- Modify: `tests/test-skill-contracts.sh`
- Modify: only files from earlier tasks if a coverage gap is found.

**Interfaces:**
- Consumes: all modified skill files, templates, README, and constitution defaults.
- Produces: passing contract test suite and final coverage against `docs/superpowers/specs/2026-07-13-dr-advanced-spec.md`.

- [ ] **Step 1: Add final acceptance assertions**

Add these assertions to `tests/test-skill-contracts.sh` if not already present from previous tasks:

```bash
assert_contains "skills/code/SKILL.md" "verification passes"
assert_contains "skills/code/SKILL.md" "closed_reason: committed"
assert_contains "skills/spec/SKILL.md" "code-class DR 必须保持 `accepted`"
assert_contains "skills/plan/SKILL.md" "DR `plan_required: yes`"
assert_contains "skills/spec/SKILL.md" "closed_reason: document-updated"
assert_contains "skills/triage/SKILL.md" "explain only -> no DR"
assert_contains "skills/triage/SKILL.md" "fix DR -> code -> verification"
assert_contains "skills/triage/SKILL.md" "fix DR -> plan -> code -> verification"
assert_contains "skills/triage/SKILL.md" "new feat/chg DR -> spec -> plan -> code -> verification"
```

- [ ] **Step 2: Run full contract suite**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected:

```text
PASS: skill contracts
```

- [ ] **Step 3: Search for stale standalone triage references**

Run:

```bash
rg "2026-07-13-dr-advanced-spec|dr-advanced-spec" docs skills README.md CONSTITUTION.default.md tests
```

Expected: no output.

- [ ] **Step 4: Search for unresolved placeholders in changed files**

Run:

```bash
rg "TBD|TODO|待定|待补充" skills/triage/SKILL.md skills/dr/SKILL.md skills/dr/references/dr.md.tmpl skills/spec/SKILL.md skills/spec/references/spec.md.tmpl skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/code/SKILL.md README.md CONSTITUTION.default.md tests/test-skill-contracts.sh
```

Expected: no output.

- [ ] **Step 5: Review git diff for scope**

Run:

```bash
git diff -- skills/triage/SKILL.md skills/dr/SKILL.md skills/dr/references/dr.md.tmpl skills/spec/SKILL.md skills/spec/references/spec.md.tmpl skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/code/SKILL.md README.md CONSTITUTION.default.md tests/test-skill-contracts.sh
```

Confirm the diff only covers DR Advanced behavior, `/sdd:triage`, lightweight fix, Markdown links, README/constitution contracts, and tests.

- [ ] **Step 6: Commit final coverage adjustments**

If Step 1 changed tests or Step 5 required small corrections, commit them:

```bash
git add skills/triage/SKILL.md skills/dr/SKILL.md skills/dr/references/dr.md.tmpl skills/spec/SKILL.md skills/spec/references/spec.md.tmpl skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/code/SKILL.md README.md CONSTITUTION.default.md tests/test-skill-contracts.sh
git commit -m "test: cover DR advanced contracts"
```

If there are no changes after Step 5, do not create an empty commit.

---

## Self-Review

**Spec coverage:**
- DR classification model and fields are already mostly present in current repo; this plan keeps them and adds missing contract coverage where needed.
- Standard flows are covered by `/sdd:dr`, `/sdd:spec`, `/sdd:plan`, `/sdd:code`, and lightweight fix updates.
- Cross-document Markdown links are covered in Task 2.
- `/sdd:triage` behavior, token control, output format, classification, and path recommendations are covered in Task 1.
- Incremental skill boundaries are covered in Task 4.
- README and constitution updates are covered in Task 5.
- Contract test coverage is covered in every task and finalized in Task 6.

**Placeholder scan:** The plan uses literal placeholder syntax such as `<dr-id>` only where the target plugin templates and Skill docs need to display that syntax to users. There are no unresolved implementation placeholders.

**Type and naming consistency:** The plan consistently uses `class`, `spec_change`, `plan_required`, `code_required`, `closed_reason`, `closed_at`, `/sdd:triage`, `/sdd:dr`, `/sdd:spec`, `/sdd:plan`, and `/sdd:code` with the same spelling as the spec.
