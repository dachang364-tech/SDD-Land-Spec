#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_plugin="$(mktemp -d)"
tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project"' EXIT

mkdir -p "$tmp_plugin/assets/project"
printf '# Default Claude\n' > "$tmp_plugin/assets/project/CLAUDE.md"

sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_file_exists "$tmp_project/CLAUDE.md"
assert_contains "$tmp_project/CLAUDE.md" '# Default Claude'

printf '# Custom Claude\n' > "$tmp_project/CLAUDE.md"
sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_contains "$tmp_project/CLAUDE.md" '# Custom Claude'
assert_not_contains "$tmp_project/CLAUDE.md" '# Default Claude'

printf '# Existing Agents\n' > "$tmp_project/AGENTS.md"
sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_file_exists "$tmp_project/AGENTS.md"
assert_contains "$tmp_project/AGENTS.md" '# Existing Agents'

rm "$tmp_project/AGENTS.md"
sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"
assert_file_not_exists "$tmp_project/AGENTS.md"

rm "$tmp_plugin/assets/project/CLAUDE.md"
if sdd_ensure_project_claude "$tmp_plugin" "$tmp_project"; then
  fail "expected sdd_ensure_project_claude to fail when source CLAUDE asset is missing"
fi

printf 'PASS: init project context\n'
