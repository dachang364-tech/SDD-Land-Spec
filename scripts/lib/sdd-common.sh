#!/usr/bin/env bash

sdd_read_status() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf '文档不存在：%s\n' "$file" >&2
    return 2
  fi

  local line
  line="$(grep -E '^- 状态：' "$file" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    printf '文档缺少状态行：%s，需要格式：- 状态：<value>\n' "$file" >&2
    return 2
  fi

  printf '%s\n' "${line#- 状态：}"
}

sdd_assert_status() {
  local file="$1"
  local allowed_csv="$2"
  local status
  status="$(sdd_read_status "$file")" || return 2

  IFS=',' read -r -a allowed <<< "$allowed_csv"
  local value
  for value in "${allowed[@]}"; do
    if [[ "$status" == "$value" ]]; then
      return 0
    fi
  done

  printf '状态非法：%s 状态为 %s，期望其中之一：%s\n' "$file" "$status" "$allowed_csv" >&2
  return 2
}

sdd_active_version_dir() {
  local root="$1"
  local docs_dir="$root/docs"
  if [[ ! -d "$docs_dir" ]]; then
    printf '未找到 docs/，请先运行 /sdd:init。\n' >&2
    return 2
  fi

  local versions=()
  local path
  shopt -s nullglob
  for path in "$docs_dir"/v*; do
    [[ -d "$path" ]] || continue
    case "$(basename "$path")" in
      v[0-9]*.[0-9]*.[0-9]*) versions+=("docs/$(basename "$path")") ;;
    esac
  done
  shopt -u nullglob

  if [[ "${#versions[@]}" -eq 0 ]]; then
    printf '未找到活跃版本目录，请先运行 /sdd:new vX.Y.Z。\n' >&2
    return 2
  fi

  if [[ "${#versions[@]}" -gt 1 ]]; then
    printf '发现多个未归档版本目录：%s。MVP 不支持多活跃版本，请先运行 /sdd:archive。\n' "${versions[*]}" >&2
    return 2
  fi

  printf '%s\n' "${versions[0]}"
}

sdd_next_plan_number() {
  local plans_dir="$1"
  local max=0
  local file base prefix
  shopt -s nullglob
  for file in "$plans_dir"/[0-9][0-9][0-9]-*.md; do
    base="$(basename "$file")"
    prefix="${base%%-*}"
    if [[ "$prefix" =~ ^[0-9][0-9][0-9]$ ]] && (( 10#$prefix > max )); then
      max=$((10#$prefix))
    fi
  done
  shopt -u nullglob
  printf '%03d\n' "$((max + 1))"
}

sdd_next_dr_number() {
  local decisions_dir="$1"
  local max=0
  local file base rest number
  shopt -s nullglob
  for file in "$decisions_dir"/*.md; do
    base="$(basename "$file" .md)"
    rest="${base#*-}"
    number="${rest%%-*}"
    if [[ "$number" =~ ^[0-9][0-9][0-9][0-9]$ ]] && (( 10#$number > max )); then
      max=$((10#$number))
    fi
  done
  shopt -u nullglob
  printf '%04d\n' "$((max + 1))"
}

sdd_json_target_path() {
  local payload
  payload="$(cat)"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; data=json.load(sys.stdin); ti=data.get("tool_input",{}); print(ti.get("file_path") or ti.get("path") or "")' <<< "$payload"
  else
    printf '%s\n' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
  fi
}

sdd_slug() {
  local input="$1"
  printf '%s\n' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}
