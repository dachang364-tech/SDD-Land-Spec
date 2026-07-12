#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

for skill in init new research prd spec plan code dr status doctor archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

assert_contains "skills/init/SKILL.md" "description: Initialize SDD project structure"
assert_contains "skills/init/SKILL.md" "docs/CONSTITUTION.md 已存在"
assert_contains "skills/init/SKILL.md" "不要创建 .sdd/state.json"

assert_contains "skills/new/SKILL.md" "description: Create the unique active SDD version directory"
assert_contains "skills/new/SKILL.md" "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
assert_contains "skills/new/SKILL.md" "docs/vX.Y.Z/specs/"

assert_contains "skills/research/SKILL.md" "description: Create project-level SDD research notes"
assert_file_exists "skills/research/references/research.md.tmpl"
assert_contains "skills/research/references/research.md.tmpl" "# 研究：<topic>"

assert_contains "skills/prd/SKILL.md" "description: Create the product requirements document"
assert_file_exists "skills/prd/references/prd.md.tmpl"
assert_contains "skills/prd/references/prd.md.tmpl" "# PRD：<产品/版本名>"
assert_contains "skills/prd/references/prd.md.tmpl" "## 6. 成功标准"

assert_contains "skills/spec/SKILL.md" "description: Create or revise the functional specification"
assert_file_exists "skills/spec/references/spec.md.tmpl"
assert_contains "skills/spec/references/spec.md.tmpl" "- 状态：draft"
assert_contains "skills/spec/SKILL.md" '用户确认后，将状态切换为 `approved`'

assert_contains "skills/plan/SKILL.md" "description: Create an implementation plan from approved spec or accepted code-class DR"
assert_contains "skills/plan/SKILL.md" "^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$"
assert_contains "skills/plan/SKILL.md" "文档类 DR 不生成 Implementation Plan"
assert_contains "skills/plan/SKILL.md" "Technical Planning Dialogue"
assert_file_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/plan/references/plan.md.tmpl" "## Technical Design"
assert_contains "skills/plan/references/plan.md.tmpl" "## Implementation Tasks"

assert_contains "skills/code/SKILL.md" "description: Execute an SDD implementation plan"
assert_contains "skills/code/SKILL.md" '高质量模式：`superpowers:subagent-driven-development`'
assert_contains "skills/code/SKILL.md" '快速模式：`superpowers:executing-plans`'
assert_contains "skills/code/SKILL.md" 'plan 状态从 `planned` 切换为 `coding`'
assert_contains "skills/code/SKILL.md" 'verification 通过后，将 plan 状态切换为 `done`'

assert_contains "skills/dr/SKILL.md" "description: Create, accept, or dismiss SDD decision records"
assert_contains "skills/dr/SKILL.md" "fix | feat | chg | arch | spec | doc | typo"
assert_contains "skills/dr/SKILL.md" "drafting → accepted"
assert_contains "skills/dr/SKILL.md" "accepted 或 closed DR 不允许 dismiss"
assert_file_exists "skills/dr/references/dr.md.tmpl"
assert_contains "skills/dr/references/dr.md.tmpl" "- closed_reason: null"

assert_contains "skills/status/SKILL.md" "description: Show current SDD version status and next-step guidance"
assert_contains "skills/status/SKILL.md" "展示当前版本状态与下一步建议"

assert_contains "skills/doctor/SKILL.md" "description: Diagnose SDD plugin installation and project consistency"
assert_contains "skills/doctor/SKILL.md" ".claude-plugin/plugin.json"
assert_contains "skills/doctor/SKILL.md" "done 的代码类 DR plan 对应 DR 是否仍 accepted"

assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" '所有 `plans/*.md` 状态为 `done`'
assert_contains "skills/archive/SKILL.md" "docs/vX.Y.Z/ → docs/archive/vX.Y.Z/"

printf 'PASS: skill contracts\n'
