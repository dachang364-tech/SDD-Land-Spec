---
name: status
description: Show current SDD version status and next-step guidance. Use for /sdd:status.
---

# /sdd:status

展示当前版本状态与下一步建议。

## Steps

1. Read `docs/CONSTITUTION.md`; if missing, report that the project is not initialized and suggest `/sdd:init`.
2. Resolve the unique active version directory.
3. Check whether `prd.md` exists.
4. Check `specs/spec.md` status when present.
5. Scan `plans/*.md` and list each plan status.
6. Scan `decisions/*.md` and list `drafting` DRs.
7. Scan `decisions/*.md` and list `accepted` DRs.
8. Print next-step guidance.

## Output shape

```text
当前活跃版本：v0.1.0

PRD：存在
SPEC：approved

Plans：
- 001-feature-login：done

DRs：
- drafting：arch-0002-split-auth
- accepted：fix-0001-null-login

下一步建议：
- /sdd:code 002
```

Do not inspect git log.
Do not diagnose source-code consistency.
