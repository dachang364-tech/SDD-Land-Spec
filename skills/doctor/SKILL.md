---
name: doctor
description: Diagnose SDD plugin installation and project consistency. Use for /sdd:doctor.
---

# /sdd:doctor

Read-only diagnostic for plugin installation integrity, project structure, version lifecycle, base document status, and reference structure. Does not auto-fix.

## Startup constraint

At execution start, read `docs/CONSTITUTION.md`.
If `docs/CONSTITUTION.md` is missing, report the SDD project is not initialized and suggest running `/sdd:init`. This does not replace the project structure check below.

## 1. Plugin installation checks

Check existence of:

```text
.claude-plugin/plugin.json
skills/init/SKILL.md
skills/new/SKILL.md
skills/research/SKILL.md
skills/prd/SKILL.md
skills/spec/SKILL.md
skills/plan/SKILL.md
skills/code/SKILL.md
skills/dr/SKILL.md
skills/triage/SKILL.md
skills/status/SKILL.md
skills/doctor/SKILL.md
skills/archive/SKILL.md
hooks/hooks.json
scripts/install-deps.sh
scripts/hooks/pre-tool-use.sh
scripts/lib/sdd-common.sh
CONSTITUTION.default.md
```

Check dependency reachability:

```text
superpowers
spec-kit
```

## 2. Project structure checks

- `docs/CONSTITUTION.md`
- `docs/requirements/`
- `docs/versions/`
- `docs/archive/`
- If `docs/CONSTITUTION.md` is missing, report not initialized and suggest `/sdd:init`, but still list other missing items.

## 3. Old draft structure check

- Scan `docs/vX.Y.Z/`.
- If found, report as 旧草案结构 (warning only), not part of the current model; do not auto-migrate; does not block `/sdd:new`.

## 4. Version state checks

- Scan `docs/versions/v*/`.
- Each version directory must have `state.json`, parseable as JSON.
- state.json.version 必须等于版本目录名。
- `state` only `active` or `archived`.
- `created_at` must exist; `archived_at` must be `null` when active and non-empty when archived.
- 0 active version legal (report and suggest `/sdd:new vX.Y.Z`); 1 active legal; multiple active is a consistency error.

## 5. Active version documents (only when exactly 1 active version)

- Check `specs/*.md`, `plans/*.md`, `decisions/*.md` status lines exist, parse, and are legal.
- DR status only `drafting`, `accepted`, `closed`; `closed` DR should have `closed_reason`; `superseded_by` non-empty if present.

## 6. Plan / DR consistency

- accepted code-class DR with `plan_required: yes` should have a matching plan (plan filename minus `NNN-` equals DR slug).
- accepted lightweight fix DR (`tag: fix`, `class: code`, `spec_change: no`, `plan_required: no`, `code_required: yes`) needs no plan; suggest `/sdd:code <dr-id>`.
- done code-class DR whose DR is still `accepted`: report as a close reminder.

## 7. Archive index checks

- Check `docs/archive/INDEX.md` existence.
- For each `state: archived` version, the version directory should have `ARCHIVE.md`.
- `docs/archive/INDEX.md` has at most one row per archived version, linking to `../versions/vX.Y.Z/ARCHIVE.md`.
- `INDEX.md` must not link to concrete spec/plan/DR/requirements.

## 8. Reference tables (lightweight)

- For existing PRD, spec, plan, DR in the active version:
  - Check the `## 文档引用` table exists.
  - Check the 5-column header `关系`, `当前范围`, `目标文档`, `目标标识`, `说明`.
  - Check relation values are in the enum.
  - Check cross-version references have version locators; project-level requirements references have `project:` locators.

## Output rules

- Group output by check range; each group reports `OK`, `WARNING`, or `ERROR`.
- Final next-step suggestions per state (not initialized → `/sdd:init`; 0 active → `/sdd:new vX.Y.Z`; multiple active/broken state → manual `state.json` fix; archive index issue → fix `docs/archive/INDEX.md`; reference table issue → fix reference tables).

## Boundaries

- 不自动创建或修改文件、不修复 state.json、不创建 active version、不归档版本、不生成 ARCHIVE.md、不更新 INDEX.md、不读取 git log、不审计源码、不机器解析 CONSTITUTION must/should、不做正文链接语义启发式扫描。
