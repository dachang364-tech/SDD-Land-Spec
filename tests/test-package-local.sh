#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

plugin_version="$(sdd_plugin_version .claude-plugin/plugin.json)"
package_root="$(sdd_json_name .claude-plugin/marketplace.json)"

assert_file_exists "scripts/package-local.sh"
assert_executable "scripts/package-local.sh"

rm -rf dist
bash scripts/package-local.sh >/tmp/sdd-package-local.out

assert_file_exists "dist/sdd-plugin-v${plugin_version}.zip"
assert_file_exists "dist/sdd-plugin-v${plugin_version}.tar.gz"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v${plugin_version}.zip"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v${plugin_version}.tar.gz"

archive_contents="/tmp/sdd-package-local-contents.out"
tar -tzf "dist/sdd-plugin-v${plugin_version}.tar.gz" >"$archive_contents"

if grep -Eq "^${package_root}/(dist|docs|tests)(/|$)|^${package_root}/TESTING\\.md$|^${package_root}/\\.git/" "$archive_contents"; then
  fail "package must not include development-only files"
fi

if ! grep -Fxq "${package_root}/.claude-plugin/plugin.json" "$archive_contents"; then
  fail "package must include plugin metadata under package root"
fi

readme_tmp="/tmp/sdd-package-local-readme.md"
rm -rf "/tmp/${package_root}"
tar -xzf "dist/sdd-plugin-v${plugin_version}.tar.gz" -C /tmp "${package_root}/README.md"
mv "/tmp/${package_root}/README.md" "$readme_tmp"
rmdir "/tmp/${package_root}"
assert_contains "$readme_tmp" "# SDD Plugin"
assert_contains "$readme_tmp" "## 安装"
assert_contains "$readme_tmp" "## 使用"
assert_contains "$readme_tmp" "/sdd:init"
if grep -Eq '本项目验证|测试指南|worktree|合并|开发' "$readme_tmp"; then
  fail "packaged README must focus on user usage, not plugin development"
fi

printf 'PASS: local package script\n'
