---
name: plan
description: Create an implementation plan from approved spec or accepted code-class DR. Use for /sdd:plan <work-item>.
---

# /sdd:plan

Generate an Implementation Plan under `docs/vX.Y.Z/plans/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Parse `<work-item>` by syntax, not by semantic guessing.

## DR Advanced 增量约束

This skill keeps its existing responsibility: generate an Implementation Plan. DR Advanced only adds code-class DR mode constraints, document-class DR rejection, `plan_required: yes`, and Markdown link requirements.

如果来自 `/sdd:triage` 的用户选择指向 plan revision, generate a new incremental plan for the accepted code-class DR; do not reopen a closed DR and do not rewrite a completed plan.

## Mode detection

1. If `<work-item>` matches `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. Otherwise use feature mode.

## Plan number allocation

Before choosing the output path, set `plans_dir` to `docs/vX.Y.Z/plans/` and allocate `NNN` by calling Task 2's `sdd_next_plan_number(plans_dir)` helper or an equivalent automatic rule:

1. Inspect existing files matching `docs/vX.Y.Z/plans/[0-9][0-9][0-9]-*.md`.
2. Extract the numeric prefixes as version-local plan numbers.
3. Use the next zero-padded 3-digit number after the current maximum; if no plan exists, use `001`.
4. Do not ask the user to choose `NNN`, and do not reuse an existing number.

## Feature mode

Precondition:

```text
docs/vX.Y.Z/specs/spec.md 状态为 approved
```

Normalize names:

```text
login         → feature-login
feature-login → feature-login
```

Output path:

```text
docs/vX.Y.Z/plans/NNN-feature-<name>.md
```

## Code-class DR mode

Precondition:

```text
docs/vX.Y.Z/decisions/<dr-id>.md 状态为 accepted
DR `class` is `code`
DR `plan_required: yes`
```

Refuse DR `plan_required: no`; use `/sdd:code <id>` for eligible lightweight fix DRs.

Output path:

```text
docs/vX.Y.Z/plans/NNN-<dr-id>.md
```

## Technical Planning Dialogue

Before writing Implementation Tasks:

1. Read spec.
2. Read DR when in code-class DR mode.
3. Explore current code structure.
4. Identify affected modules and file areas.
5. Present 2-3 implementation approaches.
6. Recommend one approach with tradeoffs.
7. Confirm architecture boundaries, data/control flow, file impact, testing strategy, risks, and constraints with the user.
8. Only after user confirmation, generate the plan.

## Plan content

Use `skills/plan/references/plan.md.tmpl`.
写入 `关联 DR` 时，使用 Markdown 链接格式，例如 `[<dr-id>](../decisions/<dr-id>.md)`；不要强制使用 Markdown anchor 链接到具体章节。

Initial status:

```markdown
- 状态：draft
```

After user approval, change status to:

```markdown
- 状态：planned
```
