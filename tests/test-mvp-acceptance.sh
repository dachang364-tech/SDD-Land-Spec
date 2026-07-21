#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

# Plugin installation surface
assert_file_exists ".claude-plugin/plugin.json"
assert_file_exists ".claude-plugin/marketplace.json"
assert_file_exists "hooks/hooks.json"
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"

for skill in init new research prd spec plan code dr archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

assert_file_exists "assets/template-packs/backend/research/template.md"
assert_file_exists "assets/template-packs/backend/research/quality.standard.md"
assert_file_exists "assets/template-packs/backend/prd/template.md"
assert_file_exists "assets/template-packs/backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/plan/quality.standard.md"
assert_file_exists "assets/template-packs/backend/dr/template.md"
assert_file_exists "assets/template-packs/backend/dr/quality.standard.md"

# No forbidden centralized state implementation.
# Scan implementation and generated contract files only, so documentation that
# describes the prohibition is not treated as a violation.
if grep -R "\.sdd/state\.json" \
  .claude-plugin hooks scripts \
  --include='*.json' \
  --include='*.sh' \
  >/tmp/sdd-state-grep.out 2>/tmp/sdd-state-grep.err; then
  fail "implementation must not create or depend on centralized SDD state file"
fi

# Hook behavior from spec section 9.6
bash tests/test-pre-tool-use.sh >/tmp/sdd-pretool.out
assert_contains "/tmp/sdd-pretool.out" "PASS: pre-tool-use hook"

# Shared parser behavior
bash tests/test-common-library.sh >/tmp/sdd-common.out
assert_contains "/tmp/sdd-common.out" "PASS: common library"

# Skill documentation contract
bash tests/test-skill-contracts.sh >/tmp/sdd-skills.out
assert_contains "/tmp/sdd-skills.out" "PASS: skill contracts"

bash tests/test-dr-filename-contract.sh

assert_file_not_exists "skills/doctor/SKILL.md"
assert_file_not_exists "skills/status/SKILL.md"

printf 'PASS: MVP acceptance\n'
