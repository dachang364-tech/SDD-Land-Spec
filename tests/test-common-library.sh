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

printf 'PASS: common library\n'
