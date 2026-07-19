# doc-reviewer Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a real Claude Code `doc-reviewer` agent, align the review skill with its stable agent identity, include it in local plugin packages, and verify the installed archive contains the agent definition.

**Architecture:** Keep `skills/review/SKILL.md` as the `/sdd:review` orchestration contract. Add the independently discoverable `agents/doc-reviewer.md` as the execution unit; it consumes the existing structured JSON handoff and returns exactly one result object conforming to the existing reviewer schema. Extend packaging and contract tests so source and released archives cannot silently diverge.

**Tech Stack:** Claude Code plugin Markdown agent definitions, YAML frontmatter, Bash contract tests, ZIP/TAR packaging, JSON Schema.

## Global Constraints

- Use the official plugin component convention: `agents/doc-reviewer.md` at the plugin root.
- Do not add a custom `agents` path to `.claude-plugin/plugin.json` unless the implementation requires a non-default location.
- Preserve the existing `skills/review/references/reviewer-result.schema.json` as the machine-output contract.
- The agent must return one JSON object only; no Markdown fences, prose, or multiple JSON objects.
- The agent must perform admission checks before review or repair and return `blocked: true`, `iterations: 0`, without editing the document when admission fails.
- The package must include `agents/doc-reviewer.md` in both TAR and ZIP outputs.
- Do not change unrelated document workflows or template-pack behavior.

---

### Task 1: Add the real doc-reviewer agent definition

**Files:**
- Create: `agents/doc-reviewer.md`
- Test: `tests/test-document-reviewer.sh`

**Interfaces:**
- Consumes: the JSON handoff defined by `skills/review/SKILL.md`, with `document_path`, `document_type`, `mode`, `template_path`, `standard_path`, `repair_policy`, `upstream_paths`, `invocation_source`, and `max_rounds`.
- Produces: one JSON object matching `skills/review/references/reviewer-result.schema.json`; the stable agent identity is `doc-reviewer`.

- [ ] **Step 1: Write failing contract assertions**

Add assertions to `tests/test-document-reviewer.sh` for:

```bash
assert_file_exists "agents/doc-reviewer.md"
assert_contains "agents/doc-reviewer.md" "name: doc-reviewer"
assert_contains "agents/doc-reviewer.md" "description:"
assert_contains "agents/doc-reviewer.md" "document_path"
assert_contains "agents/doc-reviewer.md" "document_type"
assert_contains "agents/doc-reviewer.md" "standard_path"
assert_contains "agents/doc-reviewer.md" "reviewer-result.schema.json"
assert_contains "agents/doc-reviewer.md" '"blocked": true'
assert_contains "agents/doc-reviewer.md" '"iterations": 0'
assert_contains "agents/doc-reviewer.md" "exactly one JSON object"
```

Run:

```bash
bash tests/test-document-reviewer.sh
```

Expected: FAIL because `agents/doc-reviewer.md` does not exist.

- [ ] **Step 2: Add the minimal agent definition**

Create `agents/doc-reviewer.md` with this structure and concrete behavior:

```markdown
---
name: doc-reviewer
description: Review one PRD, spec, or plan document against its project template and standard, apply only permitted repairs, and return one schema-compliant JSON result.
model: sonnet
---

# doc-reviewer

You are the document review execution agent for the SDD plugin.

## Input contract

Read exactly one JSON input object from the caller. It must contain:

- `document_path`
- `document_type`: `prd`, `spec`, or `plan`
- `mode`: `quality` or `feasibility`
- `template_path`
- `standard_path`
- `repair_policy`
- `upstream_paths`
- `invocation_source`
- `max_rounds`: positive integer

Treat paths as project-relative paths. Read the target document, the referenced template, the referenced standard, and every declared upstream document before evaluating it. Do not substitute plugin-bundled templates for project paths.

## Admission check

Before reviewing or editing anything, verify that:

1. The target exists, is readable, is a regular non-empty file.
2. `document_type` and `mode` are supported.
3. `template_path` and `standard_path` exist, are readable, and are under `.sdd/templates/<document_type>/`.
4. The target contains the required template sections, required metadata, and a `## 文档引用` section, and is not an untouched placeholder template.
5. Every `upstream_paths` dependency exists and satisfies the document type's minimum prerequisite.
6. `repair_policy`, `invocation_source`, and positive `max_rounds` are present and usable.

If any check fails, do not enter the review loop and do not edit the target. Return one JSON object matching `skills/review/references/reviewer-result.schema.json` with `passed: false`, `blocked: true`, `iterations: 0`, the admission failure in `blocking_items`, and a complete `user_receipt`.

## Review and repair loop

For the selected mode, evaluate the document against the referenced standard, then apply only repairs allowed by `repair_policy`. Low-risk structural and clarity fixes may be applied directly when permitted. Semantic ambiguity, architecture changes, or other high-risk changes must be reported as `candidate_rewrites` and require user confirmation. Re-read and re-evaluate after each repair. Stop when the mode passes with no blocking items, `max_rounds` is reached, user confirmation is required, or no valid improvement remains.

Never delete user intent. Never change files outside the target document. Preserve the requested mode and document type in the output.

## Output contract

Return exactly one JSON object and nothing else. Do not use Markdown fences. The object must validate against `skills/review/references/reviewer-result.schema.json` and contain all required fields:

- `document_type`
- `mode`
- `passed`
- `blocked`
- `score_or_grade`
- `blocking_items`
- `auto_repairs`
- `remaining_issues`
- `requires_user_confirmation`
- `candidate_rewrites`
- `iterations`
- `reached_max_iterations`
- `stopped_for_no_improvement`
- `user_receipt`

`user_receipt` must contain `document_type`, `executed_modes`, `iterations`, `auto_repairs_summary`, `remaining_or_confirmation_items`, `blocked`, and `quality_summary`.
```

- [ ] **Step 3: Run the focused test**

Run:

```bash
bash tests/test-document-reviewer.sh
```

Expected: PASS.

- [ ] **Step 4: Commit the agent definition and test**

```bash
git add agents/doc-reviewer.md tests/test-document-reviewer.sh
git commit -m "feat: add doc-reviewer plugin agent"
```

---

### Task 2: Align the review orchestration contract with the real agent

**Files:**
- Modify: `skills/review/SKILL.md:17-37`
- Modify: `tests/test-document-reviewer.sh`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: the `doc-reviewer` agent identity from Task 1.
- Produces: an explicit `/sdd:review` handoff that names `doc-reviewer` as the Claude Code agent, while retaining the existing input/output and aggregation rules.

- [ ] **Step 1: Add failing identity assertions**

Add assertions:

```bash
assert_contains "skills/review/SKILL.md" "doc-reviewer"
assert_not_contains "skills/review/SKILL.md" "doc Reviewer-Subagent"
assert_contains "tests/test-skill-contracts.sh" "agents/doc-reviewer.md"
```

Run:

```bash
bash tests/test-document-reviewer.sh
bash tests/test-skill-contracts.sh
```

Expected: the new identity assertions fail until the skill and contract test are updated.

- [ ] **Step 2: Update the skill wording**

Replace the conceptual `doc Reviewer-Subagent` references with explicit Claude Code agent wording:

```markdown
命令层或手动 `/sdd:review` 必须启动插件提供的 `doc-reviewer` agent。每次调用只评审一个 `mode`，并将以下 JSON 对象作为 agent 唯一的输入载荷。
```

Add a short identity requirement after the handoff block:

```markdown
`doc-reviewer` 必须解析为插件根目录 `agents/doc-reviewer.md` 定义的 Claude Code agent；调用方不得用普通文本模拟该 agent，也不得把 review 逻辑替换为当前主 agent 的非隔离推理。
```

Keep the existing schema validation, admission, loop, repair policy, and aggregation semantics unchanged.

- [ ] **Step 3: Add source/package identity assertions**

Extend `tests/test-skill-contracts.sh` to assert:

```bash
assert_file_exists "agents/doc-reviewer.md"
assert_contains "skills/review/SKILL.md" "启动插件提供的 `doc-reviewer` agent"
assert_contains "skills/review/SKILL.md" "agents/doc-reviewer.md"
```

- [ ] **Step 4: Run focused contract tests**

```bash
bash tests/test-document-reviewer.sh
bash tests/test-skill-contracts.sh
bash tests/test-review-output-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the orchestration alignment**

```bash
git add skills/review/SKILL.md tests/test-document-reviewer.sh tests/test-skill-contracts.sh
git commit -m "fix: bind review orchestration to doc-reviewer agent"
```

---

### Task 3: Include agents in local plugin packages

**Files:**
- Modify: `scripts/package-local.sh:64-67`
- Modify: `tests/test-package-local.sh:29-38`

**Interfaces:**
- Consumes: `agents/doc-reviewer.md` from Task 1.
- Produces: `sdd-local/agents/doc-reviewer.md` in both generated archive formats.

- [ ] **Step 1: Add failing archive assertions**

Add these assertions after the existing plugin metadata checks:

```bash
assert_contains "$archive_contents" "${package_root}/agents/doc-reviewer.md"
assert_contains "$zip_listing" "${package_root}/agents/doc-reviewer.md"
```

Run:

```bash
bash tests/test-package-local.sh
```

Expected: FAIL because the current copy list excludes `agents`.

- [ ] **Step 2: Extend the package copy list**

Change the package source loop in `scripts/package-local.sh` from:

```bash
for path in .claude-plugin CONSTITUTION.default.md LICENSE hooks scripts skills assets; do
```

to:

```bash
for path in .claude-plugin CONSTITUTION.default.md LICENSE hooks scripts skills agents assets; do
```

Do not alter archive naming, metadata synchronization, exclusions, or generated README behavior.

- [ ] **Step 3: Run the package test**

```bash
bash tests/test-package-local.sh
```

Expected: PASS and both archive listings contain `sdd-local/agents/doc-reviewer.md`.

- [ ] **Step 4: Inspect archive contents directly**

```bash
unzip -Z1 "dist/sdd-plugin-v$(node -p "require('./.claude-plugin/plugin.json').version").zip" | grep '/agents/doc-reviewer.md$'
tar -tzf "dist/sdd-plugin-v$(node -p "require('./.claude-plugin/plugin.json').version").tar.gz" | grep '/agents/doc-reviewer.md$'
```

Expected: one matching path from each command.

- [ ] **Step 5: Commit packaging support**

```bash
git add scripts/package-local.sh tests/test-package-local.sh
git commit -m "build: package doc-reviewer agent"
```

---

### Task 4: Complete plugin integrity and documentation checks

**Files:**
- Modify: `skills/doctor/SKILL.md`
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `tests/test-skill-contracts.sh`
- Modify: `tests/test-review-output-contract.sh`

**Interfaces:**
- Consumes: the packaged/default `agents/doc-reviewer.md` component.
- Produces: explicit integrity guidance and manual verification for agent discovery and archive contents.

- [ ] **Step 1: Add failing documentation assertions**

Add assertions:

```bash
assert_contains "README.md" "agents/doc-reviewer.md"
assert_contains "TESTING.md" "agents/doc-reviewer.md"
assert_contains "skills/doctor/SKILL.md" "agents/doc-reviewer.md"
```

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-review-output-contract.sh
```

Expected: FAIL until the docs and doctor contract mention the agent.

- [ ] **Step 2: Update doctor integrity checks**

Add a plugin-level check to `skills/doctor/SKILL.md`:

```markdown
## Reviewer agent checks

- 检查插件根目录 `agents/doc-reviewer.md` 是否存在。
- 检查 agent frontmatter 包含 `name: doc-reviewer` 和 `description`。
- 检查最终 ZIP/TAR 包包含 `agents/doc-reviewer.md`。
- 如缺失，报告 `缺少 doc-reviewer agent`，并阻止宣称 reviewer runtime 完整。
```

- [ ] **Step 3: Update user-facing and manual verification docs**

In `README.md`, add `agents/` to the plugin structure and explain that `/sdd:review` uses the installed `doc-reviewer` agent.

In `TESTING.md`, add a manual check:

```text
确认插件安装后的组件目录包含 agents/doc-reviewer.md，并执行 /sdd:review，确认 reviewer 使用该 agent 而不是仅依据 review skill 文本模拟执行。
```

- [ ] **Step 4: Run documentation contracts**

```bash
bash tests/test-skill-contracts.sh
bash tests/test-review-output-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit integrity documentation**

```bash
git add skills/doctor/SKILL.md README.md TESTING.md tests/test-skill-contracts.sh tests/test-review-output-contract.sh
git commit -m "docs: document doc-reviewer plugin integrity"
```

---

### Task 5: Run the complete verification suite and package the release artifacts

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-doc-reviewer-agent-implementation.md` only if recording verification notes is required.

**Interfaces:**
- Consumes: all changes from Tasks 1-4.
- Produces: passing focused/full contract tests and regenerated local ZIP/TAR artifacts.

- [ ] **Step 1: Run focused agent and review tests**

```bash
bash tests/test-document-reviewer.sh
bash tests/test-review-output-contract.sh
bash tests/test-skill-contracts.sh
```

Expected: PASS for all three.

- [ ] **Step 2: Run package verification**

```bash
bash tests/test-package-local.sh
```

Expected: PASS; archive listings contain `sdd-local/agents/doc-reviewer.md`.

- [ ] **Step 3: Run the repository regression suite**

```bash
bash tests/test-template-assets.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-common-library.sh
bash tests/test-reference-validation.sh
bash tests/test-doctor-contract.sh
bash tests/test-mvp-acceptance.sh
bash tests/test-pre-tool-use.sh
bash scripts/package-local.sh
bash tests/test-package-local.sh
git diff --check
```

Expected: every test passes and `git diff --check` produces no output.

- [ ] **Step 4: Verify final package contents**

```bash
version="$(node -p "require('./.claude-plugin/plugin.json').version")"
unzip -Z1 "dist/sdd-plugin-v${version}.zip" | grep -E '^sdd-local/(agents/doc-reviewer\.md|\.claude-plugin/plugin\.json)$'
tar -tzf "dist/sdd-plugin-v${version}.tar.gz" | grep -E '^sdd-local/(agents/doc-reviewer\.md|\.claude-plugin/plugin\.json)$'
```

Expected: both commands show the agent and plugin metadata paths.

- [ ] **Step 5: Record verification results**

Append a dated `Execution Verification Notes` section to this plan with the exact commands that passed and the generated archive paths. Do not claim a live `/sdd:review` execution was verified unless it was actually run through an installed Claude Code plugin.

- [ ] **Step 6: Commit verification notes if changed**

```bash
git add docs/superpowers/plans/2026-07-20-doc-reviewer-agent-implementation.md
 git commit -m "test: verify doc-reviewer packaging"
```

## Execution Verification Notes

- [x] `bash tests/test-document-reviewer.sh`
- [x] `bash tests/test-review-output-contract.sh`
- [x] `bash tests/test-skill-contracts.sh`
- [x] `bash tests/test-package-local.sh`
- [x] `bash tests/test-template-assets.sh`
- [x] `bash tests/test-template-runtime-contract.sh`
- [x] `bash tests/test-common-library.sh`
- [x] `bash tests/test-reference-validation.sh`
- [x] `bash tests/test-doctor-contract.sh`
- [x] `bash tests/test-mvp-acceptance.sh`
- [x] `bash tests/test-pre-tool-use.sh`
- [x] `bash scripts/package-local.sh`
- [x] `git diff --check`
- [x] `unzip -Z1 "dist/sdd-plugin-v0.4.0.zip" | grep -E '^sdd-local/(agents/doc-reviewer\.md|\.claude-plugin/plugin\.json)$'`
- [x] `tar -tzf "dist/sdd-plugin-v0.4.0.tar.gz" | grep -E '^sdd-local/(agents/doc-reviewer\.md|\.claude-plugin/plugin\.json)$'`

Generated artifacts:

- `dist/sdd-plugin-v0.4.0.zip`
- `dist/sdd-plugin-v0.4.0.tar.gz`

Note: this verification confirms source contracts, package contents, and archive integrity. It does not claim a live installed-plugin `/sdd:review` execution was verified in Claude Code.
