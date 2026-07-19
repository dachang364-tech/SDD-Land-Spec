#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/references/reviewer-result.schema.json" '"blocked"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"auto_repairs"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"user_receipt"'
assert_contains "README.md" '/sdd:review'
assert_contains "TESTING.md" '.sdd/templates/'

printf 'PASS: review output contract\n'
