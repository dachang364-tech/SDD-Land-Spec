#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_project"' EXIT
mkdir -p "$tmp_project/.sdd/templates/prd"
mkdir -p "$tmp_project/.sdd/templates/spec"
mkdir -p "$tmp_project/.sdd/templates/plan"
printf '# PRD\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"

assert_file_exists "$(sdd_require_template_asset "$tmp_project" prd template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" spec feasibility.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" plan quality.standard.md)"

rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
if sdd_require_template_asset "$tmp_project" spec feasibility.standard.md >/tmp/sdd-spec-template.out 2>/tmp/sdd-spec-template.err; then
  fail "expected missing spec feasibility standard to fail"
fi
assert_contains "/tmp/sdd-spec-template.err" "缺少项目模板资产"

printf 'PASS: template runtime contract\n'
