#!/usr/bin/env bash
set -euo pipefail

. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-common.sh"
. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-review-runner.sh"

payload="$(cat)"
target_path="$(printf '%s' "$payload" | sdd_json_target_path)"

if [[ -z "$target_path" ]]; then
  exit 0
fi

if ! sdd_is_managed_review_document "$target_path"; then
  exit 0
fi

if ! result="$(sdd_review_runner_main --document-path "$target_path" --invocation-source automatic 2>&1)"; then
  status=$?
  printf '文档已写入，但自动 review 未完成：%s\n' "$target_path" >&2
  printf '%s\n' "$result" >&2
  exit "$status"
fi

printf '%s\n' "$result" >/dev/null
