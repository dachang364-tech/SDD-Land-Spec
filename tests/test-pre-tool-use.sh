#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash tests/fixtures/valid-project.sh "$tmp"

run_hook() {
  local root="$1"
  local target="$2"
  (cd "$root" && printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$OLDPWD/scripts/hooks/pre-tool-use.sh")
}

run_hook "$tmp" "docs/v0.1.0/prd.md"
run_hook "$tmp" "docs/v0.1.0/specs/spec.md"
run_hook "$tmp" "docs/v0.1.0/plans/001-feature-login.md"
run_hook "$tmp" "docs/v0.1.0/plans/002-fix-0001-login-null.md"
run_hook "$tmp" "docs/v0.1.0/decisions/fix-0002-other.md"
run_hook "$tmp" "docs/requirements/topic-2026-07.md"
run_hook "$tmp" "src/app.ts"

rm "$tmp/docs/v0.1.0/prd.md"
if run_hook "$tmp" "docs/v0.1.0/specs/spec.md" >/tmp/sdd-hook.out 2>/tmp/sdd-hook.err; then
  fail "expected spec write without PRD to fail"
fi
assert_contains "/tmp/sdd-hook.err" "无法写入 docs/v0.1.0/specs/spec.md"
assert_contains "/tmp/sdd-hook.err" "请先完成 /sdd:prd"

printf '# PRD\n' > "$tmp/docs/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$tmp/docs/v0.1.0/specs/spec.md"
if run_hook "$tmp" "docs/v0.1.0/plans/003-feature-settings.md" >/tmp/sdd-hook2.out 2>/tmp/sdd-hook2.err; then
  fail "expected feature plan write with draft spec to fail"
fi
assert_contains "/tmp/sdd-hook2.err" "前置文档 docs/v0.1.0/specs/spec.md 状态为 draft，期望 approved"

printf '# DR\n\n- 状态：drafting\n' > "$tmp/docs/v0.1.0/decisions/chg-0002-policy.md"
if run_hook "$tmp" "docs/v0.1.0/plans/004-chg-0002-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/v0.1.0/decisions/chg-0002-policy.md 状态为 drafting，期望 accepted"

printf 'PASS: pre-tool-use hook\n'
