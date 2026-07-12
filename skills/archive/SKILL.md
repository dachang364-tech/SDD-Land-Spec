---
name: archive
description: Archive the current active SDD version. Use for /sdd:archive.
---

# /sdd:archive

Archive the current active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. There is exactly one active version.
3. `prd.md` exists.
4. `spec.md` status is `approved`.
5. 所有 `plans/*.md` 状态为 `done`.
6. No DR status is `drafting`.
7. No DR status is `accepted`.

## Steps

Move:

```text
docs/vX.Y.Z/ → docs/archive/vX.Y.Z/
```

If inside a git repository, prefer:

```bash
git mv docs/vX.Y.Z docs/archive/vX.Y.Z
```

Otherwise use:

```bash
mv docs/vX.Y.Z docs/archive/vX.Y.Z
```

Do not move:

```text
docs/requirements/
docs/CONSTITUTION.md
```

Do not modify archived document states.
