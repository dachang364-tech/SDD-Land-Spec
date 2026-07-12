#!/usr/bin/env bash
set -euo pipefail

# Contract-visible dependency sources:
# claude plugin install "claude-plugins-official/superpowers"
# claude plugin install "claude-plugins-official/spec-kit"

has_plugin() {
  local plugin_name="$1"
  claude plugin list 2>/dev/null | grep -Eq "(^|[[:space:]])${plugin_name}([[:space:]]|$)"
}

install_plugin() {
  local plugin_name="$1"
  local source="$2"
  if has_plugin "$plugin_name"; then
    printf '[skip] %s 已装\n' "$plugin_name"
  else
    printf '[installing] %s...\n' "$plugin_name"
    claude plugin install "$source"
  fi
}

install_plugin "superpowers" "claude-plugins-official/superpowers"
install_plugin "spec-kit" "claude-plugins-official/spec-kit"

printf '[done] 所有依赖已就绪\n'
