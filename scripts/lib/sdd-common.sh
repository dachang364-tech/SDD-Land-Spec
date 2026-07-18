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

sdd_state_field() {
  local state_file="$1"
  local field="$2"
  if [[ ! -f "$state_file" ]]; then
    printf 'state 文件不存在：%s\n' "$state_file" >&2
    return 2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf '需要 python3 以读取 state.json：%s\n' "$state_file" >&2
    return 2
  fi

  python3 - "$state_file" "$field" <<'PY'
import json
import sys

state_file, field = sys.argv[1:]
try:
    with open(state_file, encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, json.JSONDecodeError):
    print(f"state.json 无法解析：{state_file}", file=sys.stderr)
    sys.exit(3)

if not isinstance(data, dict):
    print(f"state.json 无法解析：{state_file}", file=sys.stderr)
    sys.exit(3)
if field not in data:
    print(f"state.json 缺少字段：{field}（{state_file}）", file=sys.stderr)
    sys.exit(4)

value = data[field]
print("null" if value is None else value)
PY
}

sdd_active_version_dir() {
  local root="$1"
  local versions_dir="$root/docs/versions"
  if [[ ! -d "$versions_dir" ]]; then
    printf '未找到 docs/versions/，请先运行 /sdd:init。\n' >&2
    return 2
  fi

  local actives=()
  local path base state version created_at archived_at
  shopt -s nullglob
  for path in "$versions_dir"/v*; do
    [[ -d "$path" ]] || continue
    base="$(basename "$path")"
    [[ "$base" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    if [[ ! -f "$path/state.json" ]]; then
      printf '版本目录缺少 state.json：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    fi
    version="$(sdd_state_field "$path/state.json" version)" || {
      printf 'state.json 无法解析：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    }
    if [[ "$version" != "$base" ]]; then
      printf 'state.json.version 与目录名不一致：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    fi
    created_at="$(sdd_state_field "$path/state.json" created_at 2>/dev/null)" || {
      printf 'state.json 缺少必需字段：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    }
    archived_at="$(sdd_state_field "$path/state.json" archived_at 2>/dev/null)" || {
      printf 'state.json 缺少必需字段：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    }
    if [[ -z "$created_at" || -z "$archived_at" ]]; then
      printf 'state.json 缺少必需字段：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    fi
    state="$(sdd_state_field "$path/state.json" state)"
    case "$state" in
      active)
        if [[ "$archived_at" != "null" ]]; then
          printf 'state.json 生命周期非法：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
          shopt -u nullglob
          return 2
        fi
        actives+=("docs/versions/$base")
        ;;
      archived)
        if [[ "$archived_at" == "null" ]]; then
          printf 'state.json 生命周期非法：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
          shopt -u nullglob
          return 2
        fi
        ;;
      *)
        printf 'state.json.state 非法：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
        shopt -u nullglob
        return 2
        ;;
    esac
  done
  shopt -u nullglob

  if [[ "${#actives[@]}" -eq 0 ]]; then
    printf '未发现 active version，请先运行 /sdd:new vX.Y.Z。\n' >&2
    return 2
  fi
  if [[ "${#actives[@]}" -gt 1 ]]; then
    printf '发现多个 active version：%s，请运行 /sdd:doctor。\n' "${actives[*]}" >&2
    return 2
  fi
  printf '%s\n' "${actives[0]}"
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

sdd_is_dr_id() {
  local value="$1"
  [[ "$value" =~ ^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch|spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

sdd_next_dr_number() {
  local decisions_dir="$1"
  local max=0
  local file base number
  shopt -s nullglob
  for file in "$decisions_dir"/*.md; do
    base="$(basename "$file" .md)"
    number="${base%%-*}"
    if sdd_is_dr_id "$base" && [[ "$number" =~ ^[0-9][0-9][0-9]$ ]] && (( 10#$number > max )); then
      max=$((10#$number))
    fi
  done
  shopt -u nullglob
  if (( max >= 999 )); then
    printf 'DR 编号已达到上限 999：%s\n' "$decisions_dir" >&2
    return 2
  fi
  printf '%03d\n' "$((max + 1))"
}

sdd_plan_dr_id_from_basename() {
  local plan_basename="$1"
  local base="${plan_basename%.md}"
  local rest="${base#???-}"
  if [[ ! "$base" =~ ^[0-9][0-9][0-9]-(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    printf '不是 code-class DR plan：%s\n' "$plan_basename" >&2
    return 2
  fi
  if ! sdd_is_dr_id "$rest"; then
    printf '非法 DR ID：%s\n' "$rest" >&2
    return 2
  fi
  printf '%s\n' "$rest"
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

sdd_locator_valid() {
  local locator="$1"
  case "$locator" in
    -) return 0 ;;
    project:requirements/*.md) return 0 ;;
    v[0-9]*.[0-9]*.[0-9]*:*) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_slug() {
  local input="$1"
  printf '%s\n' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}
