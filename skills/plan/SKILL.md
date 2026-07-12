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

## Mode detection

1. If `<work-item>` matches `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. Otherwise use feature mode.

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
```

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

Initial status:

```markdown
- 状态：draft
```

After user approval, change status to:

```markdown
- 状态：planned
```
