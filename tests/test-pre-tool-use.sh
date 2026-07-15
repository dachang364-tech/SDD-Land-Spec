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

run_hook_abs_raw() {
  local root="$1"
  local target="$2"
  (cd "$root" && printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$OLDPWD/scripts/hooks/pre-tool-use.sh")
}

run_hook "$tmp" "docs/versions/v0.1.0/prd.md"
run_hook "$tmp" "docs/versions/v0.1.0/specs/spec.md"
run_hook "$tmp" "docs/versions/v0.1.0/specs/document-references.md"
run_hook "$tmp" "docs/versions/v0.1.0/plans/002-feature-settings.md"
run_hook "$tmp" "docs/versions/v0.1.0/decisions/fix-0002-other.md"
run_hook "$tmp" "docs/requirements/topic-2026-07.md"
run_hook "$tmp" "src/app.ts"

rm "$tmp/docs/versions/v0.1.0/prd.md"
if run_hook "$tmp" "docs/versions/v0.1.0/specs/new-spec.md" >/tmp/sdd-hook.out 2>/tmp/sdd-hook.err; then
  fail "expected spec write without PRD to fail"
fi
assert_contains "/tmp/sdd-hook.err" "无法写入 docs/versions/v0.1.0/specs/new-spec.md"
assert_contains "/tmp/sdd-hook.err" "请先完成 /sdd:prd"

printf '# PRD\n' > "$tmp/docs/versions/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$tmp/docs/versions/v0.1.0/specs/spec.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/003-feature-settings.md" >/tmp/sdd-hook2.out 2>/tmp/sdd-hook2.err; then
  fail "expected feature plan write with draft spec to fail"
fi
assert_contains "/tmp/sdd-hook2.err" "前置规格 docs/versions/v0.1.0/specs/*.md 中不存在 approved 文档"
assert_contains "/tmp/sdd-hook2.err" "请先完成 /sdd:spec 并批准目标 Functional Specification"

if run_hook_abs_raw "$tmp" "$tmp/docs/versions/v0.1.0/plans/003-login.md" >/tmp/sdd-hook2c.out 2>/tmp/sdd-hook2c.err; then
  fail "expected absolute spec-mode plan path with only draft specs to fail"
fi
assert_contains "/tmp/sdd-hook2c.err" "前置规格 docs/versions/v0.1.0/specs/*.md 中不存在 approved 文档"

if run_hook_abs_raw "$tmp" "$tmp/docs/versions/../versions/v0.1.0/plans/003-login.md" >/tmp/sdd-hook2d.out 2>/tmp/sdd-hook2d.err; then
  fail "expected dot-dot absolute spec-mode plan path with only draft specs to fail"
fi
assert_contains "/tmp/sdd-hook2d.err" "前置规格 docs/versions/v0.1.0/specs/*.md 中不存在 approved 文档"

if run_hook "$tmp" "docs/x/../../docs/versions/v0.1.0/plans/003-login.md" >/tmp/sdd-hook2f.out 2>/tmp/sdd-hook2f.err; then
  fail "expected dot-dot relative spec-mode plan path with only draft specs to fail"
fi
assert_contains "/tmp/sdd-hook2f.err" "前置规格 docs/versions/v0.1.0/specs/*.md 中不存在 approved 文档"

if run_hook "$tmp" "docs//versions/v0.1.0/plans/003-login.md" >/tmp/sdd-hook2g.out 2>/tmp/sdd-hook2g.err; then
  fail "expected doubled-slash relative spec-mode plan path with only draft specs to fail"
fi
assert_contains "/tmp/sdd-hook2g.err" "前置规格 docs/versions/v0.1.0/specs/*.md 中不存在 approved 文档"

printf '# Functional Specification\n\n- 状态：approved\n' > "$tmp/docs/versions/v0.1.0/specs/document-references.md"
run_hook "$tmp" "docs/versions/v0.1.0/plans/003-login.md"
run_hook "$tmp" "docs/versions/v0.1.0/plans/003-feature-settings.md"

printf '# DR\n\n- 状态：drafting\n- class：code\n- tag：chg\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/chg-0002-policy.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/004-chg-0002-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/versions/v0.1.0/decisions/chg-0002-policy.md 状态为 drafting，期望 accepted"

printf '# DR\n\n- 状态：drafting\n- class：code\n- tag：feat\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/feat-0002-rollout.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/005-feat-0002-rollout.md" >/tmp/sdd-hook4.out 2>/tmp/sdd-hook4.err; then
  fail "expected feat DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook4.err" "前置 DR docs/versions/v0.1.0/decisions/feat-0002-rollout.md 状态为 drafting，期望 accepted"

run_hook "$tmp" "docs/archive/INDEX.md"
run_hook "$tmp" "docs/versions/v0.1.0/ARCHIVE.md"

printf 'PASS: pre-tool-use hook\n'
