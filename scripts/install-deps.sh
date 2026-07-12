#!/usr/bin/env bash
set -euo pipefail

# Contract-visible dependency sources:
# claude plugin install "https://github.com/obra/superpowers.git"
# claude plugin install "https://github.com/github/spec-kit.git"

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

install_plugin "superpowers" "https://github.com/obra/superpowers.git"
install_plugin "spec-kit" "https://github.com/github/spec-kit.git"

printf '[done] 所有依赖已就绪\n'
