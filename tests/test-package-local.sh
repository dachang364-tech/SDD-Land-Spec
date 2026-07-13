#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "scripts/package-local.sh"
assert_executable "scripts/package-local.sh"

rm -rf dist
bash scripts/package-local.sh >/tmp/sdd-package-local.out

assert_file_exists "dist/sdd-plugin-v0.2.0.zip"
assert_file_exists "dist/sdd-plugin-v0.2.0.tar.gz"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v0.2.0.zip"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v0.2.0.tar.gz"

archive_contents="/tmp/sdd-package-local-contents.out"
tar -tzf dist/sdd-plugin-v0.2.0.tar.gz >"$archive_contents"

if grep -Eq '^sdd/(dist|docs|tests)(/|$)|^sdd/TESTING\.md$|^sdd/\.git/' "$archive_contents"; then
  fail "package must not include development-only files"
fi

if ! grep -Fxq 'sdd/.claude-plugin/plugin.json' "$archive_contents"; then
  fail "package must include plugin metadata under sdd root"
fi

readme_tmp="/tmp/sdd-package-local-readme.md"
tar -xzf dist/sdd-plugin-v0.2.0.tar.gz -C /tmp sdd/README.md
mv /tmp/sdd/README.md "$readme_tmp"
rmdir /tmp/sdd
assert_contains "$readme_tmp" "# SDD Plugin"
assert_contains "$readme_tmp" "## 安装"
assert_contains "$readme_tmp" "## 使用"
assert_contains "$readme_tmp" "/sdd:init"
if grep -Eq '本项目验证|测试指南|worktree|合并|开发' "$readme_tmp"; then
  fail "packaged README must focus on user usage, not plugin development"
fi

printf 'PASS: local package script\n'
