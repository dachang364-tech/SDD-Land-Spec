# Document Quality Reviewer and Standards-Driven Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement project-scoped template packs, runtime `.sdd/templates/` asset loading, and a unified document reviewer flow for `/sdd:prd`, `/sdd:spec`, `/sdd:plan`.

**Architecture:** The implementation should introduce packaged template-pack assets plus one shared runtime asset helper in `scripts/lib`, then route `/sdd:init` through that helper to materialize `.sdd/templates/`. After the project asset contract is stable, wire `/sdd:prd`, `/sdd:spec`, `/sdd:plan`, and a new `/sdd:review` entry to consume the same project assets and structured reviewer result format, while preserving current metadata style, `## 文档引用` contract, and active-version workflow.

**Tech Stack:** Bash, Claude Code plugin skills, Markdown templates and standards, shell helper libraries in `scripts/lib`, shell contract tests in `tests/*.sh`, packaged artifacts from `scripts/package-local.sh`

## Global Constraints

- 第一阶段只覆盖 `prd / spec / plan`。
- 第一阶段不实现项目模板包来源追踪、内容损坏检测或运行时自动回退。
- `template-pack` 是用户在 `/sdd:init` 时可选择的静态资产集合。
- 模板包名称是人类可读标识，用于初始化时选择，不要求写入项目元数据文件。
- `.sdd/templates/` 是项目级 SDD 文档资产根目录。
- `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和独立 review 入口在运行时只读取 `.sdd/templates/`。
- 如果 `.sdd/templates/` 缺失必要文件，命令必须失败并给出明确错误，而不是自动回退到 Plugin 内置资产。
- 生成阶段与 reviewer 必须基于同一套项目级有效资产执行，避免生成与 review 使用不同标准。
- `doc Reviewer-Subagent` 对外保持单入口，对内支持 `quality` 和 `feasibility` 两个 mode。
- reviewer 在单次 subagent 调用内以串行方式执行有限轮次闭环，不将同一文档的连续优化拆成多个并行 reviewer。
- `PRD / Spec` 的低风险问题允许自动修复；需求语义不清时生成候选改写而不是直接落正文。
- `Plan` 的自动修复权限高于 `PRD / Spec`，可主动修复任务拆分、执行顺序、验证缺口和验收映射等低至中风险问题。
- 通过规则采用“有分数，但阻断项优先”。
- `PRD / Spec / Plan` 三类模板继续沿用当前元数据风格，并统一保留 `## 文档引用` 表与流程契约字段。

---

### Task 1: Add packaged template-pack assets and runtime asset helper

**Files:**
- Create: `assets/template-packs/default-backend/prd/template.md`
- Create: `assets/template-packs/default-backend/prd/quality.standard.md`
- Create: `assets/template-packs/default-backend/spec/template.md`
- Create: `assets/template-packs/default-backend/spec/quality.standard.md`
- Create: `assets/template-packs/default-backend/spec/feasibility.standard.md`
- Create: `assets/template-packs/default-backend/plan/template.md`
- Create: `assets/template-packs/default-backend/plan/quality.standard.md`
- Create: `assets/template-packs/default-backend/plan/feasibility.standard.md`
- Create: `scripts/lib/sdd-template-assets.sh`
- Modify: `tests/test-common-library.sh`
- Create: `tests/test-template-assets.sh`
- Test: `tests/test-common-library.sh`
- Test: `tests/test-template-assets.sh`

**Interfaces:**
- Consumes: `sdd_active_version_dir(root)` from `scripts/lib/sdd-common.sh`
- Produces:
  - `sdd_template_pack_root(plugin_root, pack_name) -> stdout <absolute-pack-path>`
  - `sdd_default_template_pack() -> stdout "default-backend"`
  - `sdd_project_templates_root(project_root) -> stdout <absolute-project-template-root>`
  - `sdd_require_template_asset(project_root, doc_type, asset_name) -> stdout <absolute-asset-path>; exit 2 on missing`
  - `sdd_copy_template_pack(plugin_root, project_root, pack_name) -> copies pack into .sdd/templates/`
  - `sdd_list_template_packs(plugin_root) -> stdout one pack per line`

- [ ] **Step 1: Write the failing helper and asset tests**

Add this import and these assertions near the top of `tests/test-common-library.sh`:

```bash
. scripts/lib/sdd-template-assets.sh
```

```bash
plugin_tmp_assets="$(mktemp -d)"
project_tmp_assets="$(mktemp -d)"
trap 'rm -rf "${tmp:-}" "$plugin_tmp_assets" "$project_tmp_assets"' EXIT
mkdir -p "$plugin_tmp_assets/assets/template-packs/default-backend/prd"
mkdir -p "$plugin_tmp_assets/assets/template-packs/default-backend/spec"
mkdir -p "$plugin_tmp_assets/assets/template-packs/default-backend/plan"
printf '# PRD\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/prd/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/prd/quality.standard.md"
printf '# Spec\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/spec/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/spec/quality.standard.md"
printf '# feasibility\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/plan/template.md"
printf '# quality\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/plan/quality.standard.md"
printf '# feasibility\n' > "$plugin_tmp_assets/assets/template-packs/default-backend/plan/feasibility.standard.md"

pack_name="$(sdd_default_template_pack)"
[[ "$pack_name" == "default-backend" ]] || fail "expected default-backend, got $pack_name"

pack_root="$(sdd_template_pack_root "$plugin_tmp_assets" "default-backend")"
[[ "$pack_root" == "$plugin_tmp_assets/assets/template-packs/default-backend" ]] || fail "expected default pack root, got $pack_root"

list_output="$(sdd_list_template_packs "$plugin_tmp_assets")"
[[ "$list_output" == "default-backend" ]] || fail "expected default-backend listing, got $list_output"

sdd_copy_template_pack "$plugin_tmp_assets" "$project_tmp_assets" "default-backend"
assert_file_exists "$project_tmp_assets/.sdd/templates/prd/template.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/spec/feasibility.standard.md"
assert_file_exists "$project_tmp_assets/.sdd/templates/plan/quality.standard.md"

project_templates_root="$(sdd_project_templates_root "$project_tmp_assets")"
[[ "$project_templates_root" == "$project_tmp_assets/.sdd/templates" ]] || fail "expected project templates root, got $project_templates_root"

prd_template="$(sdd_require_template_asset "$project_tmp_assets" "prd" "template.md")"
[[ "$prd_template" == "$project_tmp_assets/.sdd/templates/prd/template.md" ]] || fail "expected prd template path, got $prd_template"

if sdd_require_template_asset "$project_tmp_assets" "spec" "missing.standard.md" >/tmp/sdd-missing-template.out 2>/tmp/sdd-missing-template.err; then
  fail "expected missing template asset to fail"
fi
assert_contains "/tmp/sdd-missing-template.err" "缺少项目模板资产"
```

Create `tests/test-template-assets.sh` with this failing contract:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_plugin="$(mktemp -d)"
tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_plugin" "$tmp_project"' EXIT

mkdir -p "$tmp_plugin/assets/template-packs/default-backend/prd"
mkdir -p "$tmp_plugin/assets/template-packs/default-backend/spec"
mkdir -p "$tmp_plugin/assets/template-packs/default-backend/plan"
printf '# PRD\n' > "$tmp_plugin/assets/template-packs/default-backend/prd/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/default-backend/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/template.md"
printf '# quality\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_plugin/assets/template-packs/default-backend/plan/feasibility.standard.md"

sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "default-backend"
assert_file_exists "$tmp_project/.sdd/templates/prd/template.md"
assert_file_exists "$tmp_project/.sdd/templates/prd/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/template.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/template.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/quality.standard.md"
assert_file_exists "$tmp_project/.sdd/templates/plan/feasibility.standard.md"

printf 'PASS: template assets\n'
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
bash tests/test-common-library.sh
bash tests/test-template-assets.sh
```

Expected:

```text
FAIL: ... sdd_default_template_pack ... command not found
bash: tests/test-template-assets.sh: No such file or directory
```

- [ ] **Step 3: Add the minimal helper implementation**

Create `scripts/lib/sdd-template-assets.sh` with this content:

```bash
#!/usr/bin/env bash

sdd_default_template_pack() {
  printf 'default-backend\n'
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
  rm -rf "$target_root"
  mkdir -p "$target_root"
  cp -R "$pack_root/prd" "$target_root/prd"
  cp -R "$pack_root/spec" "$target_root/spec"
  cp -R "$pack_root/plan" "$target_root/plan"
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
```

Create the eight default asset files with these minimal but valid first-pass contents:

`assets/template-packs/default-backend/prd/template.md`

```markdown
# PRD：<产品/版本名>

- 日期：<YYYY-MM-DD>
- 类型：PRD

## 1. 背景与目标

提示：说明业务背景、目标和成功结果。
示例：统一任务编排入口，减少人工跟踪和返工。

## 2. 目标用户 / 使用场景

提示：列出主要使用者和核心场景。

## 3. 问题陈述

提示：明确当前痛点、断层或成本来源。

## 4. 范围（In / Out）

### In

- <内容>

### Out

- <内容>

## 5. 需求

### 需求主题 A

- 场景 1：<内容>
- 场景 2：<内容>

## 6. 成功标准

- <可验证结果>

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
```
```

`assets/template-packs/default-backend/prd/quality.standard.md`

```markdown
# PRD Quality Standard

## 元信息

- mode: quality
- doc_type: prd
- pass_threshold: 80
- blocker_priority: strict
- max_rounds: 2

## 检查项定义

- 核心章节完整
- 需求主题与场景清晰
- 成功标准可验证
- 文档引用表完整

## 评分与阈值规则

- 完整性: 25
- 清晰性: 25
- 规范性: 25
- 一致性: 25

## 执行策略

- 允许自动修复结构、措辞、术语和引用表问题
- 语义不清时只生成候选改写

## 输出契约

- output_format: machine+user
```
```

`assets/template-packs/default-backend/spec/template.md`

```markdown
# Functional Specification：<能力名>

- 日期：<YYYY-MM-DD>
- 状态：draft
- 类型：Functional Specification

## 1. 简短总览

提示：概括本 spec 解决的能力边界。

## 2. 范围 / 非范围

### 范围

- <内容>

### 非范围

- <内容>

## 3. 领域能力分块

### 能力 1

- 能力目标：<内容>
- 接口契约：<内容>
- 输入输出：<内容>
- 状态变化：<内容>
- 规则约束：<内容>
- 异常场景：<内容>
- 验收标准：<内容>
- 来源：<PRD 需求主题或场景>

## 4. 依赖与约束

- <内容>

## 5. 数据与一致性要求

- <内容>

## 6. 上下游影响

- <内容>

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
```
```

`assets/template-packs/default-backend/spec/quality.standard.md`

```markdown
# Spec Quality Standard

## 元信息

- mode: quality
- doc_type: spec
- pass_threshold: 82
- blocker_priority: strict
- max_rounds: 3

## 检查项定义

- 能力块结构完整
- 契约、输入输出、异常、来源齐全
- 文档引用表完整
- 与 PRD 术语一致

## 评分与阈值规则

- 完整性: 25
- 清晰性: 25
- 规范性: 25
- 一致性: 25

## 执行策略

- 允许自动修复结构、一致性、引用表和低风险措辞
- 语义歧义输出候选改写

## 输出契约

- output_format: machine+user
```
```

`assets/template-packs/default-backend/spec/feasibility.standard.md`

```markdown
# Spec Feasibility Standard

## 元信息

- mode: feasibility
- doc_type: spec
- pass_threshold: 75
- blocker_priority: medium
- max_rounds: 2

## 检查项定义

- 关键接口契约闭合
- 输入输出可实现
- 异常路径可覆盖
- 验收标准可落地

## 评分与阈值规则

- 可落地性: 25
- 覆盖性: 25
- 闭合性: 25
- 验证性: 25

## 执行策略

- 输出风险与建议
- 高风险语义不直接改正文

## 输出契约

- output_format: machine+user
```
```

`assets/template-packs/default-backend/plan/template.md`

```markdown
# Implementation Plan：<工作项>

- 日期：<YYYY-MM-DD>
- 状态：draft
- 类型：Implementation Plan

## 1. 背景与目标

提示：说明要实现的能力和交付边界。

## 2. 实施范围 / 非范围

### 范围

- <内容>

### 非范围

- <内容>

## 3. 技术方案总览

- <内容>

## 4. 架构边界

- <内容>

## 5. 关键数据流 / 控制流

- <内容>

## 6. 状态变化与一致性要求

- <内容>

## 7. 模块与文件影响

- <内容>

## 8. 接口 / 契约变化

- <内容>

## 9. 风险与兼容性处理

- <内容>

## 10. 测试策略

- <内容>

## 11. Implementation Tasks

### Task 1

- 任务目标：<内容>
- 涉及文件 / 模块：<内容>
- 接口或契约变化：<内容>
- 实现步骤：<内容>
- 验证与完成判据：<内容>
- 与 spec / 技术方案的映射：<内容>

## 12. 验收映射

- <内容>

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
```
```

`assets/template-packs/default-backend/plan/quality.standard.md`

```markdown
# Plan Quality Standard

## 元信息

- mode: quality
- doc_type: plan
- pass_threshold: 85
- blocker_priority: strict
- max_rounds: 3

## 检查项定义

- 方案结构完整
- 任务项细度足够
- 验证与完成判据明确
- 文档引用表完整

## 评分与阈值规则

- 完整性: 25
- 清晰性: 25
- 规范性: 25
- 一致性: 25

## 执行策略

- 允许自动修复结构、重复、顺序和引用表问题

## 输出契约

- output_format: machine+user
```
```

`assets/template-packs/default-backend/plan/feasibility.standard.md`

```markdown
# Plan Feasibility Standard

## 元信息

- mode: feasibility
- doc_type: plan
- pass_threshold: 80
- blocker_priority: high
- max_rounds: 3

## 检查项定义

- 实现路径闭合
- 任务顺序可执行
- 验证策略可落地
- 验收映射完整

## 评分与阈值规则

- 可落地性: 25
- 覆盖性: 25
- 闭合性: 25
- 验证性: 25

## 执行策略

- 允许自动修复任务拆分、顺序和验证缺口
- 架构路线变化只输出建议

## 输出契约

- output_format: machine+user
```
```

Create `tests/test-template-assets.sh` with the content from Step 1.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test-common-library.sh
bash tests/test-template-assets.sh
```

Expected:

```text
PASS: common library
PASS: template assets
```

- [ ] **Step 5: Commit**

```bash
git add assets/template-packs/default-backend scripts/lib/sdd-template-assets.sh tests/test-common-library.sh tests/test-template-assets.sh
git commit -m "feat: add project template pack assets"
```

### Task 2: Materialize template packs during `/sdd:init` and package them

**Files:**
- Modify: `skills/init/SKILL.md`
- Modify: `scripts/package-local.sh`
- Modify: `README.md`
- Modify: `tests/test-skill-contracts.sh`
- Modify: `tests/test-package-local.sh`
- Modify: `tests/test-mvp-acceptance.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-package-local.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `sdd_default_template_pack`, `sdd_list_template_packs`, `sdd_copy_template_pack`
- Produces:
  - `/sdd:init` contract requiring template-pack selection and `.sdd/templates/` creation
  - package artifacts containing `assets/template-packs/**`

- [ ] **Step 1: Write the failing contract tests**

Add these assertions to `tests/test-skill-contracts.sh` after the current `/sdd:init` block:

```bash
assert_contains "skills/init/SKILL.md" "展示可选模板包列表"
assert_contains "skills/init/SKILL.md" '将所选模板包中的 `PRD / Spec / Plan` 模板与标准完整展开到 `.sdd/templates/`'
assert_contains "skills/init/SKILL.md" '如果用户未显式切换，则使用默认模板包'
assert_contains "skills/init/SKILL.md" '不要求把“用户选择了哪个模板包”写入项目元数据文件'
assert_contains "skills/init/SKILL.md" '.sdd/templates/'
assert_not_contains "skills/init/SKILL.md" 'Do not create `.sdd/state.json`.'
```

Add these assertions to `tests/test-mvp-acceptance.sh` after the plugin installation surface block:

```bash
assert_file_exists "assets/template-packs/default-backend/prd/template.md"
assert_file_exists "assets/template-packs/default-backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/default-backend/plan/quality.standard.md"
```

Add these assertions to `tests/test-package-local.sh`:

```bash
assert_contains "$tar_listing" "sdd-local/assets/template-packs/default-backend/prd/template.md"
assert_contains "$tar_listing" "sdd-local/assets/template-packs/default-backend/spec/feasibility.standard.md"
assert_contains "$tar_listing" "sdd-local/assets/template-packs/default-backend/plan/quality.standard.md"
assert_contains "$zip_listing" "sdd-local/assets/template-packs/default-backend/prd/template.md"
assert_contains "$zip_listing" "sdd-local/assets/template-packs/default-backend/spec/feasibility.standard.md"
assert_contains "$zip_listing" "sdd-local/assets/template-packs/default-backend/plan/quality.standard.md"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-package-local.sh
bash tests/test-mvp-acceptance.sh
```

Expected:

```text
FAIL: expected skills/init/SKILL.md to contain: 展示可选模板包列表
FAIL: expected ... assets/template-packs/default-backend/prd/template.md
FAIL: expected ... sdd-local/assets/template-packs/default-backend/prd/template.md
```

- [ ] **Step 3: Update `/sdd:init`, packaging, and README**

Replace the `## Steps` block in `skills/init/SKILL.md` with:

```markdown
## Steps

1. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
   - `.sdd/`
2. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
3. 展示可选模板包列表。
4. 如果用户未显式切换，则使用默认模板包 `default-backend`。
5. 将所选模板包中的 `PRD / Spec / Plan` 模板与标准完整展开到 `.sdd/templates/`。
6. 不创建任何版本目录或版本级 state.json。
7. 不要求把“用户选择了哪个模板包”写入项目元数据文件。
8. 不创建 `prd.md`、`specs/*.md`、`plans/*.md` 或 `decisions/*.md`。
9. 不修改 `CLAUDE.md` 或 `AGENTS.md`。
10. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
11. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。
```
```

Update the `## Output` block in `skills/init/SKILL.md` to:

```markdown
## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
.sdd/templates/
```
```
```

Update the package copy loop in `scripts/package-local.sh`:

```bash
for path in .claude-plugin CONSTITUTION.default.md LICENSE hooks scripts skills assets; do
  if [[ -e "$root_dir/$path" ]]; then
    cp -R "$root_dir/$path" "$package_dir/$path"
  fi
done
```

Update the packaged README skeleton in `scripts/package-local.sh` to include `.sdd/templates/` and template packs in the usage and project structure sections:

```markdown
`/sdd:init` 会在项目中初始化 `.sdd/templates/`，并将所选模板包展开为运行时唯一生效资产。
```

```text
.sdd/
└── templates/
    ├── prd/
    ├── spec/
    └── plan/
```
```

Update `README.md` quick-start expectations with:

```markdown
- `/sdd:init` 创建：
  - `docs/CONSTITUTION.md`
  - `docs/requirements/`
  - `docs/archive/`
  - `.sdd/templates/prd/`
  - `.sdd/templates/spec/`
  - `.sdd/templates/plan/`
- `/sdd:init` 会提示模板包选择；未显式切换时默认使用 `default-backend`。
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-package-local.sh
bash tests/test-mvp-acceptance.sh
```

Expected:

```text
PASS: skill contracts
PASS: package-local
PASS: MVP acceptance
```

- [ ] **Step 5: Commit**

```bash
git add skills/init/SKILL.md scripts/package-local.sh README.md tests/test-skill-contracts.sh tests/test-package-local.sh tests/test-mvp-acceptance.sh
git commit -m "feat: initialize project template assets"
```

### Task 3: Route `/sdd:prd`, `/sdd:spec`, and `/sdd:plan` through project template assets

**Files:**
- Modify: `skills/prd/SKILL.md`
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`
- Create: `tests/test-template-runtime-contract.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-template-runtime-contract.sh`

**Interfaces:**
- Consumes: `sdd_require_template_asset(project_root, doc_type, asset_name)`
- Produces:
  - `/sdd:prd` reads `.sdd/templates/prd/template.md` and `quality.standard.md`
  - `/sdd:spec` reads `.sdd/templates/spec/template.md`, `quality.standard.md`, `feasibility.standard.md`
  - `/sdd:plan` reads `.sdd/templates/plan/template.md`, `quality.standard.md`, `feasibility.standard.md`

- [ ] **Step 1: Write the failing runtime contract tests**

Add these assertions to `tests/test-skill-contracts.sh`:

```bash
assert_contains "skills/prd/SKILL.md" '只读取 `.sdd/templates/prd/template.md`'
assert_contains "skills/prd/SKILL.md" '如果 `.sdd/templates/prd/` 下必要文件缺失，则直接失败'
assert_not_contains "skills/prd/SKILL.md" 'skills/prd/references/prd.md.tmpl'

assert_contains "skills/spec/SKILL.md" '只读取 `.sdd/templates/spec/` 下的模板与标准'
assert_contains "skills/spec/SKILL.md" '自动按顺序触发 `quality -> feasibility`'
assert_contains "skills/spec/SKILL.md" '如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产'

assert_contains "skills/plan/SKILL.md" '只读取 `.sdd/templates/plan/` 下的模板与标准'
assert_contains "skills/plan/SKILL.md" '自动按顺序触发 `quality -> feasibility`'
assert_contains "skills/plan/SKILL.md" '如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产'
```

Create `tests/test-template-runtime-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-template-assets.sh

tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_project"' EXIT
mkdir -p "$tmp_project/.sdd/templates/prd"
mkdir -p "$tmp_project/.sdd/templates/spec"
mkdir -p "$tmp_project/.sdd/templates/plan"
printf '# PRD\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# Spec\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# Plan\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"

assert_file_exists "$(sdd_require_template_asset "$tmp_project" prd template.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" spec feasibility.standard.md)"
assert_file_exists "$(sdd_require_template_asset "$tmp_project" plan quality.standard.md)"

rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
if sdd_require_template_asset "$tmp_project" spec feasibility.standard.md >/tmp/sdd-spec-template.out 2>/tmp/sdd-spec-template.err; then
  fail "expected missing spec feasibility standard to fail"
fi
assert_contains "/tmp/sdd-spec-template.err" "缺少项目模板资产"

printf 'PASS: template runtime contract\n'
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-template-runtime-contract.sh
```

Expected:

```text
FAIL: expected skills/prd/SKILL.md to contain: 只读取 `.sdd/templates/prd/template.md`
PASS: template runtime contract
```

- [ ] **Step 3: Update the skill contracts**

Replace the `## Output` paragraph in `skills/prd/SKILL.md` with:

```markdown
## Output

Write `docs/versions/vX.Y.Z/prd.md` using `.sdd/templates/prd/template.md`.

- 生成前必须读取 `.sdd/templates/prd/template.md` 和 `.sdd/templates/prd/quality.standard.md`。
- 如果 `.sdd/templates/prd/` 下必要文件缺失，则直接失败并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
- `## 文档引用` 是正式机器可检查引用关系。
- `## 上游需求资料` 是人类阅读摘要。
- 影响 PRD 契约内容的 requirement 必须同时出现在 `## 文档引用`。
- 不写 `- 状态：` 行。
```
```

Append this block to `skills/prd/SKILL.md` before `## Boundaries`:

```markdown
## Review flow

- 目标文档写入完成并通过最小结构校验后，自动触发 `quality` reviewer。
- reviewer 只消费当前项目 `.sdd/templates/prd/` 中的模板与标准。
- 低风险结构、术语、引用表和一致性问题允许自动修复。
- 需求语义不清时生成候选改写并等待用户确认。
- `quality` 未通过时阻断进入下一稳定状态。
```
```

Update the `## Steps` section of `skills/spec/SKILL.md` line 44 block to:

```markdown
## Steps

1. Read `prd.md`.
2. 读取 `.sdd/templates/spec/template.md`、`.sdd/templates/spec/quality.standard.md`、`.sdd/templates/spec/feasibility.standard.md`。
3. 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
4. Write `docs/versions/vX.Y.Z/specs/<spec-name>.md` with `- 状态：draft`.
5. 目标文档写入完成并通过最小结构校验后，自动按顺序触发 `quality -> feasibility`。
6. `quality` 强阻断。
7. `feasibility` 默认弱阻断，但必须输出风险与建议。
8. Ask the user to approve or request changes.
9. 用户确认后，将状态切换为 `approved`。
```
```

Update the `## Plan quality rules` block in `skills/plan/SKILL.md` with:

```markdown
## Plan quality rules

- 只读取 `.sdd/templates/plan/` 下的模板与标准。
- 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
- 写入完成并通过最小结构校验后，自动按顺序触发 `quality -> feasibility`。
- `quality` 未通过时阻断。
- `feasibility` 在 `plan` 上比 `spec` 更严格，但仍保留高杠杆技术决策的用户确认边界。
- `Implementation Tasks` 必须是可由 agentic worker 直接执行的 TDD 手册，不是概要 TODO。
- 每个 task 必须包含精确 `Files`、`Interfaces`、`Acceptance Mapping` 和 checkbox steps。
- 测试步骤包含实际测试代码或 contract assertion、运行命令和 expected FAIL/PASS 输出。
- 实现步骤包含足够具体的代码、替换片段、文件内容或修改说明。
- commit 步骤包含具体 `git add` 路径和 `git commit -m` 信息。
- 最终 plan 不得保留占位符（`TBD`、`TODO`、`待定`、`待补充`、`path/to/file` 等）。
- 写出 plan 前必须执行自检：spec coverage、placeholder scan、type/naming consistency，记录在 `## 7. Self-Review`。
```
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-template-runtime-contract.sh
```

Expected:

```text
PASS: skill contracts
PASS: template runtime contract
```

- [ ] **Step 5: Commit**

```bash
git add skills/prd/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md tests/test-skill-contracts.sh tests/test-template-runtime-contract.sh
git commit -m "feat: route document skills through project templates"
```

### Task 4: Add unified reviewer skill contract and structured output model

**Files:**
- Create: `skills/review/SKILL.md`
- Create: `skills/review/references/reviewer-result.schema.json`
- Create: `tests/test-document-reviewer.sh`
- Modify: `tests/test-skill-contracts.sh`
- Modify: `README.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-document-reviewer.sh`

**Interfaces:**
- Consumes: runtime template assets passed by `/sdd:prd`, `/sdd:spec`, `/sdd:plan`
- Produces:
  - reviewer input contract: `document_path`, `document_type`, `mode`, `template_path`, `standard_path`, `repair_policy`, `upstream_paths`, `invocation_source`, `max_rounds`
  - reviewer result schema fields: `document_type`, `mode`, `passed`, `blocked`, `score_or_grade`, `blocking_items`, `auto_repairs`, `remaining_issues`, `requires_user_confirmation`, `candidate_rewrites`, `iterations`, `reached_max_iterations`, `stopped_for_no_improvement`, `user_receipt`

- [ ] **Step 1: Write the failing reviewer tests**

Add these assertions to `tests/test-skill-contracts.sh`:

```bash
assert_file_exists "skills/review/SKILL.md"
assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/SKILL.md" "description: Review and improve PRD, spec, or plan documents"
assert_contains "skills/review/SKILL.md" '`quality`'
assert_contains "skills/review/SKILL.md" '`feasibility`'
assert_contains "skills/review/SKILL.md" 'review -> update -> review'
assert_contains "skills/review/SKILL.md" '单次 subagent 调用内部'
assert_contains "skills/review/SKILL.md" '机器输出'
assert_contains "skills/review/SKILL.md" '用户输出'
assert_contains "skills/review/references/reviewer-result.schema.json" '"document_type"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"requires_user_confirmation"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"candidate_rewrites"'
```

Create `tests/test-document-reviewer.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "skills/review/SKILL.md"
assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/SKILL.md" '文档路径'
assert_contains "skills/review/SKILL.md" '文档类型'
assert_contains "skills/review/SKILL.md" '当前 mode'
assert_contains "skills/review/SKILL.md" '最大循环轮次'
assert_contains "skills/review/SKILL.md" '达到最大循环轮次'
assert_contains "skills/review/SKILL.md" '进入需要用户确认的状态'
assert_contains "skills/review/SKILL.md" '无法继续产生有效改进'
assert_contains "skills/review/SKILL.md" '默认只向用户返回 1 份聚合后的简洁回执'

printf 'PASS: document reviewer\n'
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-document-reviewer.sh
```

Expected:

```text
FAIL: expected file to exist: skills/review/SKILL.md
FAIL: expected file to exist: skills/review/SKILL.md
```

- [ ] **Step 3: Add the reviewer skill contract and schema**

Create `skills/review/SKILL.md` with this content:

```markdown
---
name: review
description: Review and improve PRD, spec, or plan documents. Use for /sdd:review and for post-write review orchestration in /sdd:prd, /sdd:spec, /sdd:plan.
---

# /sdd:review

Review a target document using the project runtime template assets in `.sdd/templates/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `.sdd/templates/` to exist; if missing, stop and ask the user to run `/sdd:init`.
3. Require the target document to exist and pass the minimum pre-review structure gate.
4. 如果必要模板或标准文件缺失，直接失败，不降级到 Plugin 内置资产。

## Structured Input

reviewer 输入应是结构化上下文，而不是模糊的自由文本请求。至少包括：

- 文档路径
- 文档类型
- 当前 mode
- 解析后的模板
- 解析后的标准
- 修复权限策略
- 上游依赖文档路径
- 调用来源（自动触发 / 手动复审）
- 最大循环轮次

## Modes

- `quality`
- `feasibility`

默认触发矩阵：

- `prd -> quality`
- `spec -> quality + feasibility`
- `plan -> quality + feasibility`

## Review Loop

reviewer 在单次 subagent 调用内部完成有限轮次串行闭环：

```text
review -> update -> review -> output
```

停止条件：

1. 达到当前 mode 的通过阈值。
2. 达到最大循环轮次。
3. 进入需要用户确认的状态。
4. 无法继续产生有效改进。

## Repair Policy

- `PRD / Spec` 的低风险问题允许自动修复。
- `PRD / Spec` 的语义歧义生成候选改写，不直接落正文。
- `Plan` 可自动修复任务拆分、执行顺序、测试缺口、验收映射和重复问题。
- 架构路线切换只输出建议，不直接改写。

## Output

reviewer 输出必须区分：

1. 机器输出
2. 用户输出

机器输出至少包含：

- `document_type`
- `mode`
- `passed`
- `blocked`
- `score_or_grade`
- `blocking_items`
- `auto_repairs`
- `remaining_issues`
- `requires_user_confirmation`
- `candidate_rewrites`
- `iterations`
- `reached_max_iterations`
- `stopped_for_no_improvement`

用户输出默认只返回 1 份聚合后的简洁回执，包含：

- 文档类型
- 执行的 mode
- 总迭代轮次
- 自动修复摘要
- 待确认项 / 剩余问题
- 是否阻断后续流程
- 简要质量摘要
```
```

Create `skills/review/references/reviewer-result.schema.json` with:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "reviewer-result",
  "type": "object",
  "required": [
    "document_type",
    "mode",
    "passed",
    "blocked",
    "score_or_grade",
    "blocking_items",
    "auto_repairs",
    "remaining_issues",
    "requires_user_confirmation",
    "candidate_rewrites",
    "iterations",
    "reached_max_iterations",
    "stopped_for_no_improvement",
    "user_receipt"
  ],
  "properties": {
    "document_type": { "type": "string" },
    "mode": { "type": "string", "enum": ["quality", "feasibility"] },
    "passed": { "type": "boolean" },
    "blocked": { "type": "boolean" },
    "score_or_grade": { "type": ["number", "string"] },
    "blocking_items": { "type": "array", "items": { "type": "string" } },
    "auto_repairs": { "type": "array", "items": { "type": "string" } },
    "remaining_issues": { "type": "array", "items": { "type": "string" } },
    "requires_user_confirmation": { "type": "boolean" },
    "candidate_rewrites": { "type": "array", "items": { "type": "string" } },
    "iterations": { "type": "integer", "minimum": 0 },
    "reached_max_iterations": { "type": "boolean" },
    "stopped_for_no_improvement": { "type": "boolean" },
    "user_receipt": {
      "type": "object",
      "required": ["summary", "blocked"],
      "properties": {
        "summary": { "type": "string" },
        "blocked": { "type": "boolean" }
      }
    }
  }
}
```

Update `README.md` command table with:

```markdown
| `/sdd:review [doc-path] [mode?]` | 对已有 PRD、spec 或 plan 重新执行 reviewer |
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-document-reviewer.sh
```

Expected:

```text
PASS: skill contracts
PASS: document reviewer
```

- [ ] **Step 5: Commit**

```bash
git add skills/review/SKILL.md skills/review/references/reviewer-result.schema.json README.md tests/test-skill-contracts.sh tests/test-document-reviewer.sh
git commit -m "feat: add unified document reviewer contract"
```

### Task 5: Add doctor/docs coverage for template assets and reviewer flow

**Files:**
- Modify: `skills/doctor/SKILL.md`
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `tests/test-skill-contracts.sh`
- Create: `tests/test-review-output-contract.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-review-output-contract.sh`

**Interfaces:**
- Consumes: `.sdd/templates/` runtime contract, reviewer result schema
- Produces:
  - `/sdd:doctor` contract diagnosing missing runtime template assets
  - manual verification instructions for template selection and review flow

- [ ] **Step 1: Write the failing doctor/docs tests**

Add these assertions to `tests/test-skill-contracts.sh`:

```bash
assert_contains "skills/doctor/SKILL.md" '.sdd/templates/'
assert_contains "skills/doctor/SKILL.md" '缺少项目模板资产'
assert_contains "skills/doctor/SKILL.md" '/sdd:review'
assert_contains "README.md" '.sdd/templates/'
assert_contains "README.md" '/sdd:review'
assert_contains "TESTING.md" '模板包选择'
assert_contains "TESTING.md" '.sdd/templates/'
assert_contains "TESTING.md" 'reviewer'
```

Create `tests/test-review-output-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/references/reviewer-result.schema.json" '"blocked"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"auto_repairs"'
assert_contains "skills/review/references/reviewer-result.schema.json" '"user_receipt"'
assert_contains "README.md" '/sdd:review'
assert_contains "TESTING.md" '.sdd/templates/'

printf 'PASS: review output contract\n'
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-review-output-contract.sh
```

Expected:

```text
FAIL: expected skills/doctor/SKILL.md to contain: .sdd/templates/
PASS: review output contract
```

- [ ] **Step 3: Update doctor, README, and TESTING**

Append this section to `skills/doctor/SKILL.md`:

```markdown
## Template asset checks

- 检查项目 `.sdd/templates/` 是否存在。
- 检查 `prd/template.md`、`prd/quality.standard.md` 是否存在。
- 检查 `spec/template.md`、`spec/quality.standard.md`、`spec/feasibility.standard.md` 是否存在。
- 检查 `plan/template.md`、`plan/quality.standard.md`、`plan/feasibility.standard.md` 是否存在。
- 如缺失，报告 `缺少项目模板资产`，提示重新执行 `/sdd:init` 或手工修复。
- 可提示用户使用 `/sdd:review` 对现有文档重新收敛质量。
```
```

Add this subsection to `README.md` after quick start:

```markdown
## 项目模板资产

`/sdd:init` 会将所选模板包展开到 `.sdd/templates/`，这是 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和 `/sdd:review` 的运行时唯一模板来源。

```text
.sdd/
└── templates/
    ├── prd/
    │   ├── template.md
    │   └── quality.standard.md
    ├── spec/
    │   ├── template.md
    │   ├── quality.standard.md
    │   └── feasibility.standard.md
    └── plan/
        ├── template.md
        ├── quality.standard.md
        └── feasibility.standard.md
```
```

Append this section to `TESTING.md` after automatic verification:

```markdown
## 模板包与 reviewer 手工验证

1. 运行 `/sdd:init`，确认会提示模板包选择，未显式切换时默认使用 `default-backend`。
2. 确认项目生成 `.sdd/templates/prd/`、`.sdd/templates/spec/`、`.sdd/templates/plan/`。
3. 手工删除 `.sdd/templates/spec/feasibility.standard.md` 后再次运行 `/sdd:spec`，期望命令明确失败，并提示缺少项目模板资产。
4. 重新执行 `/sdd:init` 恢复模板资产。
5. 生成或修改 `prd.md`、`spec.md`、`plan.md` 后，确认 reviewer 自动触发。
6. 对已有文档执行 `/sdd:review <doc-path>`，确认只返回一份聚合用户回执。
```
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-review-output-contract.sh
```

Expected:

```text
PASS: skill contracts
PASS: review output contract
```

- [ ] **Step 5: Commit**

```bash
git add skills/doctor/SKILL.md README.md TESTING.md tests/test-skill-contracts.sh tests/test-review-output-contract.sh
git commit -m "docs: cover template assets and reviewer flow"
```

### Task 6: Run the full regression suite and capture acceptance evidence

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-document-quality-reviewer-implementation.md`
- Test: `tests/test-template-assets.sh`
- Test: `tests/test-template-runtime-contract.sh`
- Test: `tests/test-document-reviewer.sh`
- Test: `tests/test-review-output-contract.sh`
- Test: `tests/test-common-library.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-reference-validation.sh`
- Test: `tests/test-doctor-contract.sh`
- Test: `tests/test-mvp-acceptance.sh`
- Test: `tests/test-package-local.sh`

**Interfaces:**
- Consumes: all prior tasks’ assets, skill contracts, and test suites
- Produces: final verification evidence that the new template-pack and reviewer contract does not regress existing SDD workflow boundaries

- [x] **Step 1: Add the final verification checklist to this plan**

Append this checklist under a temporary working note section at the end of this file while executing the plan:

```markdown
## Execution Verification Notes

- [ ] `bash tests/test-template-assets.sh`
- [ ] `bash tests/test-template-runtime-contract.sh`
- [ ] `bash tests/test-document-reviewer.sh`
- [ ] `bash tests/test-review-output-contract.sh`
- [ ] `bash tests/test-common-library.sh`
- [ ] `bash tests/test-skill-contracts.sh`
- [ ] `bash tests/test-reference-validation.sh`
- [ ] `bash tests/test-doctor-contract.sh`
- [ ] `bash tests/test-mvp-acceptance.sh`
- [ ] `bash tests/test-package-local.sh`
- [ ] `bash scripts/package-local.sh`
- [ ] `git diff --check`
```
```

- [ ] **Step 2: Run each verification command before the final package check**

Run:

```bash
bash tests/test-template-assets.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-document-reviewer.sh
bash tests/test-review-output-contract.sh
bash tests/test-common-library.sh
bash tests/test-skill-contracts.sh
bash tests/test-reference-validation.sh
bash tests/test-doctor-contract.sh
bash tests/test-mvp-acceptance.sh
bash tests/test-package-local.sh
```

Expected:

```text
PASS: template assets
PASS: template runtime contract
PASS: document reviewer
PASS: review output contract
PASS: common library
PASS: skill contracts
PASS: reference validation
PASS: doctor contract
PASS: MVP acceptance
PASS: package-local
```

- [ ] **Step 3: Run packaging and whitespace verification**

Run:

```bash
bash scripts/package-local.sh
git diff --check
```

Expected:

```text
已生成本地包：
<dist zip path>
<dist tar path>
```

and `git diff --check` produces no output.

- [ ] **Step 4: Update the checklist with actual pass/fail results**

Mark the `## Execution Verification Notes` checklist in this file with actual results after execution. If any command fails, keep the item unchecked and note the failing command directly below it.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-07-19-document-quality-reviewer-implementation.md
git commit -m "chore: record reviewer implementation verification"
```

## Self-Review

### Spec coverage

- Template packs in Plugin and `.sdd/templates/` runtime-only usage are covered by Task 1 and Task 2.
- `/sdd:init` pack selection and no metadata persistence are covered by Task 2.
- `/sdd:new` retaining version-only responsibility is covered by Task 2 contract assertions and unchanged behavior.
- `/sdd:prd` / `/sdd:spec` / `/sdd:plan` runtime asset loading and trigger matrix are covered by Task 3.
- Unified reviewer contract, finite serial loop, machine/user outputs, and stop conditions are covered by Task 4.
- Doctor, README, TESTING, and manual verification guidance are covered by Task 5.
- Recommended implementation verification from the spec is covered by Task 6.

### Placeholder scan

- No `TBD`, `TODO`, `implement later`, or dummy `path/to/file` placeholders remain.
- Every task includes exact file paths, explicit commands, and concrete content blocks.

### Type consistency

- Shared helper names are used consistently: `sdd_default_template_pack`, `sdd_template_pack_root`, `sdd_project_templates_root`, `sdd_require_template_asset`, `sdd_copy_template_pack`, `sdd_list_template_packs`.
- Reviewer result fields are consistent across Task 4 tests, skill contract, and schema.
- Runtime asset directories consistently use `.sdd/templates/prd`, `.sdd/templates/spec`, `.sdd/templates/plan`.

## Execution Verification Notes

- [x] `bash tests/test-template-assets.sh`
- [x] `bash tests/test-template-runtime-contract.sh`
- [x] `bash tests/test-document-reviewer.sh`
- [x] `bash tests/test-review-output-contract.sh`
- [x] `bash tests/test-common-library.sh`
- [x] `bash tests/test-skill-contracts.sh`
- [x] `bash tests/test-reference-validation.sh`
- [x] `bash tests/test-doctor-contract.sh`
- [x] `bash tests/test-mvp-acceptance.sh`
- [x] `bash tests/test-package-local.sh`
- [x] `bash scripts/package-local.sh`
- [x] `git diff --check`
