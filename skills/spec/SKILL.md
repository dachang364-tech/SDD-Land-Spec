---
name: spec
description: Create or revise the functional specification. Use for /sdd:spec.
---

# /sdd:spec

Create or revise `docs/vX.Y.Z/specs/spec.md` from PRD and optional accepted document-class DRs.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Require `docs/vX.Y.Z/prd.md` to exist.
4. If `prd.md` is missing, stop and say: `prd.md 不存在，请先运行 /sdd:prd。`

## Dialogue

Clarify:

1. 功能边界
2. 用户故事
3. 业务规则
4. 输入输出
5. 异常 / 边界场景
6. 验收标准
7. 非目标

If accepted document-class DRs exist with tag `spec`, `doc`, or `typo`, list them and ask whether to associate one or more with this spec revision.
If accepted code-class DRs exist with `spec_change: yes`, or with `spec_change: maybe` and the current revision needs a spec update, list them and ask whether to associate one or more with this spec revision.

## Steps

1. Read `prd.md`.
2. Use Spec-Kit structure for functional specification writing.
3. Write `docs/vX.Y.Z/specs/spec.md` with `- 状态：draft`.
4. Ask the user to approve or request changes.
5. 用户确认后，将状态切换为 `approved`.
6. If associated document-class DRs were committed by this revision, change each associated DR from `accepted` to `closed`, set `closed_reason: committed`, and set `closed_at` to current UTC timestamp. document-class DRs may close after document revision, and document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`.
7. If an associated code-class DR is revised through `/sdd:spec`, that code-class DR 保持 `accepted`; do not close it after spec approval, and output 下一步 `/sdd:plan <id>`.

## Failure behavior

If the user does not approve, keep `spec.md` at `draft`.
