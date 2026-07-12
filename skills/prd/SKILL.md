---
name: prd
description: Create the product requirements document. Use for /sdd:prd.
---

# /sdd:prd

Create `docs/vX.Y.Z/prd.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory under `docs/v*/`.
3. If there is no active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
4. If there are multiple active versions, stop and ask the user to archive old versions.

## Dialogue

1. Scan `docs/requirements/*.md`.
2. Ask the user which requirement documents to reference.
3. Clarify product background, target users, pain points, business goals, scope in/out, success criteria, risks, and assumptions.

## Output

Write `docs/vX.Y.Z/prd.md` using `skills/prd/references/prd.md.tmpl`.

Do not include a `- 状态：` line.
