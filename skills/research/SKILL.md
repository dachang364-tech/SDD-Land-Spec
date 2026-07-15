---
name: research
description: Create project-level SDD research notes. Use for /sdd:research <topic>.
---

# /sdd:research

Create or update project-level research material under `docs/requirements/`. Not part of any version and not part of the version lifecycle.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Ensure `docs/requirements/` exists; if `docs/CONSTITUTION.md` exists but `docs/requirements/` is missing, create only `docs/requirements/`.
3. 不扫描 docs/versions/v*/state.json。
4. 不要求 active version；0 active version 时仍可运行。

## Dialogue

1. Research topic.
2. Why the topic matters.
3. Sources or local files.
4. Decision output later needed by PRD or spec.
5. If the user names a target PRD or spec, record it as a suggested later reference but do not modify the target document.

## Output path

```text
docs/requirements/<topic-slug>-<yyyy-mm>.md
```

Write using `skills/research/references/research.md.tmpl`.

- research 文档不写 `- 状态：` 行，不写 version lifecycle 字段，不要求 `## 文档引用` 表。
- 如果同名 research 文件已存在，更新同一文档或要求用户确认新 slug；不得创建 version-local 副本。

## Relationship with PRD / spec

- 不自动修改 PRD 或 spec。
- 当 PRD 或 spec 正式引用该 research 时，目标文档在 `## 文档引用` 表用相对 Markdown link、`project:requirements/<file>.md` locator 和 `derives_from` 或 `references` 关系记录。

## Boundaries

- 不创建 active version、不读取或修改 state.json、不创建或修改 PRD/spec/plan/DR、不关闭 DR、不生成 plan、不执行 code、不归档版本。
