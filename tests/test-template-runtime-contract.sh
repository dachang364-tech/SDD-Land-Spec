#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_project="$(mktemp -d)"
error_output="$(mktemp)"
error_status="$(mktemp)"
trap 'rm -rf "$tmp_project" "$error_output" "$error_status"' EXIT
mkdir -p "$tmp_project/.sdd/templates/research"
mkdir -p "$tmp_project/.sdd/templates/prd"
mkdir -p "$tmp_project/.sdd/templates/spec"
mkdir -p "$tmp_project/.sdd/templates/plan"
mkdir -p "$tmp_project/.sdd/templates/dr"
printf '# Research\n' > "$tmp_project/.sdd/templates/research/template.md"
printf '# research quality\n' > "$tmp_project/.sdd/templates/research/quality.standard.md"
printf '# PRD\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"
printf '# DR\n' > "$tmp_project/.sdd/templates/dr/template.md"
printf '# dr quality\n' > "$tmp_project/.sdd/templates/dr/quality.standard.md"

assert_file_exists "$(sdd_require_template_asset "$tmp_project" research template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" research quality.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" prd template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" prd quality.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" spec template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" spec quality.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" spec feasibility.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" plan template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" plan quality.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" plan feasibility.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" dr template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" dr quality.standard.md)"

for asset in template.md quality.standard.md; do
  rm "$tmp_project/.sdd/templates/research/$asset"
  if sdd_require_template_asset "$tmp_project" research "$asset" >"$error_status" 2>"$error_output"; then
    fail "expected missing research $asset to fail"
  fi
  assert_contains "$error_output" "缺少项目模板资产"
  printf '# restored\n' > "$tmp_project/.sdd/templates/research/$asset"
done

for asset in template.md quality.standard.md; do
  rm "$tmp_project/.sdd/templates/prd/$asset"
  if sdd_require_template_asset "$tmp_project" prd "$asset" >"$error_status" 2>"$error_output"; then
    fail "expected missing prd $asset to fail"
  fi
  assert_contains "$error_output" "缺少项目模板资产"
  printf '# restored\n' > "$tmp_project/.sdd/templates/prd/$asset"
done

for asset in template.md quality.standard.md feasibility.standard.md; do
  rm "$tmp_project/.sdd/templates/spec/$asset"
  if sdd_require_template_asset "$tmp_project" spec "$asset" >"$error_status" 2>"$error_output"; then
    fail "expected missing spec $asset to fail"
  fi
  assert_contains "$error_output" "缺少项目模板资产"
  printf '# restored\n' > "$tmp_project/.sdd/templates/spec/$asset"
done

for asset in template.md quality.standard.md feasibility.standard.md; do
  rm "$tmp_project/.sdd/templates/plan/$asset"
  if sdd_require_template_asset "$tmp_project" plan "$asset" >"$error_status" 2>"$error_output"; then
    fail "expected missing plan $asset to fail"
  fi
  assert_contains "$error_output" "缺少项目模板资产"
  printf '# restored\n' > "$tmp_project/.sdd/templates/plan/$asset"
done

for asset in template.md quality.standard.md; do
  rm "$tmp_project/.sdd/templates/dr/$asset"
  if sdd_require_template_asset "$tmp_project" dr "$asset" >"$error_status" 2>"$error_output"; then
    fail "expected missing dr $asset to fail"
  fi
  assert_contains "$error_output" "缺少项目模板资产"
  printf '# restored\n' > "$tmp_project/.sdd/templates/dr/$asset"
done

assert_not_contains "hooks/hooks.json" '"PostToolUse"'
assert_file_not_exists "scripts/hooks/post-tool-use.sh"
assert_file_not_exists "scripts/lib/sdd-review-runner.sh"
assert_contains "skills/review/SKILL.md" '/sdd:review'
assert_contains "skills/review/SKILL.md" 'doc-reviewer'
assert_contains "skills/spec/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/plan/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'

printf 'PASS: template runtime contract\n'
