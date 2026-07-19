#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/references/reviewer-result.schema.json" '"blocked"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"auto_repairs"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"user_receipt"'
assert_contains "README.md" '/sdd:review'
assert_contains "README.md" '运行时唯一模板来源'
assert_contains "README.md" '`/sdd:init` 会将所选模板包展开到 `.sdd/templates/`'
assert_contains "TESTING.md" '模板包选择'
assert_contains "TESTING.md" '未显式切换时默认使用 `default-backend`'
assert_contains "TESTING.md" '手工删除 `.sdd/templates/spec/feasibility.standard.md`'
assert_contains "TESTING.md" '明确失败，并提示缺少项目模板资产'
assert_contains "TESTING.md" '确认 reviewer 自动触发'
assert_contains "TESTING.md" '只返回一份聚合用户回执'

printf 'PASS: review output contract\n'
