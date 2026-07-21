---
name: new
description: Create the unique active SDD version directory. Use for /sdd:new vX.Y.Z.
---

# /sdd:new

Create a single active version directory under `docs/versions/`.

## Required argument

Version must match:

```text
^v[0-9]+\.[0-9]+\.[0-9]+$
```

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and say the structure is incomplete, run `/sdd:init`.
3. Target directory `docs/versions/vX.Y.Z/` must not already exist.
4. 扫描 docs/versions/v*/state.json。
5. If one `state: active` version exists, stop and ask the user to run `/sdd:archive` first.
6. If multiple `state: active` versions exist, stop and report the project state is inconsistent.
7. If any version directory is missing `state.json`, has unparseable JSON, has a `version` mismatch, or an illegal `state`, stop and report the project state is inconsistent.
8. If 0 active version and no consistency error, allow creation.

## Steps

Create:

```text
docs/versions/vX.Y.Z/
docs/versions/vX.Y.Z/state.json
docs/versions/vX.Y.Z/research/
docs/versions/vX.Y.Z/prd/
docs/versions/vX.Y.Z/spec/
docs/versions/vX.Y.Z/plan/
docs/versions/vX.Y.Z/dr/
```

这些目录都创建为空目录。

Initial `docs/versions/vX.Y.Z/state.json` content:

```json
{
  "version": "vX.Y.Z",
  "state": "active",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "archived_at": null
}
```

Do not create:

```text
docs/versions/vX.Y.Z/prd/prd.md
docs/versions/vX.Y.Z/research/*.md
docs/versions/vX.Y.Z/spec/*.md
docs/versions/vX.Y.Z/plan/*.md
docs/versions/vX.Y.Z/dr/*.md
.sdd/state.json
```

## State semantics

- `/sdd:new` 只通过 docs/versions/v*/state.json 判断 active version，不通过目录数量判断。
- `/sdd:new` 是从 0 active version 进入 1 active version 的唯一主流程入口。
- `/sdd:new` 不修改任何已存在版本的 state.json。
- `/sdd:new` 不更新 `docs/archive/INDEX.md`。
