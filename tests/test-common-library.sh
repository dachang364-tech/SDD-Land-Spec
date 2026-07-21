#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh
. scripts/lib/sdd-template-assets.sh

plugin_tmp_assets="$(mktemp -d)"
project_tmp_assets="$(mktemp -d)"
trap 'rm -rf "${tmp:-}" "$plugin_tmp_assets" "$project_tmp_assets"' EXIT
mkdir -p "$plugin_tmp_assets/assets/template-packs/backend/research"
mkdir -p "$plugin_tmp_assets/assets/template-packs/backend/prd"
mkdir -p "$plugin_tmp_assets/assets/template-packs/backend/spec"
mkdir -p "$plugin_tmp_assets/assets/template-packs/backend/plan"
mkdir -p "$plugin_tmp_assets/assets/template-packs/backend/dr"
printf '# Research\n' > "$plugin_tmp_assets/assets/template-packs/backend/research/template.md"
printf '# research quality\n' > "$plugin_tmp_assets/assets/template-packs/backend/research/quality.standard.md"
printf '# PRD\n' > "$plugin_tmp_assets/assets/template-packs/backend/prd/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/backend/prd/quality.standard.md"
printf '# Spec\n' > "$plugin_tmp_assets/assets/template-packs/backend/spec/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/backend/spec/quality.standard.md"
printf '# feasibility\n' > "$plugin_tmp_assets/assets/template-packs/backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$plugin_tmp_assets/assets/template-packs/backend/plan/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/backend/plan/quality.standard.md"
printf '# feasibility\n' > "$plugin_tmp_assets/assets/template-packs/backend/plan/feasibility.standard.md"
printf '# DR\n' > "$plugin_tmp_assets/assets/template-packs/backend/dr/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/backend/dr/quality.standard.md"

pack_name="$(sdd_default_template_pack)"
[[ "$pack_name" == "backend" ]] || fail "expected backend, got $pack_name"

pack_root="$(sdd_template_pack_root "$plugin_tmp_assets" "backend")"
[[ "$pack_root" == "$plugin_tmp_assets/assets/template-packs/backend" ]] || fail "expected default pack root, got $pack_root"

list_output="$(sdd_list_template_packs "$plugin_tmp_assets")"
[[ "$list_output" == "backend" ]] || fail "expected backend listing, got $list_output"

sdd_copy_template_pack "$plugin_tmp_assets" "$project_tmp_assets" "backend"
assert_file_exists "$project_tmp_assets/.sdd/templates/research/template.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/research/quality.standard.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/prd/template.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/spec/feasibility.standard.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/plan/quality.standard.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/dr/template.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/dr/quality.standard.md"

project_templates_root="$(sdd_project_templates_root "$project_tmp_assets")"
[[ "$project_templates_root" == "$project_tmp_assets/.sdd/templates" ]] || fail "expected project templates root, got $project_templates_root"

prd_template="$(sdd_require_template_asset "$project_tmp_assets" "prd" "template.md")"
[[ "$prd_template" == "$project_tmp_assets/.sdd/templates/prd/template.md" ]] || fail "expected prd template path, got $prd_template"

if sdd_require_template_asset "$project_tmp_assets" "spec" "missing.standard.md" >/tmp/sdd-missing-template.out 2>/tmp/sdd-missing-template.err; then
  fail "expected missing template asset to fail"
fi
assert_contains "/tmp/sdd-missing-template.err" "缺少项目模板资产"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" "$plugin_tmp_assets" "$project_tmp_assets"' EXIT

bash tests/fixtures/valid-project.sh "$tmp/valid"

status="$(sdd_read_status "$tmp/valid/docs/versions/v0.1.0/spec/spec.md")"
[[ "$status" == "approved" ]] || fail "expected approved status, got $status"

active="$(sdd_active_version_dir "$tmp/valid")"
[[ "$active" == "docs/versions/v0.1.0" ]] || fail "expected docs/versions/v0.1.0, got $active"

state="$(sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" state)"
[[ "$state" == "active" ]] || fail "expected active state, got $state"

version="$(sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" version)"
[[ "$version" == "v0.1.0" ]] || fail "expected v0.1.0, got $version"

if PATH=/nonexistent sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" state >/tmp/sdd-missing-python.out 2>/tmp/sdd-missing-python.err; then
  fail "expected missing python3 to fail"
fi
assert_contains "/tmp/sdd-missing-python.err" "需要 python3"

printf '{ invalid json\n' > "$tmp/invalid-state.json"
if sdd_state_field "$tmp/invalid-state.json" state >/tmp/sdd-invalid-json.out 2>/tmp/sdd-invalid-json.err; then
  fail "expected invalid JSON to fail"
fi
assert_contains "/tmp/sdd-invalid-json.err" "state.json 无法解析"

if sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" missing_field >/tmp/sdd-missing-field.out 2>/tmp/sdd-missing-field.err; then
  fail "expected missing state field to fail"
fi
assert_contains "/tmp/sdd-missing-field.err" "state.json 缺少字段"

number="$(sdd_next_plan_number "$tmp/valid/docs/versions/v0.1.0/plan")"
[[ "$number" == "002" ]] || fail "expected next plan 002, got $number"

mkdir -p "$tmp/overflow-plans"
printf '# Plan\n\n- 状态：planned\n' > "$tmp/overflow-plans/999-final.md"
if sdd_next_plan_number "$tmp/overflow-plans" >/tmp/sdd-next-plan-overflow.out 2>/tmp/sdd-next-plan-overflow.err; then
  fail "expected plan number overflow to fail"
fi
assert_contains "/tmp/sdd-next-plan-overflow.err" "Plan 编号已达到上限 999"

dr_number="$(sdd_next_dr_number "$tmp/valid/docs/versions/v0.1.0/dr")"
[[ "$dr_number" == "002" ]] || fail "expected next DR 002, got $dr_number"

slug="$(sdd_slug 'Login Null Error!')"
[[ "$slug" == "login-null-error" ]] || fail "expected login-null-error, got $slug"

sdd_locator_valid "v0.3.0:spec/archive.md" || fail "expected version locator to be valid"
sdd_locator_valid "-" || fail "expected dash locator to be valid"
if sdd_locator_valid "spec/archive.md"; then fail "expected bare relative path to be an invalid locator"; fi
if sdd_locator_valid "project:requirements/business-rules.md"; then fail "expected project locator to be invalid"; fi
if sdd_locator_valid "project:notes.txt"; then fail "expected non-requirements project locator to be invalid"; fi

target="$(printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/prd/prd.md"}}' | sdd_json_target_path)"
[[ "$target" == "docs/versions/v0.1.0/prd/prd.md" ]] || fail "expected file_path target, got $target"

bash tests/fixtures/invalid-project.sh "$tmp/invalid"
if sdd_active_version_dir "$tmp/invalid" >/tmp/sdd-invalid.out 2>/tmp/sdd-invalid.err; then
  fail "expected multiple active versions to fail"
fi
assert_contains "/tmp/sdd-invalid.err" "发现多个 active version"

bash tests/fixtures/valid-project.sh "$tmp/zero"
printf '{\n  "version": "v0.1.0",\n  "state": "archived",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": "2026-07-14T12:00:00Z"\n}\n' > "$tmp/zero/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/zero" >/tmp/sdd-zero.out 2>/tmp/sdd-zero.err; then
  fail "expected zero active versions to fail"
fi
assert_contains "/tmp/sdd-zero.err" "未发现 active version"
assert_contains "/tmp/sdd-zero.err" "/sdd:new"

bash tests/fixtures/valid-project.sh "$tmp/missing-required"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "archived_at": null\n}\n' > "$tmp/missing-required/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/missing-required" >/tmp/sdd-missing-required.out 2>/tmp/sdd-missing-required.err; then
  fail "expected state.json without created_at to fail"
fi
assert_contains "/tmp/sdd-missing-required.err" "state.json 缺少必需字段"

bash tests/fixtures/valid-project.sh "$tmp/missing-archived-at"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z"\n}\n' > "$tmp/missing-archived-at/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/missing-archived-at" >/tmp/sdd-missing-archived-at.out 2>/tmp/sdd-missing-archived-at.err; then
  fail "expected state.json without archived_at to fail"
fi
assert_contains "/tmp/sdd-missing-archived-at.err" "state.json 缺少必需字段"

bash tests/fixtures/valid-project.sh "$tmp/active-with-archived-at"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": "2026-07-14T12:00:00Z"\n}\n' > "$tmp/active-with-archived-at/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/active-with-archived-at" >/tmp/sdd-active-with-archived-at.out 2>/tmp/sdd-active-with-archived-at.err; then
  fail "expected active state with archived_at to fail"
fi
assert_contains "/tmp/sdd-active-with-archived-at.err" "state.json 生命周期非法"

bash tests/fixtures/valid-project.sh "$tmp/archived-with-null"
printf '{\n  "version": "v0.1.0",\n  "state": "archived",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$tmp/archived-with-null/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/archived-with-null" >/tmp/sdd-archived-with-null.out 2>/tmp/sdd-archived-with-null.err; then
  fail "expected archived state with null archived_at to fail"
fi
assert_contains "/tmp/sdd-archived-with-null.err" "state.json 生命周期非法"

bash tests/fixtures/valid-project.sh "$tmp/archived-with-value"
printf '{\n  "version": "v0.1.0",\n  "state": "archived",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": "2026-07-14T12:00:00Z"\n}\n' > "$tmp/archived-with-value/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/archived-with-value" >/tmp/sdd-archived-with-value.out 2>/tmp/sdd-archived-with-value.err; then
  fail "expected archived-only project to report no active version"
fi
assert_contains "/tmp/sdd-archived-with-value.err" "未发现 active version"

bash tests/fixtures/valid-project.sh "$tmp/non-semver"
mkdir -p "$tmp/non-semver/docs/versions/v0.2.0-beta"
printf '{\n  "version": "v0.2.0-beta",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$tmp/non-semver/docs/versions/v0.2.0-beta/state.json"
active="$(sdd_active_version_dir "$tmp/non-semver")"
[[ "$active" == "docs/versions/v0.1.0" ]] || fail "expected non-semver directory to be ignored, got $active"

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
if sdd_is_dr_id "000-fix-login-null"; then
  fail "expected zero DR number to be invalid"
fi

plan_dr_id="$(sdd_plan_dr_id_from_basename "007-001-fix-login-null.md")"
[[ "$plan_dr_id" == "001-fix-login-null" ]] || fail "expected 001-fix-login-null, got $plan_dr_id"

if sdd_plan_dr_id_from_basename "007-feature-login.md" >/tmp/sdd-plan-dr-id.out 2>/tmp/sdd-plan-dr-id.err; then
  fail "expected spec-mode plan basename to fail code-class DR parsing"
fi
assert_contains "/tmp/sdd-plan-dr-id.err" "不是 code-class DR plan"

if sdd_plan_dr_id_from_basename "000-001-fix-login-null.md" >/tmp/sdd-plan-zero-number.out 2>/tmp/sdd-plan-zero-number.err; then
  fail "expected zero plan number to be invalid"
fi
if sdd_plan_dr_id_from_basename "007-000-fix-login-null.md" >/tmp/sdd-plan-zero-dr.out 2>/tmp/sdd-plan-zero-dr.err; then
  fail "expected zero DR number in plan to be invalid"
fi

mkdir -p "$tmp/empty-dr"
first_dr_number="$(sdd_next_dr_number "$tmp/empty-dr")"
[[ "$first_dr_number" == "001" ]] || fail "expected first DR number 001, got $first_dr_number"

mkdir -p "$tmp/multi-tag-dr"
printf '# DR-001-fix：A\n\n- 状态：accepted\n' > "$tmp/multi-tag-dr/001-fix-a.md"
printf '# DR-002-feat：B\n\n- 状态：accepted\n' > "$tmp/multi-tag-dr/002-feat-b.md"
printf '# DR-009-doc：C\n\n- 状态：accepted\n' > "$tmp/multi-tag-dr/009-doc-c.md"
shared_number="$(sdd_next_dr_number "$tmp/multi-tag-dr")"
[[ "$shared_number" == "010" ]] || fail "expected cross-tag next DR number 010, got $shared_number"

mkdir -p "$tmp/overflow-dr"
printf '# DR-999-fix：Overflow\n\n- 状态：accepted\n' > "$tmp/overflow-dr/999-fix-overflow.md"
if sdd_next_dr_number "$tmp/overflow-dr" >/tmp/sdd-next-dr-overflow.out 2>/tmp/sdd-next-dr-overflow.err; then
  fail "expected DR number overflow to fail"
fi
assert_contains "/tmp/sdd-next-dr-overflow.err" "DR 编号已达到上限 999"

assert_not_contains "scripts/lib/sdd-common.sh" '/sdd:doctor'
assert_not_contains "scripts/lib/sdd-common.sh" 'project:requirements/'

printf 'PASS: common library\n'
