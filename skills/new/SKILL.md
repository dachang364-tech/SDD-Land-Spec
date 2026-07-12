---
name: new
description: Create the unique active SDD version directory. Use for /sdd:new vX.Y.Z.
---

# /sdd:new

Create a single active version directory.

## Required argument

Version must match:

```text
^v[0-9]+\.[0-9]+\.[0-9]+$
```

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Scan `docs/v*/` excluding `docs/archive/**`.
3. If any active version directory exists, stop and say: `已有未归档版本目录；MVP 不支持多活跃版本，请先运行 /sdd:archive。`

## Steps

Create:

```text
docs/vX.Y.Z/specs/
docs/vX.Y.Z/plans/
docs/vX.Y.Z/decisions/
```

Do not create:

```text
docs/vX.Y.Z/prd.md
docs/vX.Y.Z/specs/spec.md
docs/vX.Y.Z/plans/*.md
.sdd/state.json
```
