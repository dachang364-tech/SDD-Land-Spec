#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

plugin_version="$(sdd_plugin_version .claude-plugin/plugin.json)"

assert_file_exists ".claude-plugin/plugin.json"
assert_contains ".claude-plugin/plugin.json" '"name": "sdd"'
assert_contains ".claude-plugin/plugin.json" "\"version\": \"$plugin_version\""
assert_file_exists ".claude-plugin/marketplace.json"
assert_contains ".claude-plugin/marketplace.json" '"name": "sdd-local"'
assert_contains ".claude-plugin/marketplace.json" '"name": "sdd"'
assert_contains ".claude-plugin/marketplace.json" '"source": "./"'

assert_file_exists "CONSTITUTION.default.md"
assert_contains "CONSTITUTION.default.md" "must: SDD 主流程必须按"
assert_contains "CONSTITUTION.default.md" "must: SDD 管理的状态行只能使用"
assert_contains "CONSTITUTION.default.md" "must: 代码类 DR 必须先"

assert_file_exists "scripts/install-deps.sh"
assert_executable "scripts/install-deps.sh"
assert_contains "scripts/install-deps.sh" 'claude plugin install "https://github.com/obra/superpowers.git"'
assert_contains "scripts/install-deps.sh" 'claude plugin install "https://github.com/github/spec-kit.git"'

assert_file_exists "hooks/hooks.json"
assert_contains "hooks/hooks.json" "PreToolUse"
assert_contains "hooks/hooks.json" "SessionStart"
assert_contains "hooks/hooks.json" '${CLAUDE_PLUGIN_ROOT}/scripts/hooks/pre-tool-use.sh'
assert_contains "hooks/hooks.json" '${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh'
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"

assert_file_exists "README.md"
assert_contains "README.md" "/sdd:init"
assert_contains "README.md" "/sdd:archive"

assert_contains "skills/doctor/SKILL.md" 'the remaining plan basename must equal the full `DR ID`'
assert_contains "skills/doctor/SKILL.md" 'A DR-like plan basename with an invalid DR ID, a missing exact `decisions/<dr-id>.md`, or legacy `<tag>-NNNN-<slug>` form is an `ERROR`'
assert_not_contains "skills/doctor/SKILL.md" 'plan filename minus `NNN-` equals DR slug'

printf 'PASS: skeleton contract\n'
