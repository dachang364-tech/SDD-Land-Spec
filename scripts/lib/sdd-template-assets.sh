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

sdd_project_claude_asset_path() {
  local plugin_root="$1"
  printf '%s/assets/project/CLAUDE.md\n' "$plugin_root"
}

sdd_project_claude_target_path() {
  local project_root="$1"
  printf '%s/CLAUDE.md\n' "$project_root"
}

sdd_ensure_project_claude() {
  local plugin_root="$1"
  local project_root="$2"
  local source_path
  local target_path

  source_path="$(sdd_project_claude_asset_path "$plugin_root")"
  target_path="$(sdd_project_claude_target_path "$project_root")"

  if [[ ! -f "$source_path" ]]; then
    printf '项目级 CLAUDE 模板不存在：%s\n' "$source_path" >&2
    return 2
  fi

  if [[ -e "$target_path" ]]; then
    return 0
  fi

  cp "$source_path" "$target_path" || {
    printf '项目级 CLAUDE 模板复制失败：%s -> %s\n' "$source_path" "$target_path" >&2
    return 2
  }
}

sdd_copy_template_pack() {
  local plugin_root="$1"
  local project_root="$2"
  local pack_name="$3"
  local pack_root
  pack_root="$(sdd_template_pack_root "$plugin_root" "$pack_name")" || return 2
  local target_root
  target_root="$(sdd_project_templates_root "$project_root")"
  local required_dir
  local source_dir
  local target_dir
  local source_entry
  local entry_name

  for required_dir in research prd spec plan dr; do
    if [[ ! -d "$pack_root/$required_dir" ]]; then
      printf '模板包缺少必需目录：%s\n' "$pack_root/$required_dir" >&2
      return 2
    fi
  done

  mkdir -p "$project_root/.sdd" || {
    printf '无法创建目录：%s/.sdd\n' "$project_root" >&2
    return 2
  }
  mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr" || {
    printf '无法创建模板目标目录：%s\n' "$target_root" >&2
    return 2
  }

  for required_dir in research prd spec plan dr; do
    source_dir="$pack_root/$required_dir"
    target_dir="$target_root/$required_dir"
    shopt -s dotglob nullglob
    for source_entry in "$source_dir"/*; do
      entry_name="$(basename "$source_entry")"
      if [[ -e "$target_dir/$entry_name" ]]; then
        continue
      fi
      cp -R -n "$source_entry" "$target_dir/" || {
        printf '模板资产复制失败：%s -> %s/\n' "$source_entry" "$target_dir" >&2
        shopt -u dotglob nullglob
        return 2
      }
    done
    shopt -u dotglob nullglob
  done
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
