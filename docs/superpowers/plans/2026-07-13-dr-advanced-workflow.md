# DR Advanced Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the DR classification template and workflow behavior defined in `docs/superpowers/specs/2026-07-13-dr-advance-spec.md`, so code-class and document-class DRs carry explicit process fields and produce correct next-step guidance.

**Architecture:** The implementation remains file-driven. DR classification is encoded in `skills/dr/references/dr.md.tmpl` and enforced by Skill instructions in `skills/dr/SKILL.md`, `skills/spec/SKILL.md`, `skills/plan/SKILL.md`, and `skills/code/SKILL.md`. Tests remain shell-based contract tests that validate templates, Skill text, and hook behavior without introducing a central state store.

**Tech Stack:** Claude Code Skills (`skills/<name>/SKILL.md`), Markdown templates under `skills/<name>/references/`, POSIX-compatible shell contract tests, existing SDD document status conventions.

## Global Constraints

- Do not introduce `.sdd/state.json` or any centralized state store.
- Keep the status line format as `- 状态：<value>`.
- Preserve existing DR statuses: `drafting`, `accepted`, `closed`.
- Preserve existing plan statuses: `draft`, `planned`, `coding`, `done`.
- Code-class DR tags are `fix`, `feat`, `chg`, and `arch`.
- Document-class DR tags are `spec`, `doc`, and `typo`.
- Document-class DRs must not generate Implementation Plans or execute `/sdd:code`.
- Code-class DRs must remain `accepted` after any associated spec revision and can only close after `/sdd:code` succeeds and verification passes.
- Historical DR files are not migrated automatically.
- Update only files directly needed for the V0.2.0 DR workflow behavior and contract coverage.

---

## Task 1: Update the DR Template With Explicit Classification Fields

**Files:**
- Modify: `skills/dr/references/dr.md.tmpl`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - Existing DR template format.
  - New template contract from `docs/superpowers/specs/2026-07-13-dr-advance-spec.md`.
- Produces:
  - DR template fields:
    - `- class：code | document`
    - `- spec_change：yes | no | maybe`
    - `- plan_required：yes | no`
    - `- code_required：yes | no`
  - New DR template sections:
    - `## 契约影响`
    - `## 实现影响`
    - `## 文档影响`
    - `## 验证方式`

- [ ] **Step 1: Write the failing template contract assertions**

  Update `tests/test-skill-contracts.sh` to assert that `skills/dr/references/dr.md.tmpl` contains the new classification fields and new impact/verification sections.

- [ ] **Step 2: Run the contract test to verify it fails**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

  Confirm the test fails because the current DR template lacks the V0.2.0 fields and sections.

- [ ] **Step 3: Update the DR template**

  Modify `skills/dr/references/dr.md.tmpl` so it matches the V0.2.0 template structure:

  ```markdown
  # DR-<tag>-NNNN：<标题>

  - 状态：drafting
  - class：code | document
  - tag：fix | feat | chg | arch | spec | doc | typo
  - 日期：YYYY-MM-DD
  - spec_change：yes | no | maybe
  - plan_required：yes | no
  - code_required：yes | no
  - closed_reason: null
  - closed_at: null
  - supersedes: []
  - superseded_by: null
  - dismissed_reason: null
  ```

  Keep existing `影响资产`, `背景`, `决策`, and `落地方式` sections, and add the new impact and verification sections.

- [ ] **Step 4: Run the contract test to verify it passes**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 5: Commit**

  Commit this task as a focused template contract change.

---

## Task 2: Update `/sdd:dr` Creation and Accept Guidance

**Files:**
- Modify: `skills/dr/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - DR tag list: `fix | feat | chg | arch | spec | doc | typo`
  - V0.2.0 tag default mapping.
- Produces:
  - Create-mode instructions that derive `class`, `spec_change`, `plan_required`, and `code_required` from tag.
  - Accept-mode instructions that read those fields and output correct next-step guidance.

- [ ] **Step 1: Write failing Skill contract assertions**

  Add assertions to `tests/test-skill-contracts.sh` requiring `skills/dr/SKILL.md` to mention:

  - `class` / `spec_change` / `plan_required` / `code_required`
  - `fix | code | no | yes | yes`
  - `feat | code | yes | yes | yes`
  - `chg | code | yes | yes | yes`
  - `arch | code | maybe | yes | yes`
  - `spec | document | yes | no | no`
  - `doc | document | maybe | no | no`
  - `typo | document | no | no | no`
  - code-class `spec_change: yes` should point to `/sdd:spec` before `/sdd:plan`
  - document-class should not enter `/sdd:plan`

- [ ] **Step 2: Run the contract test to verify it fails**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 3: Update create mode**

  Update `skills/dr/SKILL.md` create mode so `/sdd:dr <tag> <title>` explicitly says to:

  1. Generate the DR id and path as before.
  2. Fill template placeholders.
  3. Derive default fields from tag using the V0.2.0 table.
  4. Allow `spec_change` to be adjusted only when it does not violate the mandatory class/plan/code constraints.

- [ ] **Step 4: Update accept mode**

  Update accept mode so `/sdd:dr accept <id>` explicitly says to:

  1. Require status `drafting`.
  2. Change `drafting → accepted`.
  3. Read `class`, `spec_change`, `plan_required`, and `code_required`.
  4. Output next step:
     - `class: code`, `spec_change: yes`: run `/sdd:spec`, then `/sdd:plan <id>`.
     - `class: code`, `spec_change: no`: run `/sdd:plan <id>`.
     - `class: code`, `spec_change: maybe`: decide whether spec revision is needed; if yes, `/sdd:spec`, otherwise `/sdd:plan <id>`.
     - `class: document`: run `/sdd:spec` or the corresponding document Skill; do not enter `/sdd:plan`.

- [ ] **Step 5: Run the contract test to verify it passes**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 6: Commit**

  Commit this task as a focused DR Skill behavior update.

---

## Task 3: Update `/sdd:spec` to Support Code-Class DR Spec Revisions

**Files:**
- Modify: `skills/spec/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - Accepted document-class DRs with tags `spec`, `doc`, `typo`.
  - Accepted code-class DRs with `spec_change: yes` or code-class DRs where Agent determines spec revision is required.
- Produces:
  - Spec Skill guidance that can associate either document-class DRs or spec-changing code-class DRs.
  - Rule that code-class DRs remain `accepted` after spec approval.
  - Rule that document-class DRs may close after their document revision is committed.

- [ ] **Step 1: Write failing Skill contract assertions**

  Add assertions requiring `skills/spec/SKILL.md` to mention:

  - accepted code-class DRs with `spec_change` can be associated with `/sdd:spec`
  - code-class DR remains `accepted` after spec approval
  - next step for associated code-class DR is `/sdd:plan <id>`
  - document-class DRs may close after document revision
  - document-class DRs must not output `/sdd:plan` or `/sdd:code`

- [ ] **Step 2: Run the contract test to verify it fails**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 3: Update `/sdd:spec` dialogue**

  Modify the dialogue section so it lists two association categories:

  1. accepted document-class DRs with tags `spec`, `doc`, or `typo`.
  2. accepted code-class DRs with `spec_change: yes` or `spec_change: maybe` where the current revision needs a spec update.

- [ ] **Step 4: Update `/sdd:spec` state transition rules**

  Add explicit rules:

  - When associated DR is document-class and the document revision commits, change DR `accepted → closed`, set `closed_reason: committed`, and set `closed_at`.
  - When associated DR is code-class, do not close it after spec approval; keep it `accepted` and direct the user to `/sdd:plan <id>`.

- [ ] **Step 5: Run the contract test to verify it passes**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 6: Commit**

  Commit this task as a focused Spec Skill workflow update.

---

## Task 4: Update `/sdd:plan` and `/sdd:code` Field-Aware Preconditions

**Files:**
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/code/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - Accepted code-class DR ids matching `fix|feat|chg|arch-NNNN-<slug>`.
  - DR fields `plan_required` and `code_required`.
- Produces:
  - Plan Skill instructions that require `plan_required: yes` for code-class DR plan generation.
  - Code Skill instructions that require `code_required: yes` when executing a DR-backed plan.
  - Continued rejection of document-class DR ids in `/sdd:plan`.

- [ ] **Step 1: Write failing Skill contract assertions**

  Add assertions requiring:

  - `skills/plan/SKILL.md` mentions `plan_required: yes`.
  - `skills/plan/SKILL.md` still rejects `spec|doc|typo` DR ids.
  - `skills/code/SKILL.md` mentions `code_required: yes` for code-class DR-backed plans.
  - `skills/code/SKILL.md` keeps DR `accepted` if execution or verification fails.
  - `skills/code/SKILL.md` sets `closed_reason: committed` only after successful execution and verification.

- [ ] **Step 2: Run the contract test to verify it fails**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 3: Update `/sdd:plan` preconditions**

  Modify code-class DR mode so it requires:

  - DR status is `accepted`.
  - DR `class` is `code`.
  - DR `plan_required` is `yes`.

  Keep the existing syntax-based refusal for document-class ids.

- [ ] **Step 4: Update `/sdd:code` preconditions and close rules**

  Modify `/sdd:code` so a DR-backed plan requires:

  - Associated DR status is `accepted`.
  - Associated DR `class` is `code`.
  - Associated DR `code_required` is `yes`.

  Preserve the existing close behavior:

  - execution and verification success: plan `done`, DR `closed`, `closed_reason: committed`, `closed_at` set.
  - failure: plan remains `coding`, DR remains `accepted`.

- [ ] **Step 5: Run the contract test to verify it passes**

  Run:

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 6: Commit**

  Commit this task as a focused plan/code precondition update.

---

## Task 5: Add Hook and Fixture Coverage for Explicit DR Fields

**Files:**
- Modify: `tests/fixtures/valid-project.sh`
- Modify: `tests/test-pre-tool-use.sh`
- Modify: `scripts/hooks/pre-tool-use.sh` only if field-aware hook checks are intentionally added

**Interfaces:**
- Consumes:
  - Existing hook behavior that gates code-class DR plan writes by DR status `accepted`.
  - V0.2.0 explicit DR fields.
- Produces:
  - Fixture DR files that include the V0.2.0 fields.
  - Regression tests proving existing path/status gate still works with the new DR template.

- [ ] **Step 1: Inspect current fixture DR contents**

  Review `tests/fixtures/valid-project.sh` and identify every generated DR fixture.

- [ ] **Step 2: Update fixture DR files with explicit fields**

  Add the V0.2.0 fields to fixture DR documents, for example:

  ```markdown
  - class：code
  - spec_change：no
  - plan_required：yes
  - code_required：yes
  ```

  Preserve existing status lines used by hook tests.

- [ ] **Step 3: Decide whether hook should remain status-only**

  Keep hook behavior status-only unless the implementation explicitly chooses to make the hook validate `class` or `plan_required` mechanically. The V0.2.0 spec does not require full field-level hook validation.

- [ ] **Step 4: Run hook tests**

  Run:

  ```bash
  bash tests/test-pre-tool-use.sh
  ```

- [ ] **Step 5: Run common library tests**

  Run:

  ```bash
  bash tests/test-common-library.sh
  ```

- [ ] **Step 6: Commit**

  Commit this task as fixture and hook regression coverage.

---

## Task 6: Update User-Facing Workflow Documentation

**Files:**
- Modify: `README.md`
- Modify: `CONSTITUTION.default.md` if the new explicit fields should be elevated to constitutional constraints
- Modify: `docs/superpowers/specs/2026-07-11-sdd-plugin-mvp-workflow-spec-design.md` only if the MVP authority document must reference the V0.2.0 extension

**Interfaces:**
- Consumes:
  - V0.2.0 design spec.
  - Existing README code-class/document-class flow documentation.
- Produces:
  - User-facing explanation of explicit DR fields and three standard flows.

- [ ] **Step 1: Write failing documentation contract assertions**

  Add assertions to `tests/test-skill-contracts.sh` or another appropriate contract test requiring README and/or Constitution to mention the new fields if they are updated in this task.

- [ ] **Step 2: Run the documentation contract test to verify it fails**

  Run the selected contract test.

- [ ] **Step 3: Update README workflow section**

  Add a concise section that explains:

  - code-class DR fields and flow.
  - document-class DR fields and flow.
  - spec-changing code-class DRs remain `accepted` after spec approval.
  - fix DRs for implementation deviations usually have `spec_change: no`.

- [ ] **Step 4: Update Constitution only if needed**

  If the explicit fields are intended as hard workflow constraints, update `CONSTITUTION.default.md` with must-level rules:

  - code-class DRs must have `plan_required: yes` and `code_required: yes`.
  - document-class DRs must have `plan_required: no` and `code_required: no`.
  - code-class DRs must not close during spec revision.

  If these are only Skill-level details, leave Constitution unchanged.

- [ ] **Step 5: Run the documentation contract test to verify it passes**

  Run the selected contract test.

- [ ] **Step 6: Commit**

  Commit this task as documentation alignment for V0.2.0 DR workflow.

---

## Task 7: Run Full Verification

**Files:**
- Test only; no expected source edits unless failures reveal missed required changes.

**Interfaces:**
- Consumes:
  - All changes from Tasks 1-6.
- Produces:
  - Passing shell contract suite.
  - Verified implementation matches `docs/superpowers/specs/2026-07-13-dr-advance-spec.md`.

- [ ] **Step 1: Run skill contract tests**

  ```bash
  bash tests/test-skill-contracts.sh
  ```

- [ ] **Step 2: Run hook tests**

  ```bash
  bash tests/test-pre-tool-use.sh
  ```

- [ ] **Step 3: Run common library tests**

  ```bash
  bash tests/test-common-library.sh
  ```

- [ ] **Step 4: Run doctor contract tests**

  ```bash
  bash tests/test-doctor-contract.sh
  ```

- [ ] **Step 5: Run MVP acceptance tests**

  ```bash
  bash tests/test-mvp-acceptance.sh
  ```

- [ ] **Step 6: Check git status and diff**

  ```bash
  git status --short
  git diff --stat
  ```

- [ ] **Step 7: Final commit**

  If any verification-only fixes were needed, commit them separately with a message describing the verification fix.
