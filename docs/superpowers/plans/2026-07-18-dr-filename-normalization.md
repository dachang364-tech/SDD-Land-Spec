# DR Filename Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the canonical DR naming contract from `docs/superpowers/specs/2026-07-17-dr-filename-normalization-spec.md` so new Decision Records use `NNN-<tag>-<slug>.md`, all DR lookup flows use the full new `DR ID`, and docs/tests/hook behavior converge on the same exact contract.

**Architecture:** Keep the existing repository shape: the runtime contract lives in Bash helpers and hook scripts, while workflow behavior is primarily specified through Claude Code Skill markdown, templates, README text, and shell contract tests. Introduce the new DR naming and lookup rules at the shared helper layer first, then update the DR template, DR/plan/code/doctor skill contracts, hook gating, fixtures, README/package output, and regression tests so every layer describes and enforces the same `DR file basename -> DR ID -> plan basename -> exact lookup` model. Add one dedicated DR contract test file to convert the spec’s failure semantics into executable checks rather than relying on static wording alone.

**Tech Stack:** Bash helpers in `scripts/lib`, Claude Code Skill markdown in `skills/*/SKILL.md`, Markdown templates in `skills/*/references/*.md.tmpl`, hook script `scripts/hooks/pre-tool-use.sh`, packaging script `scripts/package-local.sh`, and shell contract tests in `tests/*.sh`.

## Global Constraints

- New DR standard output must be `docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md`.
- `DR ID` must equal the full DR basename without `.md`.
- `DR title identifier` must use `DR-NNN-<tag>` and must not include the slug.
- `tag` is restricted to `fix | feat | chg | arch | spec | doc | typo`.
- `slug` must be non-empty lowercase kebab-case using only ASCII lowercase letters, digits, and hyphens.
- `DR number` and `plan number` are separate 3-digit sequences in the range `001..999`.
- New DR creation must fail when the next DR number would exceed `999`.
- New behavior must not keep `<tag>-NNNN-<slug>.md` as canonical output.
- This implementation must not add compatibility aliases, migrations, historical batch renames, fuzzy slug lookup, or basename auto-rename driven by title edits.
- `/sdd:dr accept`, `/sdd:plan`, `/sdd:code`, doctor, and the pre-tool-use hook must use exact full `DR ID` matching only.
- Any invalid `DR ID`, missing unique DR, ambiguous match, or document-class DR used in a code-class path must fail explicitly.
- Code-class plan hook gating must not silently fall back to spec-mode when DR parsing or lookup fails.
- README, packaged README, skills, helpers, hook, and tests must all describe the same canonical contract.

---

## File Structure

- Modify `scripts/lib/sdd-common.sh`: replace the old tag-first/four-digit DR number allocation logic with 3-digit number allocation and shared DR ID parsing helpers.
- Modify `skills/dr/SKILL.md`: redefine DR create mode, ID syntax, title identifier, accept examples, and error handling for new IDs.
- Modify `skills/dr/references/dr.md.tmpl`: update the DR title line to `# DR-NNN-<tag>：<标题>`.
- Modify `skills/plan/SKILL.md`: redefine code-class DR mode detection and failure semantics around the new `DR ID`.
- Modify `skills/code/SKILL.md`: redefine DR lookup syntax and exact matching behavior for new `DR ID`.
- Modify `skills/doctor/SKILL.md`: rewrite plan/DR consistency rules to compare `strip(plan-number-) == full DR ID`.
- Modify `scripts/hooks/pre-tool-use.sh`: keep existing path normalization and gating structure, but parse code-class plan DR IDs using the new full basename semantics and reject legacy-shaped plan names.
- Modify `README.md`: update user-facing DR examples, document structure, hook explanation, `/sdd:dr accept`, and `/sdd:plan`/`/sdd:code` examples.
- Modify `scripts/package-local.sh`: keep packaged README in sync with root README’s canonical DR naming examples and structure text.
- Modify `tests/fixtures/valid-project.sh`: update the canonical fixture to use the new DR basename.
- Modify `tests/test-common-library.sh`: update DR numbering tests and add new DR ID parsing/overflow coverage.
- Modify `tests/test-pre-tool-use.sh`: update code-class plan hook fixtures to the new `DR ID` format and add exact-failure assertions.
- Create `tests/test-dr-filename-contract.sh`: cover `/sdd:dr accept`, `/sdd:plan <dr-id>`, `/sdd:code <dr-id>`, and doctor-oriented failure semantics as executable contract checks.
- Modify `tests/test-skill-contracts.sh`: update static skill/README/TESTING/constitution assertions from old DR naming to the new canonical contract.
- Modify `tests/test-package-local.sh`: verify packaged artifacts carry the new canonical naming text and structure.
- Modify `tests/test-doctor-contract.sh`: assert the doctor contract text and skeleton files now mention the new `DR ID`-based consistency rule.
- Modify `tests/test-mvp-acceptance.sh`: add `tests/test-dr-filename-contract.sh` to the aggregate regression entrypoint.

---

### Task 1: Rebuild shared DR naming helpers and base fixtures

**Files:**
- Modify: `scripts/lib/sdd-common.sh:172-214`
- Modify: `tests/fixtures/valid-project.sh:3-10`
- Modify: `tests/test-common-library.sh:40-47,113-114`
- Test: `tests/test-common-library.sh`

**Interfaces:**
- Consumes: existing `sdd_slug()`, `sdd_read_status()`, `sdd_active_version_dir()`, and shell test helpers from `tests/test-common.sh`
- Produces:
  - `sdd_next_dr_number(decisions_dir) -> stdout <NNN>; exit 2 on overflow`
  - `sdd_is_dr_id(value) -> exit 0 for valid new-format DR IDs only`
  - `sdd_plan_dr_id_from_basename(plan_basename) -> stdout <dr-id>; exit 2 on non code-class plan syntax`
  - canonical fixture DR `001-fix-login-null.md`

**Acceptance Mapping:**
- FR1, FR3, FR4, FR5, FR6
- Acceptance criteria 1, 2, 9, 10

- [ ] **Step 1: Write the failing common-library and fixture assertions**

In `tests/fixtures/valid-project.sh`, replace the DR fixture line:

```bash
printf '# DR\n\n- 状态：accepted\n- class：code\n- tag：fix\n- spec_change：no\n- plan_required：yes\n- code_required：yes\n- closed_reason: null\n' > "$root/docs/versions/v0.1.0/decisions/fix-0001-login-null.md"
```

with:

```bash
printf '# DR-001-fix：Login null\n\n- 状态：accepted\n- class：code\n- tag：fix\n- spec_change：no\n- plan_required：yes\n- code_required：yes\n- closed_reason: null\n' > "$root/docs/versions/v0.1.0/decisions/001-fix-login-null.md"
```

In `tests/test-common-library.sh`, replace the current DR-number assertion block:

```bash
dr_number="$(sdd_next_dr_number "$tmp/valid/docs/versions/v0.1.0/decisions")"
[[ "$dr_number" == "0002" ]] || fail "expected next DR 0002, got $dr_number"
```

with:

```bash
dr_number="$(sdd_next_dr_number "$tmp/valid/docs/versions/v0.1.0/decisions")"
[[ "$dr_number" == "002" ]] || fail "expected next DR 002, got $dr_number"
```

Then append these exact assertions before the final `PASS: common library` line:

```bash
sdd_is_dr_id "001-fix-login-null" || fail "expected new DR ID to be valid"
sdd_is_dr_id "001-spec-release-note" || fail "expected document-class DR ID to be valid"
if sdd_is_dr_id "fix-0001-login-null"; then
  fail "expected legacy DR ID to be invalid"
fi
if sdd_is_dr_id "1000-fix-login-null"; then
  fail "expected 4-digit DR number to be invalid"
fi
if sdd_is_dr_id "001-fix-"; then
  fail "expected empty slug DR ID to be invalid"
fi

plan_dr_id="$(sdd_plan_dr_id_from_basename "007-001-fix-login-null.md")"
[[ "$plan_dr_id" == "001-fix-login-null" ]] || fail "expected 001-fix-login-null, got $plan_dr_id"

if sdd_plan_dr_id_from_basename "007-feature-login.md" >/tmp/sdd-plan-dr-id.out 2>/tmp/sdd-plan-dr-id.err; then
  fail "expected spec-mode plan basename to fail code-class DR parsing"
fi
assert_contains "/tmp/sdd-plan-dr-id.err" "不是 code-class DR plan"

mkdir -p "$tmp/empty-decisions"
first_dr_number="$(sdd_next_dr_number "$tmp/empty-decisions")"
[[ "$first_dr_number" == "001" ]] || fail "expected first DR number 001, got $first_dr_number"

mkdir -p "$tmp/multi-tag-decisions"
printf '# DR-001-fix：A\n\n- 状态：accepted\n' > "$tmp/multi-tag-decisions/001-fix-a.md"
printf '# DR-002-feat：B\n\n- 状态：accepted\n' > "$tmp/multi-tag-decisions/002-feat-b.md"
printf '# DR-009-doc：C\n\n- 状态：accepted\n' > "$tmp/multi-tag-decisions/009-doc-c.md"
shared_number="$(sdd_next_dr_number "$tmp/multi-tag-decisions")"
[[ "$shared_number" == "010" ]] || fail "expected cross-tag next DR number 010, got $shared_number"

mkdir -p "$tmp/overflow-decisions"
printf '# DR-999-fix：Overflow\n\n- 状态：accepted\n' > "$tmp/overflow-decisions/999-fix-overflow.md"
if sdd_next_dr_number "$tmp/overflow-decisions" >/tmp/sdd-next-dr-overflow.out 2>/tmp/sdd-next-dr-overflow.err; then
  fail "expected DR number overflow to fail"
fi
assert_contains "/tmp/sdd-next-dr-overflow.err" "DR 编号已达到上限 999"
```

- [ ] **Step 2: Run the focused library test to verify it fails**

Run:

```bash
bash tests/test-common-library.sh
```

Expected: FAIL because `sdd_next_dr_number` still returns four digits, the fixture still uses `fix-0001-login-null.md`, and the new helper functions do not exist yet.

- [ ] **Step 3: Update `scripts/lib/sdd-common.sh` with the new DR helper contract**

In `scripts/lib/sdd-common.sh`, replace the existing `sdd_next_dr_number()` implementation:

```bash
sdd_next_dr_number() {
  local decisions_dir="$1"
  local max=0
  local file base rest number
  shopt -s nullglob
  for file in "$decisions_dir"/*.md; do
    base="$(basename "$file" .md)"
    rest="${base#*-}"
    number="${rest%%-*}"
    if [[ "$number" =~ ^[0-9][0-9][0-9][0-9]$ ]] && (( 10#$number > max )); then
      max=$((10#$number))
    fi
  done
  shopt -u nullglob
  printf '%04d\n' "$((max + 1))"
}
```

with this exact block:

```bash
sdd_is_dr_id() {
  local value="$1"
  [[ "$value" =~ ^[0-9][0-9][0-9]-(fix|feat|chg|arch|spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

sdd_next_dr_number() {
  local decisions_dir="$1"
  local max=0
  local file base number
  shopt -s nullglob
  for file in "$decisions_dir"/*.md; do
    base="$(basename "$file" .md)"
    number="${base%%-*}"
    if sdd_is_dr_id "$base" && [[ "$number" =~ ^[0-9][0-9][0-9]$ ]] && (( 10#$number > max )); then
      max=$((10#$number))
    fi
  done
  shopt -u nullglob
  if (( max >= 999 )); then
    printf 'DR 编号已达到上限 999：%s\n' "$decisions_dir" >&2
    return 2
  fi
  printf '%03d\n' "$((max + 1))"
}

sdd_plan_dr_id_from_basename() {
  local plan_basename="$1"
  local base="${plan_basename%.md}"
  local rest="${base#???-}"
  if [[ ! "$base" =~ ^[0-9][0-9][0-9]-[0-9][0-9][0-9]-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    printf '不是 code-class DR plan：%s\n' "$plan_basename" >&2
    return 2
  fi
  if ! sdd_is_dr_id "$rest"; then
    printf '非法 DR ID：%s\n' "$rest" >&2
    return 2
  fi
  printf '%s\n' "$rest"
}
```

Do not change `sdd_next_plan_number()` or `sdd_slug()`.

- [ ] **Step 4: Run the library test to verify it passes**

Run:

```bash
bash tests/test-common-library.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-common.sh tests/fixtures/valid-project.sh tests/test-common-library.sh
git commit -m "feat: normalize DR numbering helpers"
```

---

### Task 2: Update DR creation contract, template title, and static skill assertions

**Files:**
- Modify: `skills/dr/SKILL.md:47-66,68-99,106-111`
- Modify: `skills/dr/references/dr.md.tmpl:1-14`
- Modify: `tests/test-skill-contracts.sh:137-176,205-213,260-280`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: `sdd_next_dr_number()`, `sdd_slug()`, and the existing DR field model (`class`, `spec_change`, `plan_required`, `code_required`)
- Produces:
  - DR create mode text using `NNN-<tag>-<slug>.md`
  - DR title identifier text using `DR-NNN-<tag>`
  - accept/dismiss examples using the full new `DR ID`
  - static contract assertions tied to the new naming examples

**Acceptance Mapping:**
- FR1, FR2, FR3, FR4, FR9
- Acceptance criteria 1, 2, 3, 4, 8, 11

- [ ] **Step 1: Write the failing DR skill assertions**

In `tests/test-skill-contracts.sh`, replace:

```bash
assert_contains "skills/dr/SKILL.md" "docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md"
```

with:

```bash
assert_contains "skills/dr/SKILL.md" "docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md"
```

Then add these assertions immediately after the DR path assertion block:

```bash
assert_contains "skills/dr/SKILL.md" "Generate version-local increasing DR number `NNN`; if none, use `001`."
assert_contains "skills/dr/SKILL.md" "`DR ID` 指去掉 `.md` 后的完整 DR basename"
assert_contains "skills/dr/SKILL.md" "标题标识格式固定为 `DR-NNN-<tag>`"
assert_contains "skills/dr/SKILL.md" "`/sdd:dr accept 001-fix-login-null`"
assert_contains "skills/dr/SKILL.md" "不兼容 `<tag>-NNNN-<slug>` 旧格式"
assert_contains "skills/dr/references/dr.md.tmpl" "# DR-NNN-<tag>：<标题>"
assert_not_contains "skills/dr/references/dr.md.tmpl" "# DR-<tag>-NNNN：<标题>"
```

- [ ] **Step 2: Run the contract test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL because the DR skill and DR template still describe the old tag-first/four-digit format.

- [ ] **Step 3: Rewrite the DR create-mode and template examples to the new canonical contract**

In `skills/dr/SKILL.md`, replace this create-mode step block:

```markdown
1. Scan `docs/versions/vX.Y.Z/decisions/*.md`.
2. Generate version-local increasing DR number `NNNN`; if none, use `0001`.
3. Slugify title.
4. Write `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
```

with:

```markdown
1. Scan `docs/versions/vX.Y.Z/decisions/*.md`.
2. Generate version-local increasing DR number `NNN`; if none, use `001`.
3. Slugify title.
4. Write `docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
5. `DR ID` 指去掉 `.md` 后的完整 DR basename。
6. 标题标识格式固定为 `DR-NNN-<tag>`，slug 不进入标题标识。
7. 不兼容 `<tag>-NNNN-<slug>` 旧格式，不提供 alias、双写或模糊读取。
```

In the same file, add this line at the end of `## Create mode`:

```markdown
Example: `/sdd:dr accept 001-fix-login-null`
```

In `skills/dr/references/dr.md.tmpl`, replace the first line:

```markdown
# DR-<tag>-NNNN：<标题>
```

with:

```markdown
# DR-NNN-<tag>：<标题>
```

Do not change the rest of the DR field block or the `## 文档引用` table.

- [ ] **Step 4: Run the skill contract test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS for the DR naming assertions.

- [ ] **Step 5: Commit**

```bash
git add skills/dr/SKILL.md skills/dr/references/dr.md.tmpl tests/test-skill-contracts.sh
git commit -m "docs: redefine DR naming contract"
```

---

### Task 3: Add executable DR resolution and failure contract tests

**Files:**
- Create: `tests/test-dr-filename-contract.sh`
- Modify: `tests/test-common.sh:1-40`
- Modify: `tests/test-doctor-contract.sh:1-40`
- Modify: `tests/test-mvp-acceptance.sh:28-38`
- Test: `tests/test-dr-filename-contract.sh`
- Test: `tests/test-doctor-contract.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `sdd_is_dr_id()`, `sdd_plan_dr_id_from_basename()`, DR fixture layout, and the skill text contract for `/sdd:dr accept`, `/sdd:plan`, `/sdd:code`, and doctor
- Produces:
  - executable contract coverage for invalid `DR ID`, document-class DR rejection, exact matching wording, and doctor consistency wording
  - `assert_not_contains(path, needle)` helper available to shell tests
  - aggregate regression entrypoint updated to run the new contract test

**Acceptance Mapping:**
- FR4, FR5, FR6, FR8
- Acceptance criteria 4, 5, 6, 11

- [ ] **Step 1: Write the failing DR contract and doctor assertions**

Append this helper to `tests/test-common.sh` after `assert_contains`:

```bash
assert_not_contains() {
  local path="$1"
  local needle="$2"
  [[ "$(<"$path")" != *"$needle"* ]] || fail "expected $path not to contain: $needle"
}
```

Create `tests/test-dr-filename-contract.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

sdd_is_dr_id "001-fix-login-null" || fail "expected code-class DR ID to be valid"
sdd_is_dr_id "001-doc-release-note" || fail "expected document-class DR ID to be valid"
if sdd_is_dr_id "fix-0001-login-null"; then
  fail "expected legacy DR ID to be invalid"
fi

plan_dr_id="$(sdd_plan_dr_id_from_basename "007-001-fix-login-null.md")"
[[ "$plan_dr_id" == "001-fix-login-null" ]] || fail "expected 001-fix-login-null, got $plan_dr_id"

if sdd_plan_dr_id_from_basename "007-001-doc-release-note.md" >/tmp/sdd-doc-plan-id.out 2>/tmp/sdd-doc-plan-id.err; then
  fail "expected document-class DR plan basename to fail"
fi
assert_contains "/tmp/sdd-doc-plan-id.err" "不是 code-class DR plan"

assert_contains "skills/dr/SKILL.md" '`/sdd:dr accept 001-fix-login-null`'
assert_contains "skills/plan/SKILL.md" 'If `<work-item>` matches `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`, use code-class DR mode.'
assert_contains "skills/plan/SKILL.md" 'If `<work-item>` matches `^[0-9]{3}-(spec|doc|typo)-[a-z0-9-]+$`, refuse'
assert_contains "skills/code/SKILL.md" 'If input matches a code-class DR id `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`'
assert_contains "skills/code/SKILL.md" 'first check for a matching plan by exact DR ID suffix'
assert_contains "skills/code/SKILL.md" 'If zero plans match and no eligible lightweight fix DR matches'
assert_contains "skills/doctor/SKILL.md" 'the remaining plan basename must equal the full `DR ID`'
assert_not_contains "skills/doctor/SKILL.md" 'plan filename minus `NNN-` equals DR slug'

printf 'PASS: DR filename contract\n'
```

In `tests/test-doctor-contract.sh`, append these assertions before the final `PASS` line:

```bash
assert_contains "skills/doctor/SKILL.md" 'the remaining plan basename must equal the full `DR ID`'
assert_not_contains "skills/doctor/SKILL.md" 'plan filename minus `NNN-` equals DR slug'
```

In `tests/test-mvp-acceptance.sh`, add this line after the existing `test-skill-contracts.sh` invocation:

```bash
bash tests/test-dr-filename-contract.sh
```

- [ ] **Step 2: Run the focused contract tests to verify they fail**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-dr-filename-contract.sh
```

Expected: FAIL because the new helper file content and skill wording do not exist yet, and `tests/test-dr-filename-contract.sh` has not been created.

- [ ] **Step 3: Add the DR contract test file and aggregate it into MVP acceptance**

Write `tests/test-dr-filename-contract.sh` exactly as shown in Step 1, then run:

```bash
chmod +x tests/test-dr-filename-contract.sh
```

Keep the `assert_not_contains` helper and doctor assertions exactly as written.

- [ ] **Step 4: Run the contract tests to verify they pass**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-dr-filename-contract.sh && bash tests/test-mvp-acceptance.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test-common.sh tests/test-doctor-contract.sh tests/test-dr-filename-contract.sh tests/test-mvp-acceptance.sh
git commit -m "test: cover DR filename resolution contract"
```

---

### Task 4: Rewrite `/sdd:plan`, `/sdd:code`, and doctor to use exact full DR IDs

**Files:**
- Modify: `skills/plan/SKILL.md:19-44`
- Modify: `skills/code/SKILL.md:19-35`
- Modify: `skills/doctor/SKILL.md:75-80`
- Modify: `tests/test-skill-contracts.sh:97-131,221-237`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-dr-filename-contract.sh`

**Interfaces:**
- Consumes: `sdd_is_dr_id()` and `sdd_plan_dr_id_from_basename()` semantics from Task 1
- Produces:
  - code-class DR mode detection using `NNN-<tag>-<slug>`
  - `/sdd:code` exact DR ID lookup wording
  - doctor rule `strip plan-number prefix == full DR ID`
  - static plus executable tests for plan/code/doctor wording

**Acceptance Mapping:**
- FR5, FR6, FR8
- Acceptance criteria 5, 6, 9, 11

- [ ] **Step 1: Write the failing skill contract assertions for plan/code/doctor**

In `tests/test-skill-contracts.sh`, replace the old DR-format assertions in the plan/code sections with these exact assertions:

```bash
assert_contains "skills/plan/SKILL.md" "If `<work-item>` matches `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`, use code-class DR mode."
assert_contains "skills/plan/SKILL.md" "If `<work-item>` matches `^[0-9]{3}-(spec|doc|typo)-[a-z0-9-]+$`, refuse"
assert_contains "skills/plan/SKILL.md" "docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md"
assert_contains "skills/code/SKILL.md" "If input matches a code-class DR id `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`"
assert_contains "skills/code/SKILL.md" "first check for a matching plan by exact DR ID suffix"
assert_contains "skills/code/SKILL.md" "If zero plans match and no eligible lightweight fix DR matches"
assert_contains "skills/doctor/SKILL.md" "strip the leading `plan number` and hyphen"
assert_contains "skills/doctor/SKILL.md" "the remaining plan basename must equal the full `DR ID`"
assert_not_contains "skills/doctor/SKILL.md" "plan filename minus `NNN-` equals DR slug"
```

- [ ] **Step 2: Run the contract test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-dr-filename-contract.sh
```

Expected: FAIL because `skills/plan/SKILL.md`, `skills/code/SKILL.md`, and `skills/doctor/SKILL.md` still encode the old tag-first/four-digit DR ID semantics.

- [ ] **Step 3: Update the three skill contracts to the new exact-match model**

In `skills/plan/SKILL.md`, replace the two mode-detection lines:

```markdown
1. If `<work-item>` matches `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
```

with:

```markdown
1. If `<work-item>` matches `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^[0-9]{3}-(spec|doc|typo)-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
```

In `skills/code/SKILL.md`, replace the DR lookup rule:

```markdown
4. If input matches a code-class DR id `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, first check for a matching plan by suffix. If no plan matches, read `docs/versions/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when DR `tag` is `fix` and `plan_required: no`.
```

with:

```markdown
4. If input matches a code-class DR id `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`, first check for a matching plan by exact DR ID suffix. If no plan matches, read `docs/versions/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when DR `tag` is `fix` and `plan_required: no`.
```

In `skills/doctor/SKILL.md`, replace:

```markdown
- accepted code-class DR with `plan_required: yes` should have a matching plan (plan filename minus `NNN-` equals DR slug).
```

with:

```markdown
- accepted code-class DR with `plan_required: yes` should have a matching plan.
- For a code-class DR plan, strip the leading `plan number` and hyphen from the plan basename.
- The remaining plan basename must equal the full `DR ID`.
```

Do not change the lightweight fix bullet or the close-reminder bullet.

- [ ] **Step 4: Run the skill and executable DR contract tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-dr-filename-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md skills/code/SKILL.md skills/doctor/SKILL.md tests/test-skill-contracts.sh tests/test-dr-filename-contract.sh
git commit -m "docs: align plan code and doctor with new DR IDs"
```

---

### Task 5: Update pre-tool-use hook gating to the new plan-to-DR contract

**Files:**
- Modify: `scripts/hooks/pre-tool-use.sh:52-84`
- Modify: `tests/test-pre-tool-use.sh:22-84`
- Test: `tests/test-pre-tool-use.sh`

**Interfaces:**
- Consumes: `sdd_read_status()`, `sdd_is_dr_id()`, and `sdd_plan_dr_id_from_basename()` from `scripts/lib/sdd-common.sh`
- Produces:
  - code-class plan gating for `plans/<plan-number>-<dr-id>.md`
  - explicit failures for illegal code-class plan basenames
  - explicit failures that do not fall through into spec-mode gating

**Acceptance Mapping:**
- FR7, FR8
- Acceptance criteria 5, 6, 7

- [ ] **Step 1: Write the failing hook regression updates**

In `tests/test-pre-tool-use.sh`, replace the old code-class DR setup blocks:

```bash
printf '# DR\n\n- 状态：drafting\n- class：code\n- tag：chg\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/chg-0002-policy.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/004-chg-0002-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/versions/v0.1.0/decisions/chg-0002-policy.md 状态为 drafting，期望 accepted"

printf '# DR\n\n- 状态：drafting\n- class：code\n- tag：feat\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/feat-0002-rollout.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/005-feat-0002-rollout.md" >/tmp/sdd-hook4.out 2>/tmp/sdd-hook4.err; then
  fail "expected feat DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook4.err" "前置 DR docs/versions/v0.1.0/decisions/feat-0002-rollout.md 状态为 drafting，期望 accepted"
```

with:

```bash
printf '# DR-002-chg：Policy\n\n- 状态：drafting\n- class：code\n- tag：chg\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/002-chg-policy.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/004-002-chg-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/versions/v0.1.0/decisions/002-chg-policy.md 状态为 drafting，期望 accepted"

printf '# DR-003-feat：Rollout\n\n- 状态：drafting\n- class：code\n- tag：feat\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/003-feat-rollout.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/005-003-feat-rollout.md" >/tmp/sdd-hook4.out 2>/tmp/sdd-hook4.err; then
  fail "expected feat DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook4.err" "前置 DR docs/versions/v0.1.0/decisions/003-feat-rollout.md 状态为 drafting，期望 accepted"
```

Then append this exact illegal-ID regression before the final archive checks:

```bash
if run_hook "$tmp" "docs/versions/v0.1.0/plans/006-fix-0002-legacy.md" >/tmp/sdd-hook-legacy.out 2>/tmp/sdd-hook-legacy.err; then
  fail "expected legacy DR-style plan basename to fail"
fi
assert_contains "/tmp/sdd-hook-legacy.err" "非法 DR ID"
```

- [ ] **Step 2: Run the hook test to verify it fails**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected: FAIL because the hook still reconstructs `dr_id` from old tag-first semantics and does not reject the legacy-style code-class plan basename.

- [ ] **Step 3: Change `pre-tool-use.sh` to parse the new full DR ID exactly once**

In `scripts/hooks/pre-tool-use.sh`, replace this old code-class plan block:

```bash
  docs/versions/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    base="$(basename "$target_path" .md)"
    dr_id="${base#???-}"
    dr="docs/versions/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
```

with this exact block:

```bash
  docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    base="$(basename "$target_path")"
    dr_id="$(sdd_plan_dr_id_from_basename "$base")" || {
      printf '无法写入 %s：\n非法 DR ID。\n' "$target_path" >&2
      exit 2
    }
    dr="docs/versions/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
```

Then add this explicit legacy-pattern blocker immediately before the generic `docs/versions/v*/plans/[0-9][0-9][0-9]-*.md)` branch:

```bash
  docs/versions/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    printf '无法写入 %s：\n非法 DR ID。\n' "$target_path" >&2
    exit 2
    ;;
```

Do not change `normalize_target_path()` or the approved-spec fallback branch.

- [ ] **Step 4: Run the hook test to verify it passes**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/hooks/pre-tool-use.sh tests/test-pre-tool-use.sh
git commit -m "fix: gate code-class plans by new DR IDs"
```

---

### Task 6: Align README, packaged README, and contract tests with the new canonical DR format

**Files:**
- Modify: `README.md:166-249`
- Modify: `scripts/package-local.sh:70-185`
- Modify: `tests/test-skill-contracts.sh:205-301`
- Modify: `tests/test-package-local.sh:31-45`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-package-local.sh`

**Interfaces:**
- Consumes: all canonical naming decisions from Tasks 1-5
- Produces:
  - root README examples using the new DR basename and DR title identifier
  - packaged README text matching the same canonical output and directory structure wording
  - tests that reject the old canonical description

**Acceptance Mapping:**
- FR5, FR9
- Acceptance criteria 3, 5, 11

- [ ] **Step 1: Write the failing README/package assertions**

In `tests/test-skill-contracts.sh`, add these exact assertions near the existing README block:

```bash
assert_contains "README.md" 'docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md'
assert_contains "README.md" '`/sdd:dr accept 001-fix-login-null`'
assert_contains "README.md" '`plans/002-001-fix-login-null.md`'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md'
assert_not_contains "README.md" '[feat-0001-example](../decisions/feat-0001-example.md)'
```

In `tests/test-package-local.sh`, after the packaged README existence check, add:

```bash
assert_contains "$tmp_extract/$package_root/README.md" '001-fix-login-null'
assert_contains "$tmp_extract/$package_root/README.md" 'plans/002-001-fix-login-null.md'
assert_contains "$tmp_extract/$package_root/README.md" 'NNN-<tag>-<slug>.md'
assert_not_contains "$tmp_extract/$package_root/README.md" '<tag>-NNNN-<slug>'
```

- [ ] **Step 2: Run the README/package tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-package-local.sh
```

Expected: FAIL because the root README still documents the old canonical DR basename and the packaged README does not yet include the new structure text and examples.

- [ ] **Step 3: Update README text and packaged README heredoc**

In `README.md`, replace the Markdown link example:

```markdown
spec、plan、DR 之间的引用应使用 Markdown 链接，例如 `[feat-0001-example](../decisions/feat-0001-example.md)`。章节号和标题可以作为普通文本放在链接后，不强制使用 Markdown anchor。
```

with:

```markdown
spec、plan、DR 之间的引用应使用 Markdown 链接，例如 `[001-feat-example](../decisions/001-feat-example.md)`。章节号和标题可以作为普通文本放在链接后，不强制使用 Markdown anchor。
```

In the `## 文档结构` tree of `README.md`, replace:

```text
└── decisions/
    └── <tag>-NNNN-<slug>.md
```

with:

```text
└── decisions/
    └── NNN-<tag>-<slug>.md
```

In the `## Hook 门控` section of `README.md`, replace:

```markdown
- 写 `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`（不含 `NNN-{fix,feat,chg,arch}-*.md`）前要求 `specs/*.md` 中至少一个目标 Functional Specification 状态为 `approved`
- 写 `docs/versions/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md` 前要求对应 DR 状态为 `accepted`
```

with:

```markdown
- 写 `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`（不含 `NNN-<dr-id>.md`，其中 `<dr-id>` 为 `NNN-{fix,feat,chg,arch}-<slug>`）前要求 `specs/*.md` 中至少一个目标 Functional Specification 状态为 `approved`
- 写 `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md`，其中 `<dr-id>` 为 `NNN-{fix,feat,chg,arch}-<slug>`，前要求对应 DR 状态为 `accepted`
```

Then add this example sentence under the code-class DR flow section in `README.md`:

```markdown
例如：`/sdd:plan 001-fix-login-null` 会生成 `plans/002-001-fix-login-null.md`。
```

In the heredoc README inside `scripts/package-local.sh`, add this directory-structure sentence immediately after the `## 项目文档结构` code block:

```markdown
其中，Decision Record 的标准文件名为 `NNN-<tag>-<slug>.md`。
```

Then add this example sentence immediately after the code-class DR flow block in the heredoc README:

```markdown
例如：`/sdd:plan 001-fix-login-null` 会生成 `plans/002-001-fix-login-null.md`。
```

Do not change the package file list or marketplace behavior.

- [ ] **Step 4: Run the README/package tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-package-local.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md scripts/package-local.sh tests/test-skill-contracts.sh tests/test-package-local.sh
git commit -m "docs: update README examples for normalized DR IDs"
```

---

### Task 7: Run the full regression bundle and tighten exact-copy mismatches only

**Files:**
- Modify: `tests/test-common-library.sh` only if exact wording must be corrected
- Modify: `tests/test-pre-tool-use.sh` only if exact wording must be corrected
- Modify: `tests/test-dr-filename-contract.sh` only if exact wording must be corrected
- Modify: `tests/test-skill-contracts.sh` only if exact wording must be corrected
- Modify: `tests/test-package-local.sh` only if exact wording must be corrected
- Modify: `tests/test-doctor-contract.sh` only if exact wording must be corrected
- Modify: `README.md` only if exact wording must be corrected
- Modify: `scripts/package-local.sh` only if exact wording must be corrected
- Test: `tests/test-common-library.sh`
- Test: `tests/test-pre-tool-use.sh`
- Test: `tests/test-dr-filename-contract.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-package-local.sh`
- Test: `tests/test-reference-validation.sh`
- Test: `tests/test-doctor-contract.sh`
- Test: `tests/test-mvp-acceptance.sh`
- Test: `scripts/package-local.sh`
- Test: `git diff --check`

**Interfaces:**
- Consumes: all helper, hook, skill, README, fixture, doctor, and packaging changes from Tasks 1-6
- Produces: final repository-wide evidence that the new DR naming contract is implemented consistently and that only exact wording mismatches remain to be corrected

**Acceptance Mapping:**
- FR1-FR9
- Acceptance criteria 1-11

- [ ] **Step 1: Run the full regression bundle**

Run:

```bash
bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-dr-filename-contract.sh && bash tests/test-skill-contracts.sh && bash tests/test-package-local.sh && bash tests/test-reference-validation.sh && bash tests/test-doctor-contract.sh && bash tests/test-mvp-acceptance.sh
```

Expected: PASS for all tests. If any assertion fails because repository copy still mentions the old canonical DR naming, fix only the exact text or exact assertion needed to match the approved contract.

- [ ] **Step 2: Rebuild the local package**

Run:

```bash
bash scripts/package-local.sh
```

Expected: prints both local package paths under `dist/` without errors.

- [ ] **Step 3: Run whitespace and patch hygiene verification**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 4: Self-review implementation coverage before handoff**

Check this exact list manually:

```text
- New DR creation now describes `NNN-<tag>-<slug>.md` as the only canonical output.
- `DR ID` is treated as the full basename without `.md`.
- DR title identifier uses `DR-NNN-<tag>` and no slug.
- `DR number` allocation is 3-digit, cross-tag, version-local, and fails at 999.
- `/sdd:dr accept` examples and contract tests use the new full `DR ID`.
- `/sdd:plan` and `/sdd:code` only recognize the new full DR ID syntax.
- The pre-tool-use hook parses `plans/<plan-number>-<dr-id>.md` and does not fall back to spec-mode on illegal code-class DR plans.
- Doctor text compares plan basename minus the leading plan number to the full DR ID.
- Root README and packaged README no longer describe `<tag>-NNNN-<slug>.md` as canonical output.
- Existing tests cover the new fixture, helper logic, hook behavior, doctor wording, and user-facing contract text.
```

Expected: no uncovered spec requirement remains inside the implementation scope.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-common.sh scripts/hooks/pre-tool-use.sh skills/dr/SKILL.md skills/dr/references/dr.md.tmpl skills/plan/SKILL.md skills/code/SKILL.md skills/doctor/SKILL.md README.md scripts/package-local.sh tests/test-common.sh tests/fixtures/valid-project.sh tests/test-common-library.sh tests/test-pre-tool-use.sh tests/test-dr-filename-contract.sh tests/test-skill-contracts.sh tests/test-package-local.sh tests/test-doctor-contract.sh tests/test-mvp-acceptance.sh
git commit -m "test: verify normalized DR filename contract end to end"
```

## Self-Review

- Spec coverage:
  - FR1, FR2, FR3 are covered by Tasks 1-2 through helper allocation, fixture updates, DR skill wording, and DR template title changes.
  - FR4 is covered by Tasks 2, 3, and 6 through static contract assertions, executable DR contract tests, and README/package wording that stop treating the old format as canonical.
  - FR5 and FR6 are covered by Tasks 3, 4, and 6 through plan/code skill wording, executable DR-ID parsing checks, and explicit `plans/NNN-<dr-id>.md` examples.
  - FR7 is covered by Task 5 through the pre-tool-use hook’s exact code-class DR plan parsing and failure behavior.
  - FR8 is covered by Tasks 3, 4, and 5 through doctor wording, contract tests, and hook behavior.
  - FR9 is covered by Tasks 2, 4, and 6 through skills, README, packaged README, and tests.
  - The verification commands from spec section 10 are represented in Task 7.
- Placeholder scan:
  - No `TODO`, `TBD`, `implement later`, `similar to Task N`, or fake path placeholders remain.
  - Every code-editing step contains exact replacement snippets, exact assertions, or exact commands.
- Type consistency:
  - `DR ID` consistently means `NNN-<tag>-<slug>` across helper logic, DR/plan/code/doctor wording, hook parsing, README examples, and test assertions.
  - `DR number` consistently uses three digits and remains separate from the three-digit `plan number`.
  - `DR title identifier` consistently uses `DR-NNN-<tag>` across the DR template, skill text, and fixture examples.

Plan complete and saved to `docs/superpowers/plans/2026-07-18-dr-filename-normalization.md`. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
