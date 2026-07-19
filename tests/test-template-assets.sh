#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_plugin="$(mktemp -d)"
tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project"' EXIT

mkdir -p "$tmp_plugin/assets/template-packs/default-backend/prd"
mkdir -p "$tmp_plugin/assets/template-packs/default-backend/spec"
mkdir -p "$tmp_plugin/assets/template-packs/default-backend/plan"
printf '# PRD\n' > "$tmp_plugin/assets/template-packs/default-backend/prd/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/feasibility.standard.md"

sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "default-backend"
assert_file_exists "$tmp_project/.sdd/templates/prd/template.md"
assert_file_exists "$tmp_project/.sdd/templates/prd/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/template.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/template.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/feasibility.standard.md"

printf 'PASS: template assets\n'
