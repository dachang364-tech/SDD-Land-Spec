#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"
. "$root_dir/scripts/lib/sdd-common.sh"

target_path="$(sdd_json_target_path)"
[[ -n "$target_path" ]] || exit 0

target_path="${target_path#./}"

case "$target_path" in
  docs/v*/prd.md)
    exit 0
    ;;
  docs/v*/specs/spec.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    prd="docs/$version/prd.md"
    if [[ ! -f "$prd" ]]; then
      printf '无法写入 %s：\n前置文档 %s 不存在。\n请先完成 /sdd:prd。\n' "$target_path" "$prd" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/plans/[0-9][0-9][0-9]-feature-*.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    spec="docs/$version/specs/spec.md"
    status="$(sdd_read_status "$spec")" || exit 2
    if [[ "$status" != "approved" ]]; then
      printf '无法写入 %s：\n前置文档 %s 状态为 %s，期望 approved。\n请先完成 /sdd:spec 并批准 Functional Specification。\n' "$target_path" "$spec" "$status" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    base="$(basename "$target_path" .md)"
    dr_id="${base#???-}"
    dr="docs/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/decisions/*.md|docs/requirements/*.md|src/*|src/**)
    exit 0
    ;;
  docs/archive/*|docs/archive/**)
    printf '无法直接写入 %s：archive 内容应由 /sdd:archive 移动生成。\n' "$target_path" >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
