#!/usr/bin/env bash

sdd_review_runner_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdd_review_runner_root="$(cd "$sdd_review_runner_lib_dir/../.." && pwd)"
. "$sdd_review_runner_root/scripts/lib/sdd-common.sh"
. "$sdd_review_runner_root/scripts/lib/sdd-template-assets.sh"

sdd_review_runner_parse_args() {
  local document_path=""
  local invocation_source=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --document-path)
        document_path="$2"
        shift 2
        ;;
      --invocation-source)
        invocation_source="$2"
        shift 2
        ;;
      *)
        printf '未知参数：%s\n' "$1" >&2
        return 3
        ;;
    esac
  done

  if [[ -z "$document_path" || -z "$invocation_source" ]]; then
    printf '缺少必需参数：--document-path 和 --invocation-source\n' >&2
    return 3
  fi

  printf '%s\n%s\n' "$document_path" "$invocation_source"
}

sdd_review_runner_require_assets() {
  local project_root="$1"
  local document_type="$2"

  case "$document_type" in
    research)
      sdd_require_template_asset "$project_root" research template.md >/dev/null
      sdd_require_template_asset "$project_root" research quality.standard.md >/dev/null
      ;;
    prd)
      sdd_require_template_asset "$project_root" prd template.md >/dev/null
      sdd_require_template_asset "$project_root" prd quality.standard.md >/dev/null
      ;;
    dr)
      sdd_require_template_asset "$project_root" dr template.md >/dev/null
      sdd_require_template_asset "$project_root" dr quality.standard.md >/dev/null
      ;;
    spec)
      sdd_require_template_asset "$project_root" spec template.md >/dev/null
      sdd_require_template_asset "$project_root" spec quality.standard.md >/dev/null
      sdd_require_template_asset "$project_root" spec feasibility.standard.md >/dev/null
      ;;
    plan)
      sdd_require_template_asset "$project_root" plan template.md >/dev/null
      sdd_require_template_asset "$project_root" plan quality.standard.md >/dev/null
      sdd_require_template_asset "$project_root" plan feasibility.standard.md >/dev/null
      ;;
  esac
}

sdd_review_runner_execute_mode() {
  local document_type="$1"
  local document_path="$2"
  local mode="$3"
  printf '{"document_type":"%s","document_path":"%s","mode":"%s","blocked":false,"requires_user_confirmation":false,"remaining_items":[]}' \
    "$document_type" "$document_path" "$mode"
}

sdd_review_runner_main() {
  local parsed document_path invocation_source document_type project_root mode_chain mode executed_modes_json blocked requires_user_confirmation remaining_items_json result
  parsed="$(sdd_review_runner_parse_args "$@")" || return $?
  document_path="$(printf '%s\n' "$parsed" | sed -n '1p')"
  invocation_source="$(printf '%s\n' "$parsed" | sed -n '2p')"
  document_type="$(sdd_review_document_type "$document_path")" || return $?
  project_root="${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR is required}"
  sdd_review_runner_require_assets "$project_root" "$document_type" || return 3
  mode_chain="$(sdd_review_mode_chain "$document_type")" || return $?

  executed_modes_json='[]'
  blocked=false
  requires_user_confirmation=false
  remaining_items_json='[]'

  for mode in $mode_chain; do
    result="$(sdd_review_runner_execute_mode "$document_type" "$document_path" "$mode")" || return 3
    case "$executed_modes_json" in
      '[]') executed_modes_json="[\"$mode\"]" ;;
      *) executed_modes_json="${executed_modes_json%]} ,\"$mode\"]" ;;
    esac
  done

  executed_modes_json="$(printf '%s' "$executed_modes_json" | sed 's/ \,/,/g; s/, /,/g')"
  printf '{"document_path":"%s","document_type":"%s","invocation_source":"%s","executed_modes":%s,"blocked":%s,"requires_user_confirmation":%s,"remaining_items":%s}\n' \
    "$document_path" "$document_type" "$invocation_source" "$executed_modes_json" "$blocked" "$requires_user_confirmation" "$remaining_items_json"
}
