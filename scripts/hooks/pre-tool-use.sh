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

target_path="$(sdd_json_target_path)"
[[ -n "$target_path" ]] || exit 0

target_path="$(normalize_target_path "$target_path")"
target_path="${target_path#./}"

plan_requires_approved_spec() {
  local version="$1"
  local spec_glob="docs/versions/$version/specs/*.md"
  local spec status
  shopt -s nullglob
  for spec in docs/versions/"$version"/specs/*.md; do
    [[ -f "$spec" ]] || continue
    status="$(sdd_read_status "$spec" 2>/dev/null)" || continue
    if [[ "$status" == "approved" ]]; then
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  printf '无法写入 %s：\n前置规格 %s 中不存在 approved 文档。\n请先完成 /sdd:spec 并批准目标 Functional Specification。\n' "$target_path" "$spec_glob" >&2
  exit 2
}

case "$target_path" in
  docs/versions/v*/prd.md)
    exit 0
    ;;
  docs/versions/v*/specs/*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    prd="docs/versions/$version/prd.md"
    if [[ ! -f "$prd" ]]; then
      printf '无法写入 %s：\n前置文档 %s 不存在。\n请先完成 /sdd:prd。\n' "$target_path" "$prd" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    base="$(basename "$target_path")"
    dr_id="$(sdd_plan_dr_id_from_basename "$base")" || {
      printf '无法写入 %s：\n非法 DR ID。\n' "$target_path" >&2
      exit 2
    }
    dr="docs/versions/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-arch-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-spec-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-doc-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-[0-9]*-typo-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    printf '无法写入 %s：\n非法 DR ID。\n' "$target_path" >&2
    exit 2
    ;;
  docs/versions/v*/plans/[0-9][0-9][0-9]-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    plan_requires_approved_spec "$version"
    exit 0
    ;;
  docs/versions/v*/decisions/*.md|docs/versions/v*/ARCHIVE.md|docs/versions/v*/state.json|docs/archive/INDEX.md|docs/requirements/*.md|src/*|src/**)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
