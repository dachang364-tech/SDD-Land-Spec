#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "assets/template-packs/backend/research/template.md"
assert_file_exists "assets/template-packs/backend/research/quality.standard.md"
assert_file_exists "assets/template-packs/backend/prd/template.md"
assert_file_exists "assets/template-packs/backend/prd/quality.standard.md"
assert_file_exists "assets/template-packs/backend/spec/template.md"
assert_file_exists "assets/template-packs/backend/spec/quality.standard.md"
assert_file_exists "assets/template-packs/backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/plan/template.md"
assert_file_exists "assets/template-packs/backend/plan/quality.standard.md"
assert_file_exists "assets/template-packs/backend/plan/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/dr/template.md"
assert_file_exists "assets/template-packs/backend/dr/quality.standard.md"

assert_contains "skills/review/SKILL.md" 'dr -> quality'
assert_contains "skills/review/SKILL.md" '`research`、`prd` 与 `dr` 只有 `quality`'
assert_contains "skills/review/SKILL.md" '`research` 不要求 `## 文档引用` 表'
assert_contains "skills/init/SKILL.md" '将所选模板包中的 `research / PRD / Spec / Plan / dr` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`'
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`'
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`'
assert_contains "skills/research/SKILL.md" '`research` 只接入 `quality`，不接入 `feasibility`'
assert_contains "README.md" '.sdd/templates/research/'
assert_contains "README.md" '.sdd/templates/dr/'
assert_contains "README.md" '默认使用 `backend`'
assert_contains "README.md" '`research -> quality`'
assert_contains "README.md" '`dr -> quality`'
assert_contains "README.md" '只接入 `quality`，不接入 `feasibility`'
assert_contains "TESTING.md" '.sdd/templates/research/'
assert_contains "TESTING.md" '.sdd/templates/dr/'
assert_contains "TESTING.md" '默认使用 `backend`'
assert_contains "TESTING.md" '`research` 与 `prd` 只触发 `quality`；`dr` 只触发 `quality`；`spec` 与 `plan` 按顺序触发 `quality -> feasibility`'

assert_not_contains "skills/research/SKILL.md" 'skills/research/references/research.md.tmpl'
assert_not_contains "skills/plan/SKILL.md" 'skills/plan/references/plan.md.tmpl'
assert_not_contains "README.md" 'default-backend'
assert_not_contains "TESTING.md" 'default-backend'
assert_contains "scripts/lib/sdd-template-assets.sh" 'mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"'
assert_not_contains "scripts/lib/sdd-template-assets.sh" 'cp -R -n "$pack_root/dr/." "$target_root/dr/" || true'
assert_contains "scripts/lib/sdd-template-assets.sh" '模板包缺少必需目录'

printf 'PASS: template governance matrix\n'
