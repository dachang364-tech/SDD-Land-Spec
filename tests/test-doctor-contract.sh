#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists ".claude-plugin/plugin.json"
assert_contains ".claude-plugin/plugin.json" '"name": "sdd"'
assert_contains ".claude-plugin/plugin.json" '"version": "0.1.0"'

assert_file_exists "CONSTITUTION.default.md"
assert_contains "CONSTITUTION.default.md" "must: SDD 主流程必须按"
assert_contains "CONSTITUTION.default.md" "must: SDD 管理的状态行只能使用"
assert_contains "CONSTITUTION.default.md" "must: 代码类 DR 必须先"

assert_file_exists "scripts/install-deps.sh"
assert_executable "scripts/install-deps.sh"
assert_contains "scripts/install-deps.sh" 'claude plugin install "claude-plugins-official/superpowers"'
assert_contains "scripts/install-deps.sh" 'claude plugin install "claude-plugins-official/spec-kit"'

assert_file_exists "hooks/hooks.json"
assert_contains "hooks/hooks.json" "PreToolUse"
assert_contains "hooks/hooks.json" "SessionStart"
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"

assert_file_exists "README.md"
assert_contains "README.md" "/sdd:init"
assert_contains "README.md" "/sdd:archive"

printf 'PASS: skeleton contract\n'
