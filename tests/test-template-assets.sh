#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_plugin="$(mktemp -d)"
tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project"' EXIT

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
assert_not_contains "scripts/lib/sdd-template-assets.sh" "default-backend"
assert_contains "scripts/lib/sdd-template-assets.sh" "printf 'backend\\n'"
assert_contains "scripts/lib/sdd-template-assets.sh" 'mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"'
assert_not_contains "scripts/lib/sdd-template-assets.sh" 'cp -R -n "$pack_root/dr/." "$target_root/dr/" || true'
assert_contains "scripts/lib/sdd-template-assets.sh" '模板包缺少必需目录'
assert_contains "scripts/lib/sdd-template-assets.sh" 'sdd_ensure_project_claude'
assert_contains "scripts/lib/sdd-template-assets.sh" 'assets/project/CLAUDE.md'

mkdir -p "$tmp_plugin/assets/template-packs/backend/research"
mkdir -p "$tmp_plugin/assets/template-packs/backend/prd"
mkdir -p "$tmp_plugin/assets/template-packs/backend/spec"
mkdir -p "$tmp_plugin/assets/template-packs/backend/plan"
mkdir -p "$tmp_plugin/assets/template-packs/backend/dr"
printf '# Research\n' > "$tmp_plugin/assets/template-packs/backend/research/template.md"
printf '# research quality\n' > "$tmp_plugin/assets/template-packs/backend/research/quality.standard.md"
printf '# PRD\n' > "$tmp_plugin/assets/template-packs/backend/prd/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/backend/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_plugin/assets/template-packs/backend/spec/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/backend/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_plugin/assets/template-packs/backend/plan/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/backend/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/backend/plan/feasibility.standard.md"
printf '# DR\n' > "$tmp_plugin/assets/template-packs/backend/dr/template.md"
printf '# dr quality\n' > "$tmp_plugin/assets/template-packs/backend/dr/quality.standard.md"
mkdir -p "$tmp_plugin/assets/project"
printf '# Project Claude\n' > "$tmp_plugin/assets/project/CLAUDE.md"

sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_file_exists "$tmp_project/CLAUDE.md"
assert_contains "$tmp_project/CLAUDE.md" '# Project Claude'
printf '# Custom Claude\n' > "$tmp_project/CLAUDE.md"
sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_contains "$tmp_project/CLAUDE.md" '# Custom Claude'

sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "backend"
assert_file_exists "$tmp_project/.sdd/templates/research/template.md"
assert_file_exists "$tmp_project/.sdd/templates/research/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/prd/template.md"
assert_file_exists "$tmp_project/.sdd/templates/prd/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/template.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/template.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/feasibility.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/dr/template.md"
assert_file_exists "$tmp_project/.sdd/templates/dr/quality.standard.md"
printf '# Project PRD customization\n' > "$tmp_project/.sdd/templates/prd/template.md"
rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
rm "$tmp_project/.sdd/templates/dr/quality.standard.md"
sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "backend"
assert_contains "$tmp_project/.sdd/templates/prd/template.md" '# Project PRD customization'
assert_file_exists "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
assert_contains "$tmp_project/.sdd/templates/spec/feasibility.standard.md" '# feasibility'
assert_file_exists "$tmp_project/.sdd/templates/dr/quality.standard.md"
assert_contains "$tmp_project/.sdd/templates/dr/quality.standard.md" '# dr quality'

broken_plugin="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project" "$broken_plugin"' EXIT
mkdir -p "$broken_plugin/assets/template-packs/backend/research"
mkdir -p "$broken_plugin/assets/template-packs/backend/prd"
mkdir -p "$broken_plugin/assets/template-packs/backend/spec"
mkdir -p "$broken_plugin/assets/template-packs/backend/plan"
printf '# Research\n' > "$broken_plugin/assets/template-packs/backend/research/template.md"
printf '# research quality\n' > "$broken_plugin/assets/template-packs/backend/research/quality.standard.md"
printf '# PRD\n' > "$broken_plugin/assets/template-packs/backend/prd/template.md"
printf '# quality\n' > "$broken_plugin/assets/template-packs/backend/prd/quality.standard.md"
printf '# Spec\n' > "$broken_plugin/assets/template-packs/backend/spec/template.md"
printf '# quality\n' > "$broken_plugin/assets/template-packs/backend/spec/quality.standard.md"
printf '# feasibility\n' > "$broken_plugin/assets/template-packs/backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$broken_plugin/assets/template-packs/backend/plan/template.md"
printf '# quality\n' > "$broken_plugin/assets/template-packs/backend/plan/quality.standard.md"
printf '# feasibility\n' > "$broken_plugin/assets/template-packs/backend/plan/feasibility.standard.md"

if sdd_copy_template_pack "$broken_plugin" "$tmp_project" "backend"; then
  fail "expected sdd_copy_template_pack to fail when a required template subdirectory is missing"
fi

missing_claude_plugin="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project" "$broken_plugin" "$missing_claude_plugin"' EXIT
mkdir -p "$missing_claude_plugin/assets/project"
if sdd_ensure_project_claude "$missing_claude_plugin" "$tmp_project"; then
  fail "expected sdd_ensure_project_claude to fail when project CLAUDE asset is missing"
fi

printf 'PASS: template assets\n'
