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

assert_file_exists "assets/project/CLAUDE.md"
assert_contains "skills/review/SKILL.md" '/sdd:review'
assert_contains "skills/review/SKILL.md" 'doc-reviewer'
for skill in research prd dr spec plan; do
  assert_contains "skills/$skill/SKILL.md" '/sdd:review'
done
assert_contains "skills/init/SKILL.md" '将所选模板包中的 `research / PRD / Spec / Plan / dr` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`'
assert_contains "skills/init/SKILL.md" '`${CLAUDE_PROJECT_DIR}/CLAUDE.md` 缺失'
assert_contains "skills/init/SKILL.md" '不处理 `AGENTS.md`'
assert_contains "skills/init/SKILL.md" 'sdd_ensure_project_claude'
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`'
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`'
assert_contains "skills/research/SKILL.md" '`research` 的 review mode 为 `quality`'
assert_contains "README.md" '.sdd/templates/research/'
assert_contains "README.md" '.sdd/templates/dr/'
assert_contains "README.md" '默认使用 `backend`'
assert_contains "README.md" '`research -> quality`'
assert_contains "README.md" '`dr -> quality`'
assert_contains "README.md" '只接入 `quality`，不接入 `feasibility`'
assert_contains "TESTING.md" '.sdd/templates/research/'
assert_contains "TESTING.md" '.sdd/templates/dr/'
assert_contains "TESTING.md" '默认使用 `backend`'
assert_contains "TESTING.md" '`research`、`prd`、`dr` create 只触发 `quality`；`spec` 与 `plan` create 按顺序触发 `quality -> feasibility`。'
assert_contains "skills/prd/SKILL.md" '如果项目模板资产缺失，则直接失败'
assert_contains "skills/spec/SKILL.md" '如果项目模板资产缺失，则直接失败'
assert_contains "skills/plan/SKILL.md" '如果项目模板资产缺失，则直接失败'

assert_not_contains "skills/research/SKILL.md" 'skills/research/references/research.md.tmpl'
assert_not_contains "skills/plan/SKILL.md" 'skills/plan/references/plan.md.tmpl'
assert_not_contains "README.md" 'default-backend'
assert_not_contains "TESTING.md" 'default-backend'
assert_not_contains "assets/project/CLAUDE.md" '.sdd/templates/research/'
assert_not_contains "assets/project/CLAUDE.md" '.superpowers/'
assert_not_contains "assets/project/CLAUDE.md" '/Users/apple/'
assert_contains "scripts/lib/sdd-template-assets.sh" 'mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"'
assert_not_contains "scripts/lib/sdd-template-assets.sh" 'cp -R -n "$pack_root/dr/." "$target_root/dr/" || true'
assert_contains "scripts/lib/sdd-template-assets.sh" '模板包缺少必需目录'

printf 'PASS: template governance matrix\n'
