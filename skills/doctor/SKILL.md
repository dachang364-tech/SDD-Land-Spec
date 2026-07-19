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
skills/review/SKILL.md
skills/review/references/reviewer-result.schema.json
agents/doc-reviewer.md
hooks/hooks.json
scripts/install-deps.sh
scripts/hooks/pre-tool-use.sh
scripts/lib/sdd-common.sh
scripts/lib/sdd-references.sh
scripts/lib/sdd-template-assets.sh
assets/template-packs/default-backend/prd/template.md
assets/template-packs/default-backend/prd/quality.standard.md
assets/template-packs/default-backend/spec/template.md
assets/template-packs/default-backend/spec/quality.standard.md
assets/template-packs/default-backend/spec/feasibility.standard.md
assets/template-packs/default-backend/plan/template.md
assets/template-packs/default-backend/plan/quality.standard.md
assets/template-packs/default-backend/plan/feasibility.standard.md
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

- accepted code-class DR with `plan_required: yes` should have a matching plan.
- For a code-class DR plan, strip the leading `plan number` and hyphen from the plan basename.
- the remaining plan basename must equal the full `DR ID`.
- A DR-like plan basename with an invalid DR ID, a missing exact `decisions/<dr-id>.md`, or legacy `<tag>-NNNN-<slug>` form is an `ERROR`; do not use aliases or fuzzy lookup.
- accepted lightweight fix DR (`tag: fix`, `class: code`, `spec_change: no`, `plan_required: no`, `code_required: yes`) needs no plan; suggest `/sdd:code <dr-id>`.
- done code-class DR whose DR is still `accepted`: report as a close reminder.

## 7. Archive index checks

- Check `docs/archive/INDEX.md` existence.
- For each `state: archived` version, the version directory should have `ARCHIVE.md`.
- `docs/archive/INDEX.md` has at most one row per archived version, linking to `../versions/vX.Y.Z/ARCHIVE.md`.
- `INDEX.md` must not link to concrete spec/plan/DR/requirements.

## 8. Reference tables

Only when exactly 1 active version exists:

1. Load `scripts/lib/sdd-references.sh`.
2. Enumerate each existing `prd.md`, `specs/*.md`, `plans/*.md`, and `decisions/*.md` in that active-version directory.
3. For every enumerated source, call `sdd_refs_validate <project-root> <source.md>`.
4. Consume every JSONL diagnostic emitted by the helper. Report diagnostics with `level: "blocking"` as `ERROR`, diagnostics with `level: "warning"` as `WARNING`, and retain the helper diagnostic code, source, and reason in the report.
5. If the helper exits non-zero because it emitted `blocking` diagnostics, continue checking the remaining documents; `/sdd:doctor` remains read-only.

The helper owns the reference-table contract, including:

- the `## 文档引用` table and its 5-column header `关系`, `当前范围`, `目标文档`, `目标标识`, `说明`;
- relation enum validity;
- cross-version locators and project-level requirements `project:` locators.

## Output rules

- Group output by check range; each group reports `OK`, `WARNING`, or `ERROR`.
- Final next-step suggestions per state (not initialized → `/sdd:init`; 0 active → `/sdd:new vX.Y.Z`; multiple active/broken state → manual `state.json` fix; archive index issue → fix `docs/archive/INDEX.md`; reference table issue → fix reference tables).

## Reviewer agent checks

- 检查插件根目录 `agents/doc-reviewer.md` 是否存在。
- 检查 agent frontmatter 包含 `name: doc-reviewer` 和 `description`。
- 检查最终 ZIP/TAR 包包含 `agents/doc-reviewer.md`。
- 如缺失，报告 `缺少 doc-reviewer agent`，并阻止宣称 reviewer runtime 完整。

## Boundaries

- 不自动创建或修改文件、不修复 state.json、不创建 active version、不归档版本、不生成 ARCHIVE.md、不更新 INDEX.md、不读取 git log、不审计源码、不机器解析 CONSTITUTION must/should、不做正文链接语义启发式扫描。

## Template asset checks

- 检查项目 `.sdd/templates/` 是否存在。
- 检查 `prd/template.md`、`prd/quality.standard.md` 是否存在。
- 检查 `spec/template.md`、`spec/quality.standard.md`、`spec/feasibility.standard.md` 是否存在。
- 检查 `plan/template.md`、`plan/quality.standard.md`、`plan/feasibility.standard.md` 是否存在。
- 如缺失，报告 `缺少项目模板资产`，提示重新执行 `/sdd:init` 或手工修复。
- 可提示用户使用 `/sdd:review` 对现有文档重新收敛质量。
