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
zip_listing="/tmp/sdd-package-local-zip-contents.out"
unzip -Z1 "dist/sdd-plugin-v${plugin_version}.zip" >"$zip_listing"

if grep -Eq "^${package_root}/(dist|docs|tests)(/|$)|^${package_root}/TESTING\\.md$|^${package_root}/\\.git/" "$archive_contents"; then
  fail "package must not include development-only files"
fi

if ! grep -Fxq "${package_root}/.claude-plugin/plugin.json" "$archive_contents"; then
  fail "package must include plugin metadata under package root"
fi

assert_contains "$archive_contents" "${package_root}/agents/doc-reviewer.md"
assert_contains "$zip_listing" "${package_root}/agents/doc-reviewer.md"

assert_contains "$archive_contents" "${package_root}/assets/template-packs/backend/research/template.md"
assert_contains "$archive_contents" "${package_root}/assets/project/CLAUDE.md"
assert_contains "$archive_contents" "${package_root}/assets/template-packs/backend/research/quality.standard.md"
assert_contains "$archive_contents" "${package_root}/assets/template-packs/backend/prd/template.md"
assert_contains "$archive_contents" "${package_root}/assets/template-packs/backend/spec/feasibility.standard.md"
assert_contains "$archive_contents" "${package_root}/assets/template-packs/backend/plan/quality.standard.md"
assert_contains "$zip_listing" "${package_root}/assets/template-packs/backend/research/template.md"
assert_contains "$zip_listing" "${package_root}/assets/project/CLAUDE.md"
assert_contains "$zip_listing" "${package_root}/assets/template-packs/backend/research/quality.standard.md"
assert_contains "$zip_listing" "${package_root}/assets/template-packs/backend/prd/template.md"
assert_contains "$zip_listing" "${package_root}/assets/template-packs/backend/spec/feasibility.standard.md"
assert_contains "$zip_listing" "${package_root}/assets/template-packs/backend/plan/quality.standard.md"

readme_tmp="/tmp/sdd-package-local-readme.md"
rm -rf "/tmp/${package_root}"
tar -xzf "dist/sdd-plugin-v${plugin_version}.tar.gz" -C /tmp "${package_root}/README.md"
mv "/tmp/${package_root}/README.md" "$readme_tmp"
rmdir "/tmp/${package_root}"
assert_contains "$readme_tmp" "# SDD Plugin"
assert_contains "$readme_tmp" 'docs/versions/vX.Y.Z'
assert_contains "$readme_tmp" '001-fix-login-null'
assert_contains "$readme_tmp" 'plan/002-001-fix-login-null.md'
assert_contains "$readme_tmp" 'docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md'
assert_contains "$readme_tmp" 'NNN-<tag>-<slug>.md'
assert_not_contains "$readme_tmp" '<tag>-NNNN-<slug>'
assert_not_contains "$readme_tmp" '/sdd:doctor'
assert_not_contains "$readme_tmp" '/sdd:status'
assert_contains "$readme_tmp" "## 安装"
assert_contains "$readme_tmp" "## 使用"
assert_contains "$readme_tmp" "/sdd:init"
assert_contains "$readme_tmp" "用户自行安装"
assert_contains "$readme_tmp" "可选辅助脚本"
assert_contains "$readme_tmp" '`/sdd:init` 不会自动安装依赖插件'
assert_contains "$readme_tmp" '`/sdd:init` 会在项目中初始化 `.sdd/templates/`，并将所选模板包展开为运行时唯一生效资产。'
assert_contains "$readme_tmp" '`/sdd:init` 在项目根目录缺失 `CLAUDE.md` 时会自动生成默认项目协作说明；若已存在则不覆盖。'
assert_contains "$readme_tmp" '`/sdd:init` 不处理 `AGENTS.md`。'
assert_contains "$readme_tmp" '.sdd/templates/'
if grep -Eq '本项目验证|测试指南|worktree|合并|开发' "$readme_tmp"; then
  fail "packaged README must focus on user usage, not plugin development"
fi

printf 'PASS: local package script\n'
