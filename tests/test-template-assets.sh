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
printf '# Project PRD customization\n' > "$tmp_project/.sdd/templates/prd/template.md"
rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "default-backend"
assert_contains "$tmp_project/.sdd/templates/prd/template.md" '# Project PRD customization'
assert_file_exists "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
assert_contains "$tmp_project/.sdd/templates/spec/feasibility.standard.md" '# feasibility'

printf 'PASS: template assets\n'
