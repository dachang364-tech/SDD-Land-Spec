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
assert_contains "skills/plan/SKILL.md" 'If `<work-item>` matches `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`, use code-class DR mode.'
assert_contains "skills/plan/SKILL.md" 'If `<work-item>` matches `^[0-9]{3}-(spec|doc|typo)-[a-z0-9-]+$`, refuse'
assert_contains "skills/code/SKILL.md" 'If input matches a code-class DR id `^[0-9]{3}-(fix|feat|chg|arch)-[a-z0-9-]+$`'
assert_contains "skills/code/SKILL.md" 'first check for a matching plan by exact DR ID suffix'
assert_contains "skills/code/SKILL.md" 'If zero plans match and no eligible lightweight fix DR matches'
assert_contains "skills/doctor/SKILL.md" 'the remaining plan basename must equal the full `DR ID`'
assert_not_contains "skills/doctor/SKILL.md" 'plan filename minus `NNN-` equals DR slug'

printf 'PASS: DR filename contract\n'
