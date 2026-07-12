---
name: research
description: Create project-level SDD research notes. Use for /sdd:research <topic>.
---

# /sdd:research

Create project-level research material under `docs/requirements/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Ensure `docs/requirements/` exists.

## Dialogue

Ask the user for:

1. Research topic.
2. Why this topic matters.
3. Sources or local files to inspect.
4. Desired decision output for later PRD use.

## Output path

Write:

```text
docs/requirements/<topic-slug>-<yyyy-mm>.md
```

The document has no `- 状态：` line.
