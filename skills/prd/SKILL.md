---
name: prd
description: Create the product requirements document. Use for /sdd:prd.
---

# /sdd:prd

Create or update `docs/versions/vX.Y.Z/prd.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or an inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Target file is `docs/versions/vX.Y.Z/prd.md`. If it already exists, ask whether to overwrite, update, or cancel.

## Dialogue

1. Scan `docs/requirements/*.md`.
2. Ask which requirement documents to reference.
3. For each selected requirement, write one formal row in the `## 文档引用` table:
   - `关系` usually `derives_from`.
   - `当前范围` the affected product goal, scope, or success criteria.
   - `目标文档` a relative Markdown link from `prd.md`, for example `[business-rules.md](../../requirements/business-rules.md)`.
   - `目标标识` `project:requirements/<file>.md`.
   - `说明` one sentence on how the requirement affects the PRD.
4. Clarify product background, target users, pain points, business goals, scope, success criteria, risks, assumptions.
5. If no requirement is selected, use the fixed empty-set row `| 未声明。 | - | - | - | - |`.

## Output

Write `docs/versions/vX.Y.Z/prd.md` using `skills/prd/references/prd.md.tmpl`.

- `## 文档引用` 是正式机器可检查引用关系。
- `## 上游需求资料` 是人类阅读摘要。
- 影响 PRD 契约内容的 requirement 必须同时出现在 `## 文档引用`。
- 不写 `- 状态：` 行。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 spec/plan/DR、不归档版本、不读取 git log。
