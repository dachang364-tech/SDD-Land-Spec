#!/usr/bin/env bash

sdd_default_template_pack() {
  printf 'backend\n'
}

sdd_template_pack_root() {
  local plugin_root="$1"
  local pack_name="$2"
  local path="$plugin_root/assets/template-packs/$pack_name"
  if [[ ! -d "$path" ]]; then
    printf '模板包不存在：%s\n' "$path" >&2
    return 2
  fi
  printf '%s\n' "$path"
}

sdd_list_template_packs() {
  local plugin_root="$1"
  local base="$plugin_root/assets/template-packs"
  if [[ ! -d "$base" ]]; then
    printf '模板包目录不存在：%s\n' "$base" >&2
    return 2
  fi
  local path
  shopt -s nullglob
  for path in "$base"/*; do
    [[ -d "$path" ]] || continue
    basename "$path"
  done
  shopt -u nullglob
}

sdd_project_templates_root() {
  local project_root="$1"
  printf '%s/.sdd/templates\n' "$project_root"
}

sdd_copy_template_pack() {
  local plugin_root="$1"
  local project_root="$2"
  local pack_name="$3"
  local pack_root
  pack_root="$(sdd_template_pack_root "$plugin_root" "$pack_name")" || return 2
  local target_root
  target_root="$(sdd_project_templates_root "$project_root")"
  mkdir -p "$project_root/.sdd"
  mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"

  cp -R -n "$pack_root/research/." "$target_root/research/" || true
  cp -R -n "$pack_root/prd/." "$target_root/prd/" || true
  cp -R -n "$pack_root/spec/." "$target_root/spec/" || true
  cp -R -n "$pack_root/plan/." "$target_root/plan/" || true
  cp -R -n "$pack_root/dr/." "$target_root/dr/" || true
}

sdd_require_template_asset() {
  local project_root="$1"
  local doc_type="$2"
  local asset_name="$3"
  local path="$project_root/.sdd/templates/$doc_type/$asset_name"
  if [[ ! -f "$path" ]]; then
    printf '缺少项目模板资产：%s\n' "$path" >&2
    return 2
  fi
  printf '%s\n' "$path"
}
