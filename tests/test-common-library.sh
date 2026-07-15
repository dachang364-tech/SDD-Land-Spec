#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash tests/fixtures/valid-project.sh "$tmp/valid"

status="$(sdd_read_status "$tmp/valid/docs/versions/v0.1.0/specs/spec.md")"
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

number="$(sdd_next_plan_number "$tmp/valid/docs/versions/v0.1.0/plans")"
[[ "$number" == "002" ]] || fail "expected next plan 002, got $number"

dr_number="$(sdd_next_dr_number "$tmp/valid/docs/versions/v0.1.0/decisions")"
[[ "$dr_number" == "0002" ]] || fail "expected next DR 0002, got $dr_number"

slug="$(sdd_slug 'Login Null Error!')"
[[ "$slug" == "login-null-error" ]] || fail "expected login-null-error, got $slug"

sdd_locator_valid "v0.3.0:specs/archive.md" || fail "expected version locator to be valid"
sdd_locator_valid "project:requirements/business-rules.md" || fail "expected project locator to be valid"
sdd_locator_valid "-" || fail "expected dash locator to be valid"
if sdd_locator_valid "specs/archive.md"; then fail "expected bare relative path to be an invalid locator"; fi
if sdd_locator_valid "project:notes.txt"; then fail "expected non-requirements project locator to be invalid"; fi

target="$(printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/prd.md"}}' | sdd_json_target_path)"
[[ "$target" == "docs/versions/v0.1.0/prd.md" ]] || fail "expected file_path target, got $target"

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

printf 'PASS: common library\n'
