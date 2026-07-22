#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"
. "$root_dir/scripts/lib/sdd-common.sh"

normalize_target_path() {
  local raw="$1"
  python3 - "$PWD" "$raw" <<'PY'
import os
import sys
root = os.path.realpath(sys.argv[1])
raw = sys.argv[2]
if os.path.isabs(raw):
    path = os.path.realpath(raw)
else:
    path = os.path.realpath(os.path.join(root, raw))
try:
    rel = os.path.relpath(path, root)
except ValueError:
    print(path)
    sys.exit(0)
print(rel)
PY
}

payload="$(cat)"
target_path="$(printf '%s' "$payload" | sdd_json_target_path)"

if [[ -z "$target_path" ]]; then
  exit 0
fi

target_path="$(normalize_target_path "$target_path")"
target_path="${target_path#./}"

if ! sdd_is_managed_review_document "$target_path"; then
  exit 0
fi

if ! result="$(CLAUDE_PROJECT_DIR="$PWD" "$root_dir/scripts/lib/sdd-review-runner.sh" --document-path "$target_path" --invocation-source automatic 2>&1)"; then
  runner_status=$?
  printf '文档已写入，但自动 review 未完成：%s\n' "$target_path" >&2
  printf '%s\n' "$result" >&2
  exit "$runner_status"
fi

printf '%s\n' "$result" >/dev/null
