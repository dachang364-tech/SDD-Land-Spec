#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

sdd_is_dr_id "001-fix-login-null" || fail "expected code-class DR ID to be valid"
sdd_is_dr_id "001-doc-release-note" || fail "expected document-class DR ID to be valid"
if sdd_is_dr_id "fix-0001-login-null"; then
  fail "expected legacy DR ID to be invalid"
fi

plan_dr_id="$(sdd_plan_dr_id_from_basename "007-001-fix-login-null.md")"
[[ "$plan_dr_id" == "001-fix-login-null" ]] || fail "expected 001-fix-login-null, got $plan_dr_id"

if sdd_plan_dr_id_from_basename "007-001-doc-release-note.md" >/tmp/sdd-doc-plan-id.out 2>/tmp/sdd-doc-plan-id.err; then
  fail "expected document-class DR plan basename to fail"
fi
assert_contains "/tmp/sdd-doc-plan-id.err" "不是 code-class DR plan"

assert_contains "skills/dr/SKILL.md" '`/sdd:dr accept 001-fix-login-null`'
assert_contains "skills/plan/SKILL.md" '如果 `<work-item>` 匹配 `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$`，使用 code-class DR mode'
assert_contains "skills/plan/SKILL.md" '如果 `<work-item>` 匹配 `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`，直接拒绝'
assert_contains "skills/plan/SKILL.md" '如果 `<work-item>` 看起来像 DR（以三位数字和连字符开头），但不是合法完整 DR ID'
assert_contains "skills/plan/SKILL.md" '不得落回 spec mode。'
assert_contains "skills/plan/SKILL.md" '不得落回 spec mode。'
assert_contains "skills/code/SKILL.md" 'If input is a complete plan basename, match the same `.md` basename and use plan execution mode. This lookup occurs before DR-like validation'
assert_contains "skills/code/SKILL.md" 'If input matches a document-class DR id `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`, refuse'
assert_contains "skills/code/SKILL.md" 'If input is DR-like (starts with three digits and a hyphen) but is not a valid full DR ID, fail explicitly'
assert_contains "skills/code/SKILL.md" '001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>'
assert_contains "skills/code/SKILL.md" 'Do not fall through to plan or feature-name lookup.'
assert_contains "skills/code/SKILL.md" 'If input matches a code-class DR id `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$`'
assert_contains "skills/code/SKILL.md" 'first check for a matching plan by exact DR ID suffix'
assert_contains "skills/code/SKILL.md" 'If zero plans match and no eligible lightweight fix DR matches'

printf 'PASS: DR filename contract\n'
