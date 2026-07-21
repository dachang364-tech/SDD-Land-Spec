#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
plugin_json="$root_dir/.claude-plugin/plugin.json"
marketplace_json="$root_dir/.claude-plugin/marketplace.json"
dist_dir="$root_dir/dist"
package_root="sdd-local"

if [[ ! -f "$plugin_json" ]]; then
  printf '缺少插件元数据：%s\n' "$plugin_json" >&2
  exit 1
fi

if [[ ! -f "$marketplace_json" ]]; then
  printf '缺少 marketplace 元数据：%s\n' "$marketplace_json" >&2
  exit 1
fi

name="$(awk -F'"' '/"name"[[:space:]]*:/ { print $4; exit }' "$plugin_json")"
version="$(awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$plugin_json")"

if [[ -z "$name" || -z "$version" ]]; then
  printf '无法从 %s 读取 name 或 version。\n' "$plugin_json" >&2
  exit 1
fi

node - "$marketplace_json" "$name" "$version" <<'NODE'
const fs = require('fs');

const [marketplaceJson, pluginName, pluginVersion] = process.argv.slice(2);
const marketplace = JSON.parse(fs.readFileSync(marketplaceJson, 'utf8'));
const plugin = marketplace.plugins.find((entry) => entry.name === pluginName);

if (!plugin) {
  console.error(`marketplace 中缺少插件条目：${pluginName}`);
  process.exit(1);
}

marketplace.metadata = marketplace.metadata || {};
marketplace.metadata.version = pluginVersion;
plugin.version = pluginVersion;

fs.writeFileSync(marketplaceJson, `${JSON.stringify(marketplace, null, 2)}\n`);
NODE

mkdir -p "$dist_dir"
zip_path="$dist_dir/${name}-plugin-v${version}.zip"
tar_path="$dist_dir/${name}-plugin-v${version}.tar.gz"

exclude_args=(
  --exclude='.DS_Store'
)

rm -f "$zip_path" "$tar_path"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

package_dir="$tmp_dir/$package_root"
mkdir -p "$package_dir"

for path in .claude-plugin CONSTITUTION.default.md LICENSE hooks scripts skills agents assets; do
  if [[ -e "$root_dir/$path" ]]; then
    cp -R "$root_dir/$path" "$package_dir/$path"
  fi
done

cat >"$package_dir/README.md" <<'README'
# SDD Plugin

SDD Plugin 是一个面向 Claude Code 的 Specification Driven Development（SDD）工作流插件。它通过一组 `/sdd:*` slash commands，把项目交付流程组织为：需求资料 → PRD → Functional Specification → Implementation Plan → Code → Archive，并提供 Decision Record（DR）变更闭环、统一模板治理和最小 Hook 门控。

## 安装要求

使用前需要：

- 已安装 Claude Code
- 当前机器可以运行 `claude` CLI
- Git 仓库项目
- Bash 环境

本插件依赖以下 Claude Code plugins：

- `superpowers`
- `spec-kit`

## 安装

请用户自行安装依赖插件：

```bash
claude plugin install https://github.com/obra/superpowers.git
claude plugin install https://github.com/github/spec-kit.git
```

如需快捷安装，也可以使用可选辅助脚本：

```bash
scripts/install-deps.sh
```

`/sdd:init` 不会自动安装依赖插件，只会提示用户完成上述安装。

然后把本插件目录添加为本地 marketplace，并安装 `sdd`：

```bash
claude plugin marketplace add /path/to/sdd-plugin
claude plugin install sdd@sdd-local
claude plugin list
```

如果 marketplace 名称不是 `sdd-local`，以 `.claude-plugin/marketplace.json` 中的 `name` 字段为准。

`/sdd:init` 会在项目中初始化 `.sdd/templates/`，并将所选模板包展开为运行时唯一生效资产。

## 使用

在你的项目仓库中启动 Claude Code 后，按下面的主流程使用：

```text
/sdd:init
  → /sdd:new vX.Y.Z
  → /sdd:research <topic>   可选
  → /sdd:prd
  → /sdd:spec
  → /sdd:plan <work-item>
  → /sdd:code <NNN|work-item>
  → /sdd:archive
```

常用命令：

| 命令 | 作用 |
| --- | --- |
| `/sdd:init` | 初始化当前项目的 SDD 目录结构、`docs/CONSTITUTION.md` 与项目运行时模板资产 |
| `/sdd:new vX.Y.Z` | 创建唯一活跃版本目录 |
| `/sdd:research <topic>` | 生成项目级调研资料 |
| `/sdd:prd` | 生成产品需求文档 PRD |
| `/sdd:spec` | 基于 PRD 生成 Functional Specification |
| `/sdd:plan <work-item>` | 基于 approved spec 或 accepted code-class DR 生成 Implementation Plan |
| `/sdd:review [doc-path] [mode?]` | 对已有 research、PRD、spec 或 plan 重新执行 reviewer |
| `/sdd:code <NNN|work-item>` | 按计划执行代码实现 |
| `/sdd:dr <tag> <title>` | 创建 Decision Record |
| `/sdd:dr accept <id>` | 接受 DR，允许后续落地 |
| `/sdd:dr dismiss <id> <reason>` | 驳回 drafting 状态 DR |
| `/sdd:triage [--deep]` | 对用户疑问进行分诊，推荐后续路径并等待用户选择 |
| `/sdd:archive` | 归档当前已完成版本 |

## 变更流程

代码类变更使用 DR 流程：

```text
/sdd:dr fix|feat|chg|arch <title>
  → /sdd:dr accept <id>
  → 如果需要修订规格，先 /sdd:spec
  → /sdd:plan <id>
  → /sdd:code <NNN|id>
```

例如：`/sdd:plan 001-fix-login-null` 会生成 `plan/002-001-fix-login-null.md`。

轻量 fix DR 可跳过 plan，但仍须通过 `/sdd:code <id>` 完成实现与 verification。

## 项目文档结构

插件会在使用项目中维护以下结构：

```text
docs/
├── CONSTITUTION.md
├── archive/
│   └── INDEX.md
└── versions/
    └── vX.Y.Z/
        ├── state.json
        ├── research/
        ├── prd/
        │   └── prd.md
        ├── spec/
        ├── plan/
        ├── dr/
        └── ARCHIVE.md
```

其中，版本级文档目录为 `docs/versions/vX.Y.Z/`。

其中，Decision Record 的标准输出路径为 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。

```text
.sdd/
└── templates/
    ├── research/
    ├── prd/
    ├── spec/
    ├── plan/
    └── dr/
```
README

(
  cd "$tmp_dir"
  tar "${exclude_args[@]}" -czf "$tar_path" "$package_root"
  zip -qr "$zip_path" "$package_root" -x '*/.DS_Store'
)

node - "$package_dir/.claude-plugin/plugin.json" "$package_dir/.claude-plugin/marketplace.json" <<'NODE'
const fs = require('fs');

const [pluginJson, marketplaceJson] = process.argv.slice(2);
const plugin = JSON.parse(fs.readFileSync(pluginJson, 'utf8'));
const marketplace = JSON.parse(fs.readFileSync(marketplaceJson, 'utf8'));
const marketplacePlugin = marketplace.plugins.find((entry) => entry.name === plugin.name);

if (!marketplacePlugin) {
  console.error(`包内 marketplace 中缺少插件条目：${plugin.name}`);
  process.exit(1);
}

if (marketplace.metadata?.version !== plugin.version || marketplacePlugin.version !== plugin.version) {
  console.error(`包内版本不一致：plugin=${plugin.version}, marketplace.metadata=${marketplace.metadata?.version}, marketplace.plugins.${plugin.name}=${marketplacePlugin.version}`);
  process.exit(1);
}
NODE

printf '已生成本地包：\n'
printf '%s\n' "$zip_path"
printf '%s\n' "$tar_path"
