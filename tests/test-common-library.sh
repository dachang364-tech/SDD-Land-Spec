#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash tests/fixtures/valid-project.sh "$tmp/valid"

status="$(sdd_read_status "$tmp/valid/docs/v0.1.0/specs/spec.md")"
[[ "$status" == "approved" ]] || fail "expected approved status, got $status"

active="$(sdd_active_version_dir "$tmp/valid")"
[[ "$active" == "docs/v0.1.0" ]] || fail "expected docs/v0.1.0, got $active"

number="$(sdd_next_plan_number "$tmp/valid/docs/v0.1.0/plans")"
[[ "$number" == "002" ]] || fail "expected next plan 002, got $number"

dr_number="$(sdd_next_dr_number "$tmp/valid/docs/v0.1.0/decisions")"
[[ "$dr_number" == "0002" ]] || fail "expected next DR 0002, got $dr_number"

slug="$(sdd_slug 'Login Null Error!')"
[[ "$slug" == "login-null-error" ]] || fail "expected login-null-error, got $slug"

target="$(printf '{"tool_input":{"file_path":"docs/v0.1.0/prd.md"}}' | sdd_json_target_path)"
[[ "$target" == "docs/v0.1.0/prd.md" ]] || fail "expected file_path target, got $target"

target2="$(printf '{"tool_input":{"path":"docs/v0.1.0/specs/spec.md"}}' | sdd_json_target_path)"
[[ "$target2" == "docs/v0.1.0/specs/spec.md" ]] || fail "expected path target, got $target2"

bash tests/fixtures/invalid-project.sh "$tmp/invalid"
if sdd_active_version_dir "$tmp/invalid" >/tmp/sdd-invalid.out 2>/tmp/sdd-invalid.err; then
  fail "expected multiple active versions to fail"
fi
assert_contains "/tmp/sdd-invalid.err" "发现多个未归档版本目录"

printf 'PASS: common library\n'
