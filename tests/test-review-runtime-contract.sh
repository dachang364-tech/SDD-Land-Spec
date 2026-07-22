#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh
. scripts/lib/sdd-template-assets.sh
. scripts/lib/sdd-review-runner.sh

tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_project" /tmp/sdd-runner.out /tmp/sdd-runner.err /tmp/sdd-hook.out /tmp/sdd-hook.err' EXIT

mkdir -p "$tmp_project/.sdd/templates/research" "$tmp_project/.sdd/templates/prd" "$tmp_project/.sdd/templates/spec" "$tmp_project/.sdd/templates/plan" "$tmp_project/.sdd/templates/dr"
printf '# research template\n' > "$tmp_project/.sdd/templates/research/template.md"
printf '# research quality\n' > "$tmp_project/.sdd/templates/research/quality.standard.md"
printf '# prd template\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# prd quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# spec template\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# spec quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# spec feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# plan template\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# plan quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# plan feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"
printf '# dr template\n' > "$tmp_project/.sdd/templates/dr/template.md"
printf '# dr quality\n' > "$tmp_project/.sdd/templates/dr/quality.standard.md"

CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/prd/prd.md" --invocation-source manual > /tmp/sdd-runner.out
assert_contains "/tmp/sdd-runner.out" '"document_type":"prd"'
assert_contains "/tmp/sdd-runner.out" '"executed_modes":["quality"]'
assert_contains "/tmp/sdd-runner.out" '"requires_user_confirmation":false'

CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/spec/login.md" --invocation-source manual > /tmp/sdd-runner.out
assert_contains "/tmp/sdd-runner.out" '"document_type":"spec"'
assert_contains "/tmp/sdd-runner.out" '"executed_modes":["quality","feasibility"]'

if CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/random.md" --invocation-source manual > /tmp/sdd-runner.out 2> /tmp/sdd-runner.err; then
  fail "expected unmanaged path to fail"
fi
assert_contains "/tmp/sdd-runner.err" '不是受支持的 SDD 文档路径'

rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
if CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/spec/login.md" --invocation-source automatic > /tmp/sdd-runner.out 2> /tmp/sdd-runner.err; then
  fail "expected missing template asset to fail"
fi
assert_contains "/tmp/sdd-runner.err" '缺少项目模板资产'

printf 'PASS: review runtime contract\n'
