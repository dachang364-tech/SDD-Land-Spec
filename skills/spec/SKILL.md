---
name: spec
description: Create or revise the functional specification. Use for /sdd:spec.
---

# /sdd:spec

Create or revise a functional spec at `docs/versions/vX.Y.Z/specs/<spec-name>.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Require `docs/versions/vX.Y.Z/prd.md` to exist; if missing, stop and ask the user to run `/sdd:prd`.
7. Default target may be `specs/spec.md`; a version may hold multiple `specs/<spec-name>.md`.
8. If the target spec already exists, ask whether to overwrite, update, or cancel.

## Dialogue

1. Read the active version `prd.md`.
2. Confirm the target spec filename.
3. Clarify functional boundary, constraints, user stories, business rules, input/output, exception/edge cases, acceptance criteria, non-goals.
4. List associable accepted document-class DRs (`spec`, `doc`, `typo`).
5. List associable accepted code-class DRs (`spec_change: yes`, or `spec_change: maybe` needing a spec update).
6. Ask whether to associate one or more DRs.

## 文档引用

Write formal relationships into the unified `## 文档引用` table:

- 引用当前版本 PRD：`[prd.md](../prd.md)`，关系通常为 `derives_from`。
- 引用当前版本 DR：`[<dr-id>](../decisions/<dr-id>.md)`。
- 引用同版本其他 spec：`[<spec-name>.md](./<spec-name>.md)`。
- 引用旧版本 spec/PRD/plan/DR：必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:specs/archive.md`。
- 引用 project-level requirements：必须同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
- `## 文档引用` 是 spec 的正式引用关系来源。
- 不再使用独立 `## 关联 DRs` 作为权威关系表；如需 DR 汇总只能作为辅助阅读信息，且不得与 `## 文档引用` 冲突。

## Steps

1. Read `prd.md`.
2. 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 下的模板与标准。
3. 读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/template.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/quality.standard.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/feasibility.standard.md`。
4. 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
5. reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 中的模板与标准，与生成阶段使用同一套项目级有效资产。
6. Write `docs/versions/vX.Y.Z/specs/<spec-name>.md` with `- 状态：draft`.
7. 目标文档写入完成并通过命令层 pre-review gate 后，必须按 `/sdd:review` 的 `doc-reviewer` agent JSON 调用合同自动按顺序触发 `quality -> feasibility`；每个 mode 的机器结果均须先通过 schema 校验。
8. `quality` JSON 无效、admission check 失败、`blocked: true` 或 `requires_user_confirmation: true` 时，停止，不执行 `feasibility`，聚合已执行结果为一份回执，并保留 `draft`。
9. 只有 `quality` 的有效结果未阻断且无需确认时才执行 `feasibility`。`feasibility` 默认弱阻断：未阻断的风险只进入聚合回执；若它返回 `blocked: true`、需要确认或无效 JSON，则保留 `draft`。
10. 仅在所有应执行 reviewer 结果有效、未阻断且无需用户确认后，才 Ask the user to approve or request changes。
11. 用户确认审批后，将状态切换为 `approved`；reviewer 的候选改写或确认项必须先由用户明确确认、写回并重新复审，普通审批不得绕过。

## DR status handling

- 关联 document-class DR 且本次修订完成该 DR：用户确认 spec 后可关闭该 DR，设置 `closed_reason: document-updated` 并写入 `closed_at`；document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`。
- 关联 code-class DR：spec approved 后该 code-class DR 必须保持 `accepted`，不得因 spec 修订完成而关闭。
- code-class DR 下一步按 `plan_required` 输出：`plan_required: yes` → `/sdd:plan <dr-id>`；`plan_required: no` → `/sdd:code <dr-id>`。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 plan、不修改 code、不归档版本、不读取 git log。
- 如果 spec 引用 plan，按引用检查规则作为 warning 级例外，并在 `说明` 中解释原因。

## Failure behavior

If the user does not approve, keep the spec at `draft`.
