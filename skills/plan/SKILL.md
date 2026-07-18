---
name: plan
description: Create an implementation plan from approved spec or accepted code-class DR. Use for /sdd:plan <work-item>.
---

# /sdd:plan

Generate a new incremental Implementation Plan under `docs/versions/vX.Y.Z/plans/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Parse `<work-item>` by syntax, not by semantic guessing.

## Mode detection

1. If `<work-item>` matches `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$`, use code-class DR mode.
2. If `<work-item>` matches `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. If `<work-item>` is DR-like (starts with three digits and a hyphen) but is not a valid full DR ID in the `001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>` form, fail explicitly: `无效 DR ID。` Do not fall through to spec mode.
4. Otherwise use spec mode.

## Plan number allocation

1. Inspect `docs/versions/vX.Y.Z/plans/[0-9][0-9][0-9]-*.md`.
2. Extract numeric prefixes.
3. Use the next zero-padded 3-digit number after the current maximum; if no plan exists, use `001`.
4. Do not ask the user to choose `NNN`, and do not reuse an existing number.

## Spec mode

- `<work-item>` may be a spec filename, `specs/<spec-name>.md`, or a feature name resolving uniquely to one approved spec.
- Require the target spec to be `approved`; if no approved spec, stop and ask the user to run `/sdd:spec` and approve.
- Output path: `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`.

## Code-class DR mode

- Read `docs/versions/vX.Y.Z/decisions/<dr-id>.md`.
- Require `状态：accepted`, `class: code`, `plan_required: yes`, `code_required: yes`.
- If `plan_required: no`, refuse and tell the user to run `/sdd:code <dr-id>`.
- Output path: `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md`.

## Technical Planning Dialogue

1. Read the relevant approved spec.
2. Read the DR when in code-class DR mode.
3. Explore current code structure.
4. Identify affected modules and file areas.
5. Present 2-3 approaches.
6. Recommend one with tradeoffs.
7. Confirm architecture boundaries, data/control flow, file impact, testing strategy, risks, constraints.
8. If concrete files, test commands, implementation steps, or acceptance mapping cannot be written, continue the dialogue; do not emit a placeholder plan.
9. Only after user confirmation, generate the plan.

## Plan quality rules

- Use `skills/plan/references/plan.md.tmpl`.
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
- 引用跨版本文档时，必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:plans/001-archive.md`。
- plan 不得使用 `modifies`、`replaces`、`deprecates`。
- 如果发现需要改变功能契约，停止当前 plan 生成流程，先创建或修订 DR / spec。

## Status flow

- Initial `- 状态：draft`.
- After user approval, `- 状态：planned`.
- 不把任何 DR 改为 closed；不改变 code-class DR 状态（保持 accepted）。

## Boundaries

- 不创建 active version、不修改 state.json、不修改 spec、不修改 DR 状态、不修改 code、不归档版本、不重开 closed DR、不改写 done plan。
