# SDD Skills Claude Code 规范化改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持核心能力意图的前提下，完成 SDD 插件全部保留 Skill 的 Claude Code 规范化改造，落地新的 version-scoped 文档结构、统一模板治理和自动 review 编排，并删除 `doctor` / `status`。

**Architecture:** 先以 `/skill-creator` 为约束重写保留 Skill 的 `SKILL.md` 合同，再同步调整模板资产、版本目录、文档路径、引用路径、review 编排、共享 helper 与 Hook 门控，最后更新 README、TESTING 与测试合同，并对一批高风险 Skill 跑完整 `/skill-creator` eval loop。实现保持“模板和标准文件定义规则，Skill 与 reviewer 只编排流程”的边界，并把 archived version 收敛为只读可引用资产。

**Tech Stack:** Claude Code plugin skills, Markdown templates, Bash helper scripts, Bash contract tests, JSON schema-backed review agent orchestration.

## Global Constraints

- 任何 `skills/*/SKILL.md` 的新增、重写、扩展、规范化改造，都必须先经过 `/skill-creator` 约束。
- 除本设计明确重构的领域外，其余 Skill 默认保持现有功能意图，只做 Claude Code Skills 规范化和必要路径适配。
- 所有保留 Skill 的 `SKILL.md` 实现内容必须统一使用中文；英文仅限 slash command、路径、环境变量、JSON key、状态值、文件名与必要技术标识。
- 所有保留 Skill 同时支持显式 slash command 触发与明确语义触发，但语义触发必须保持收敛。
- 运行时文档结构和质量规则只来自 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`；Plugin 内置模板只能由 `/sdd:init` 物化，不可作为运行时 fallback。
- 模板矩阵固定为：`research` = `template.md + quality.standard.md`，`prd` = `template.md + quality.standard.md`，`spec` = `template.md + quality.standard.md + feasibility.standard.md`，`plan` = `template.md + quality.standard.md + feasibility.standard.md`，`dr` = `template.md + quality.standard.md`。
- `docs/requirements/` 完全废弃；版本内目录统一为 `research / prd / spec / plan / dr`。
- `dr` 目录替代 `decisions`，所有正式引用路径统一改为 `../dr/...`。
- archived version 保留在 `docs/versions/vX.Y.Z/` 原位置，只读可引用；不能再被 `research / prd / spec / plan / dr / review / code` 修改或执行。
- `review` 只负责识别路径、识别类型、决定 mode 和编排 reviewer 链路；结构与质量规则下沉到模板和标准文件，不能重新写回 `review` 的硬编码判断矩阵。
- `code` 的直接输入必须是某份 `plan`，只读取该 `plan` 的正式引用闭包。
- `/sdd:doctor` 与 `/sdd:status` 必须被完整删除，并清理 README、TESTING 和测试合同中的命令入口与说明。

---

### Task 1: 固化模板矩阵与 helper，纳入 `dr`

**Files:**
- Modify: `assets/template-packs/backend/research/template.md`
- Modify: `assets/template-packs/backend/research/quality.standard.md`
- Modify: `assets/template-packs/backend/prd/template.md`
- Modify: `assets/template-packs/backend/prd/quality.standard.md`
- Modify: `assets/template-packs/backend/spec/template.md`
- Modify: `assets/template-packs/backend/spec/quality.standard.md`
- Modify: `assets/template-packs/backend/spec/feasibility.standard.md`
- Modify: `assets/template-packs/backend/plan/template.md`
- Modify: `assets/template-packs/backend/plan/quality.standard.md`
- Modify: `assets/template-packs/backend/plan/feasibility.standard.md`
- Create: `assets/template-packs/backend/dr/template.md`
- Create: `assets/template-packs/backend/dr/quality.standard.md`
- Modify: `scripts/lib/sdd-template-assets.sh`
- Test: `tests/test-template-assets.sh`
- Test: `tests/test-template-runtime-contract.sh`
- Test: `tests/test-template-governance-matrix.sh`

**Interfaces:**
- Consumes: `sdd_default_template_pack() -> pack name`, `sdd_list_template_packs(plugin_root) -> stdout lines`, `sdd_copy_template_pack(plugin_root, project_root, pack_name) -> 0|2`, `sdd_require_template_asset(project_root, doc_type, asset_name) -> absolute path`.
- Produces: `${CLAUDE_PROJECT_DIR}/.sdd/templates/{research,prd,spec,plan,dr}/` 运行时资产矩阵，其中 `dr` 新增 `template.md` 与 `quality.standard.md`，所有模板正文与标准说明统一为中文。

- [ ] **Step 1: 写出新增 `dr` 模板矩阵的失败测试**

```bash
assert_file_exists "assets/template-packs/backend/dr/template.md"
assert_file_exists "assets/template-packs/backend/dr/quality.standard.md"
assert_contains "scripts/lib/sdd-template-assets.sh" 'mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"'
assert_contains "scripts/lib/sdd-template-assets.sh" 'cp -R -n "$pack_root/dr/." "$target_root/dr/" || true'
```

把这些断言加入：

- `tests/test-template-assets.sh`
- `tests/test-template-runtime-contract.sh`
- `tests/test-template-governance-matrix.sh`

同时在 `tests/test-template-assets.sh` 的临时 fixture 中新增：

```bash
mkdir -p "$tmp_plugin/assets/template-packs/backend/dr"
printf '# DR\n' > "$tmp_plugin/assets/template-packs/backend/dr/template.md"
printf '# dr quality\n' > "$tmp_plugin/assets/template-packs/backend/dr/quality.standard.md"
```

并验证：

```bash
assert_file_exists "$tmp_project/.sdd/templates/dr/template.md"
assert_file_exists "$tmp_project/.sdd/templates/dr/quality.standard.md"
```

- [ ] **Step 2: 运行失败测试，确认当前缺口暴露**

Run: `bash tests/test-template-assets.sh && bash tests/test-template-runtime-contract.sh && bash tests/test-template-governance-matrix.sh`

Expected: FAIL，原因包含 `dr` 模板资产缺失，或 helper 尚未复制 `dr` 目录。

- [ ] **Step 3: 新增 `dr` 模板资产并把正文统一为中文**

在 `assets/template-packs/backend/dr/template.md` 写入：

```md
# DR-NNN-<tag>

- 状态：drafting
- 标签：<tag>
- 版本：vX.Y.Z
- 日期：YYYY-MM-DD

## 1. 背景

## 2. 决策

## 3. 影响

## 4. 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
```

在 `assets/template-packs/backend/dr/quality.standard.md` 写入：

```md
# DR 质量标准

## 最小结构要求
- 必须包含背景、决策、影响、文档引用。
- 必须显式记录状态与标签。

## 检查维度
- 完整性
- 决策清晰度
- 影响可追踪性
- 引用合法性
- 非越界性

## 自动修复边界
- 允许补齐低风险结构缺口、标题规范化、措辞澄清。
- 不允许擅自改变决策结论或重写终态 DR。
```

同时把现有 `research / prd / spec / plan` 模板与标准文件的中文正文检查一遍，若仍有英文叙述，按同一风格改为中文。

- [ ] **Step 4: 更新 helper，纳入 `dr` 复制逻辑**

把 `scripts/lib/sdd-template-assets.sh` 中的目录创建与复制逻辑改为包含 `dr`：

```bash
mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan" "$target_root/dr"

cp -R -n "$pack_root/research/." "$target_root/research/" || true
cp -R -n "$pack_root/prd/." "$target_root/prd/" || true
cp -R -n "$pack_root/spec/." "$target_root/spec/" || true
cp -R -n "$pack_root/plan/." "$target_root/plan/" || true
cp -R -n "$pack_root/dr/." "$target_root/dr/" || true
```

并确保默认模板包逻辑仍返回：

```bash
sdd_default_template_pack() {
  printf 'backend\n'
}
```

- [ ] **Step 5: 运行模板矩阵测试，确认全部通过**

Run: `bash tests/test-template-assets.sh && bash tests/test-template-runtime-contract.sh && bash tests/test-template-governance-matrix.sh`

Expected: PASS，至少包含：

```text
PASS: template assets
PASS: template runtime contract
PASS: template governance matrix
```

- [ ] **Step 6: Commit**

```bash
git add assets/template-packs/backend scripts/lib/sdd-template-assets.sh tests/test-template-assets.sh tests/test-template-runtime-contract.sh tests/test-template-governance-matrix.sh
git commit -m "feat: add dr runtime template assets"
```

---

### Task 2: 规范化 `init` 与 `new`，落地新目录结构与模板包选择合同

**Files:**
- Modify: `skills/init/SKILL.md`
- Modify: `skills/new/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/<pack>/`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/`, `docs/versions/v*/state.json`.
- Produces: `/sdd:init` 的多模板包选择合同、`/sdd:new` 的 version-scoped 空目录骨架合同、单 active version 规则、`research / prd / spec / plan / dr` 的新版本目录矩阵。

- [ ] **Step 1: 写出 `init/new` 新目录结构的失败断言**

在 `tests/test-skill-contracts.sh` 加入：

```bash
assert_contains "skills/init/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`'
assert_contains "skills/init/SKILL.md" '若用户选择未实现模板包，直接失败并提示不可用'
assert_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/research/'
assert_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/prd/'
assert_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/spec/'
assert_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/plan/'
assert_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/dr/'
assert_not_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/specs/'
assert_not_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/plans/'
assert_not_contains "skills/new/SKILL.md" 'docs/versions/vX.Y.Z/decisions/'
```

- [ ] **Step 2: 运行失败测试，确认当前 Skill 文本仍引用旧目录**

Run: `bash tests/test-skill-contracts.sh`

Expected: FAIL，原因包含 `new` 仍使用 `specs/plans/decisions`，或 `init` 尚未声明 `dr` 模板目录与未实现模板包失败语义。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/init/SKILL.md`**

将 `skills/init/SKILL.md` 改写为中文合同，至少明确：

```md
## Template Packs

- 支持模板包选择机制，例如 `backend`、`frontend`。
- 当前仅实现 `backend`。
- 若用户选择未实现模板包，直接失败并说明当前不可用。
- 若用户未显式切换，则使用默认模板包。
- `/sdd:init` 会将所选模板包中的 `research / prd / spec / plan / dr` 模板与标准物化到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`。
- 重复执行只补齐缺失文件，不覆盖用户已定制模板。
```

同时保留：

- 不创建 version 内目录
- 不安装依赖
- 结果回执简短汇总

- [ ] **Step 4: 用 `/skill-creator` 规范重写 `skills/new/SKILL.md`**

将 `skills/new/SKILL.md` 的创建目录块改为：

```text
docs/versions/vX.Y.Z/
docs/versions/vX.Y.Z/state.json
docs/versions/vX.Y.Z/research/
docs/versions/vX.Y.Z/prd/
docs/versions/vX.Y.Z/spec/
docs/versions/vX.Y.Z/plan/
docs/versions/vX.Y.Z/dr/
```

并明确：

```md
- 这些目录都创建为空目录。
- 不预建 `prd/prd.md`。
- 不预建任何 `research/*.md`、`spec/*.md`、`plan/*.md`、`dr/*.md`。
- 若已存在 active version，必须先运行 `/sdd:archive`。
- `/sdd:new` 不更新 `docs/archive/INDEX.md`。
```

- [ ] **Step 5: 运行 Skill 合同测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh`

Expected: PASS，且不再出现 `specs/plans/decisions` 旧目录作为创建结果。

- [ ] **Step 6: Commit**

```bash
git add skills/init/SKILL.md skills/new/SKILL.md tests/test-skill-contracts.sh tests/test-mvp-acceptance.sh
git commit -m "fix: align init and new skill contracts"
```

---

### Task 3: 规范化 `research` 与 `prd`，落地新路径、命名与更新策略

**Files:**
- Modify: `skills/research/SKILL.md`
- Modify: `skills/prd/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-reference-validation.sh`

**Interfaces:**
- Consumes: `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/quality.standard.md`, active version `state.json`.
- Produces: version-scoped `research` 与 `prd` 技能合同；`research` 的 `<type>-<YYYY-MM-DD>-<slug>.md` 命名规则；`prd/prd.md` 的讨论后创建、确认后更新语义。

- [ ] **Step 1: 写出 `research/prd` 新路径和更新语义的失败断言**

在 `tests/test-skill-contracts.sh` 加入：

```bash
assert_contains "skills/research/SKILL.md" 'docs/versions/vX.Y.Z/research/<type>-<YYYY-MM-DD>-<slug>.md'
assert_contains "skills/research/SKILL.md" 'research 文档没有状态机制'
assert_contains "skills/research/SKILL.md" '同名文档存在时，用户确认后可直接更新'
assert_not_contains "skills/research/SKILL.md" 'docs/requirements/'
assert_contains "skills/prd/SKILL.md" 'docs/versions/vX.Y.Z/prd/prd.md'
assert_contains "skills/prd/SKILL.md" '如果 `prd/prd.md` 已存在，先与用户讨论并确认后更新'
assert_contains "skills/prd/SKILL.md" '不走 `DR` 变更门'
```

- [ ] **Step 2: 运行失败测试，确认当前 Skill 仍引用旧 research 路径或旧 PRD 位置**

Run: `bash tests/test-skill-contracts.sh`

Expected: FAIL，原因包含 `research` 仍指向 `docs/requirements/` 或 `prd` 未指向 `prd/prd.md`。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/research/SKILL.md`**

将 `skills/research/SKILL.md` 改为至少包含：

```md
## Output

- 输出路径：`docs/versions/vX.Y.Z/research/<type>-<YYYY-MM-DD>-<slug>.md`
- `<type>` 由用户给出，使用 kebab-case。
- `<date>` 使用 `YYYY-MM-DD`。
- research 文档没有状态机制。

## Update Rules

- 若同名文档已存在，先向用户确认。
- 用户确认后可直接更新同名文档。
- `/sdd:research` 不自动触发 review，但允许后续手动 `/sdd:review`。
```

并明确：

- 必须要求 active version
- archived version 禁止执行

- [ ] **Step 4: 用 `/skill-creator` 规范重写 `skills/prd/SKILL.md`**

将 `skills/prd/SKILL.md` 改为至少包含：

```md
## Output

- 正式输出路径：`docs/versions/vX.Y.Z/prd/prd.md`
- 一个版本只有一个正式 PRD。

## Update Rules

- `/sdd:prd` 需要先与用户讨论，再根据模板生成或更新文档。
- 如果 `prd/prd.md` 不存在，则创建。
- 如果 `prd/prd.md` 已存在，默认不直接覆盖；必须先与用户确认，再更新同一文件。
- `prd` 不走 `DR` 变更门。
```

并明确：

- 自动触发 `quality` reviewer 及其 subagent 链路
- 不强制 `## 文档引用` 表，由模板与标准定义结构要求

- [ ] **Step 5: 运行路径与合同测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-reference-validation.sh`

Expected: PASS，`research` 不再引用 `docs/requirements/`，`prd` 固定到 `prd/prd.md`。

- [ ] **Step 6: Commit**

```bash
git add skills/research/SKILL.md skills/prd/SKILL.md tests/test-skill-contracts.sh tests/test-reference-validation.sh
git commit -m "fix: normalize research and prd skill contracts"
```

---

### Task 4: 规范化 `spec` 与 `plan`，落地单数目录、状态门与 DR 变更门

**Files:**
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-reference-validation.sh`

**Interfaces:**
- Consumes: `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/*`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/*`, active version `state.json`, 文档自身状态字段。
- Produces: `docs/versions/vX.Y.Z/spec/<slug>.md` 与 `docs/versions/vX.Y.Z/plan/<slug>.md` 的单数目录合同、终态后必须转 `DR` 的更新规则、`quality -> feasibility` 自动 review 链路。

- [ ] **Step 1: 写出 `spec/plan` 单数目录和状态门的失败断言**

在 `tests/test-skill-contracts.sh` 加入：

```bash
assert_contains "skills/spec/SKILL.md" 'docs/versions/vX.Y.Z/spec/<slug>.md'
assert_contains "skills/plan/SKILL.md" 'docs/versions/vX.Y.Z/plan/<slug>.md'
assert_contains "skills/spec/SKILL.md" '若同名文档已终态，禁止直接修改，必须转 `DR`'
assert_contains "skills/plan/SKILL.md" '若同名文档已终态，禁止直接修改，必须转 `DR`'
assert_contains "skills/spec/SKILL.md" '若同名文档未终态，也需用户确认后更新'
assert_contains "skills/plan/SKILL.md" '若同名文档未终态，也需用户确认后更新'
assert_not_contains "skills/spec/SKILL.md" 'docs/versions/vX.Y.Z/specs/'
assert_not_contains "skills/plan/SKILL.md" 'docs/versions/vX.Y.Z/plans/'
```

- [ ] **Step 2: 运行失败测试，确认当前 Skill 文本仍使用复数目录或缺少状态门**

Run: `bash tests/test-skill-contracts.sh`

Expected: FAIL。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/spec/SKILL.md`**

核心合同至少包含：

```md
## Output

- 输出路径：`docs/versions/vX.Y.Z/spec/<slug>.md`
- 一个版本允许多份 spec。

## Update Rules

- 若创建新 slug 文档，按正常流程创建。
- 若更新同名文档，先读取文档状态。
- 若已终态，禁止直接修改，必须改走 `DR`。
- 若未终态，也需用户确认后更新。
```

同时明确：

- 自动触发 `quality -> feasibility`
- `quality` 未通过时，不进入 `feasibility`
- `## 文档引用` 表要求由模板与标准定义

- [ ] **Step 4: 用 `/skill-creator` 规范重写 `skills/plan/SKILL.md`**

核心合同至少包含：

```md
## Output

- 输出路径：`docs/versions/vX.Y.Z/plan/<slug>.md`
- 一个版本允许多份 plan。

## Update Rules

- 若创建新 slug 文档，按正常流程创建。
- 若更新同名文档，先读取文档状态。
- 若已终态，禁止直接修改，必须改走 `DR`。
- 若未终态，也需用户确认后更新。
```

并明确：

- 自动触发 `quality -> feasibility`
- `plan` 的结构与 `## 文档引用` 表规则由模板与标准定义

- [ ] **Step 5: 运行路径与状态门测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-reference-validation.sh`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add skills/spec/SKILL.md skills/plan/SKILL.md tests/test-skill-contracts.sh tests/test-reference-validation.sh
git commit -m "fix: align spec and plan skill contracts"
```

---

### Task 5: 规范化 `dr`，把 `decisions/` 迁为 `dr/`

**Files:**
- Modify: `skills/dr/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-dr-filename-contract.sh`
- Test: `tests/test-reference-validation.sh`

**Interfaces:**
- Consumes: `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/quality.standard.md`, active version `state.json`, 现有 DR tag/slug/ID 规则。
- Produces: `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md` 路径合同、`dr / plan / spec` 引用边界、终态 DR 必须新建新文档的规则。

- [ ] **Step 1: 写出 `dr` 新目录和引用边界的失败断言**

在 `tests/test-skill-contracts.sh` 与 `tests/test-dr-filename-contract.sh` 加入：

```bash
assert_contains "skills/dr/SKILL.md" 'docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md'
assert_not_contains "skills/dr/SKILL.md" 'docs/versions/vX.Y.Z/decisions/'
assert_contains "skills/dr/SKILL.md" '正式文档引用只允许：`dr / plan / spec`'
assert_contains "skills/dr/SKILL.md" '若同名 `DR` 已终态，不能回写，必须新建新的 `DR`'
```

并在引用测试中加入：

```bash
assert_not_contains "skills/dr/SKILL.md" 'project:requirements/'
assert_not_contains "skills/dr/SKILL.md" '../decisions/'
assert_contains "skills/dr/SKILL.md" '../dr/'
```

- [ ] **Step 2: 运行失败测试，确认当前 `dr` 仍使用 `decisions/` 和旧引用语义**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-dr-filename-contract.sh && bash tests/test-reference-validation.sh`

Expected: FAIL。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/dr/SKILL.md`**

把 Create mode 的关键写入路径改为：

```md
1. 扫描 `docs/versions/vX.Y.Z/dr/*.md`。
2. 生成版本内递增三位编号 `NNN`。
3. 写入 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。
```

并明确：

```md
- `DR` 的正式文档引用只允许 `dr / plan / spec`。
- 不允许 `prd / research`。
- 若目标 `DR` 已终态，不能回写，必须新建新的 `DR`。
- 自动触发 `quality` reviewer 及其 subagent 链路，不触发 `feasibility`。
```

同时保留：

- `fix | feat | chg | arch | spec | doc | typo` tag 枚举
- `NNN-<tag>-<slug>.md` 文件命名
- `DR ID`、slug 规则、标题标识规则

- [ ] **Step 4: 统一替换正式引用中的历史 `../decisions/...` 路径**

至少扫描并修正以下范围中的正式引用路径：

- `skills/`
- `tests/`
- `README.md`
- `TESTING.md`
- `assets/template-packs/backend/`

将历史 `../decisions/...` 统一替换为 `../dr/...`，并确保 `tests/test-reference-validation.sh` 能验证无残留。

- [ ] **Step 5: 运行 DR 路径、命名与引用测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-dr-filename-contract.sh && bash tests/test-reference-validation.sh`

Expected: PASS，且不再出现 `decisions/` 或 `../decisions/`。

- [ ] **Step 6: Commit**

```bash
git add skills/dr/SKILL.md tests/test-skill-contracts.sh tests/test-dr-filename-contract.sh tests/test-reference-validation.sh
git commit -m "fix: migrate dr contracts to dr directory"
```

---

### Task 6: 规范化 `review`，按路径自动识别类型与 mode

**Files:**
- Modify: `skills/review/SKILL.md`
- Modify: `skills/review/references/reviewer-result.schema.json`
- Modify: `agents/doc-reviewer.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-review-output-contract.sh`
- Test: `tests/test-document-reviewer.sh`

**Interfaces:**
- Consumes: 受管 `doc-path`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/*`、review mode 矩阵。
- Produces: 自动识别 `document_type` 与 mode 链路的统一 `/sdd:review` 合同；`research/prd/dr -> quality`，`spec/plan -> quality -> feasibility`；archived version 禁止 review 的 admission 规则。

- [ ] **Step 1: 写出 `review` 自动识别路径与 mode 的失败断言**

在 `tests/test-skill-contracts.sh` 加入：

```bash
assert_contains "skills/review/SKILL.md" '用户提供 `doc-path`'
assert_contains "skills/review/SKILL.md" '系统自动识别 `document_type`'
assert_contains "skills/review/SKILL.md" '系统自动决定 mode 或 mode 链路'
assert_contains "skills/review/SKILL.md" '`docs/versions/vX.Y.Z/dr/*.md`'
assert_contains "skills/review/SKILL.md" 'dr       -> quality'
assert_contains "skills/review/SKILL.md" '不是受支持的 SDD 文档路径'
assert_contains "skills/review/SKILL.md" '不能对 archived version 的文档执行任何操作'
```

- [ ] **Step 2: 运行失败测试，确认当前 `review` 尚未支持 `dr` 与路径自动识别**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-review-output-contract.sh && bash tests/test-document-reviewer.sh`

Expected: FAIL。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/review/SKILL.md`**

关键合同至少包含：

```md
## Invocation

- 用户主要提供 `doc-path`。
- 系统根据路径自动识别 `document_type`。
- 系统根据类型自动决定 mode 或 mode 链路。
- 受支持路径仅限：
  - `docs/versions/vX.Y.Z/research/*.md`
  - `docs/versions/vX.Y.Z/prd/prd.md`
  - `docs/versions/vX.Y.Z/spec/*.md`
  - `docs/versions/vX.Y.Z/plan/*.md`
  - `docs/versions/vX.Y.Z/dr/*.md`
- 不在矩阵内则直接失败，并提示“不是受支持的 SDD 文档路径”。
```

并保留自动链路：

```text
research -> quality
prd      -> quality
dr       -> quality
spec     -> quality -> feasibility
plan     -> quality -> feasibility
```

- [ ] **Step 4: 调整 reviewer schema 与 agent，纳入 `dr` 与路径驱动合同**

在 `skills/review/references/reviewer-result.schema.json` 中允许：

```json
"document_type": {
  "enum": ["research", "prd", "spec", "plan", "dr"]
}
```

在 `agents/doc-reviewer.md` 中补充：

```md
- archived version 文档不得执行 review。
- `review` 的职责是读取调用方传入的模板和标准路径，不重新硬编码文档结构规则。
- `dr` 只允许 `quality`，不允许 `feasibility`。
```

- [ ] **Step 5: 运行 review 合同测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-review-output-contract.sh && bash tests/test-document-reviewer.sh`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add skills/review/SKILL.md skills/review/references/reviewer-result.schema.json agents/doc-reviewer.md tests/test-skill-contracts.sh tests/test-review-output-contract.sh tests/test-document-reviewer.sh
git commit -m "fix: normalize review orchestration contracts"
```

---

### Task 7: 迁移共享 helper 与 PreToolUse Hook 到新路径矩阵

**Files:**
- Modify: `scripts/lib/sdd-common.sh`
- Modify: `scripts/hooks/pre-tool-use.sh`
- Modify: `tests/fixtures/valid-project.sh`
- Test: `tests/test-common-library.sh`
- Test: `tests/test-pre-tool-use.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `docs/versions/vX.Y.Z/state.json`、`research / prd / spec / plan / dr` 新路径矩阵、archived version 只读规则、DR ID 与 plan basename 解析规则。
- Produces: 与 spec 一致的共享运行时语义；废弃 `docs/requirements/`、`decisions/`、`specs/`、`plans/` 旧路径；移除 `/sdd:doctor` 残留提示；PreToolUse Hook 对新目录和 archived version 执行真实门控。

- [ ] **Step 1: 写出 helper 与 Hook 迁移的失败断言**

在 `tests/test-common-library.sh`、`tests/test-pre-tool-use.sh` 与 `tests/test-mvp-acceptance.sh` 加入：

```bash
assert_not_contains "scripts/lib/sdd-common.sh" '/sdd:doctor'
assert_not_contains "scripts/lib/sdd-common.sh" 'project:requirements/'
assert_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/prd/prd.md'
assert_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/spec/*.md'
assert_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/plan/'
assert_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/dr/'
assert_not_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/specs/*.md'
assert_not_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/plans/'
assert_not_contains "scripts/hooks/pre-tool-use.sh" 'docs/versions/v*/decisions/'
assert_not_contains "scripts/hooks/pre-tool-use.sh" 'docs/requirements/*.md'
```

并在 `tests/test-pre-tool-use.sh` 中新增可执行断言，至少包含：

```bash
mkdir -p "$tmp/docs/versions/v0.2.0/research" "$tmp/docs/versions/v0.2.0/prd" "$tmp/docs/versions/v0.2.0/spec" "$tmp/docs/versions/v0.2.0/plan" "$tmp/docs/versions/v0.2.0/dr"
printf '{\n  "version": "v0.2.0",\n  "state": "archived",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": "2026-07-20T00:00:00Z"\n}\n' > "$tmp/docs/versions/v0.2.0/state.json"
printf '# PRD\n' > "$tmp/docs/versions/v0.2.0/prd/prd.md"
printf '# Spec\n\n- 状态：approved\n' > "$tmp/docs/versions/v0.2.0/spec/spec.md"
printf '# DR-001-fix：Archived\n\n- 状态：accepted\n- class：code\n- tag：fix\n- spec_change：no\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.2.0/dr/001-fix-archived.md"

rm "$tmp/docs/versions/v0.1.0/prd/prd.md"
if run_hook "$tmp" "docs/versions/v0.1.0/spec/new-spec.md" >/tmp/sdd-hook-new-spec.out 2>/tmp/sdd-hook-new-spec.err; then
  fail "expected spec write without prd/prd.md to fail"
fi
assert_contains "/tmp/sdd-hook-new-spec.err" "请先完成 /sdd:prd"

printf '# PRD\n' > "$tmp/docs/versions/v0.1.0/prd/prd.md"
printf '# Spec\n\n- 状态：draft\n' > "$tmp/docs/versions/v0.1.0/spec/spec.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plan/003-login.md" >/tmp/sdd-hook-plan.out 2>/tmp/sdd-hook-plan.err; then
  fail "expected plan write with only draft specs to fail"
fi
assert_contains "/tmp/sdd-hook-plan.err" "approved"

printf '# Spec\n\n- 状态：approved\n' > "$tmp/docs/versions/v0.1.0/spec/spec.md"
printf '# DR-002-chg：Policy\n\n- 状态：drafting\n- class：code\n- tag：chg\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/dr/002-chg-policy.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plan/004-002-chg-policy.md" >/tmp/sdd-hook-dr-plan.out 2>/tmp/sdd-hook-dr-plan.err; then
  fail "expected dr-backed plan write with drafting dr to fail"
fi
assert_contains "/tmp/sdd-hook-dr-plan.err" "期望 accepted"

for archived_target in \
  "docs/versions/v0.2.0/research/demo-2026-07-21-scope.md" \
  "docs/versions/v0.2.0/prd/prd.md" \
  "docs/versions/v0.2.0/spec/archived-spec.md" \
  "docs/versions/v0.2.0/plan/001-archived.md" \
  "docs/versions/v0.2.0/dr/002-fix-archived-followup.md"; do
  if run_hook "$tmp" "$archived_target" >/tmp/sdd-hook-archived.out 2>/tmp/sdd-hook-archived.err; then
    fail "expected archived write to fail for $archived_target"
  fi
  assert_contains "/tmp/sdd-hook-archived.err" "archived"
done
```

- [ ] **Step 2: 运行失败测试，确认当前运行时仍引用旧目录与旧提示**

Run: `bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-mvp-acceptance.sh`

Expected: FAIL，原因包含旧路径矩阵、`/sdd:doctor` 提示或 archived version 缺少真实禁写门控。

- [ ] **Step 3: 修改 `scripts/lib/sdd-common.sh`，统一共享语义**

至少完成以下调整：

```bash
- 移除所有 `/sdd:doctor` 残留提示，改为直接说明当前结构或状态错误。
- 将 `sdd_locator_valid()` 中的 `project:requirements/*.md` 废弃，按新信息架构收敛合法 locator。
- 将 DR 目录相关帮助语义从 `decisions` 迁为 `dr`。
- 如果需要复用 archived version 判断，新增统一 helper，而不是在 Hook 和其他入口各写一份。
```

- [ ] **Step 4: 修改 `scripts/hooks/pre-tool-use.sh` 与 fixture，迁移到新矩阵**

把门控规则迁为：

```text
spec  -> docs/versions/vX.Y.Z/spec/*.md       前置 prd/prd.md
plan  -> docs/versions/vX.Y.Z/plan/*.md       前置 spec/*.md approved 或对应 dr/*.md accepted
dr    -> docs/versions/vX.Y.Z/dr/*.md         允许写 active version
prd   -> docs/versions/vX.Y.Z/prd/prd.md      允许写 active version
research -> docs/versions/vX.Y.Z/research/*.md 允许写 active version
```

同时更新 `tests/fixtures/valid-project.sh`，把测试工程骨架改为：

```text
docs/versions/v0.1.0/
├── state.json
├── research/
├── prd/prd.md
├── spec/spec.md
├── plan/001-feature-login.md
└── dr/001-fix-login-null.md
```

并新增 archived fixture 或在现有 fixture 中补一份 `state: archived` 的版本，用于禁写验证。

- [ ] **Step 5: 运行共享 helper 与 Hook 测试**

Run: `bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-mvp-acceptance.sh`

Expected: PASS，至少包含：

```text
PASS: common library
PASS: pre-tool-use hook
PASS: MVP acceptance
```

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/sdd-common.sh scripts/hooks/pre-tool-use.sh tests/fixtures/valid-project.sh tests/test-common-library.sh tests/test-pre-tool-use.sh tests/test-mvp-acceptance.sh
git commit -m "fix: align runtime hook and helpers with new document matrix"
```

---

### Task 8: 规范化 `archive`、`triage` 与 `code`，收紧只读和输入边界

**Files:**
- Modify: `skills/archive/SKILL.md`
- Modify: `skills/triage/SKILL.md`
- Modify: `skills/code/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-reference-validation.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: active version `state.json`, archived version 只读规则, `ARCHIVE.md + docs/archive/INDEX.md`, `plan` 的正式引用闭包。
- Produces: 继续沿用索引式归档模型的 `archive` 合同；保持轻量输出的 `triage` 合同；仅以 `plan` 为直接输入的 `code` 合同，并在测试中落下 archived 只读和 plan-closure 边界验证。

- [ ] **Step 1: 写出 `archive/triage/code` 新边界的失败断言**

在 `tests/test-skill-contracts.sh` 加入：

```bash
assert_contains "skills/archive/SKILL.md" 'docs/archive/INDEX.md'
assert_contains "skills/archive/SKILL.md" '归档不移动版本目录'
assert_contains "skills/archive/SKILL.md" '归档后的版本只能查询和引用，不能再修改或 review'
assert_contains "skills/triage/SKILL.md" '可读取 archived version 的文档作为参考'
assert_contains "skills/code/SKILL.md" '直接输入必须是某份 `plan`'
assert_contains "skills/code/SKILL.md" '只读取该 `plan` 的 `## 文档引用` 闭包'
assert_contains "skills/code/SKILL.md" '不默认扫描整个 version'
assert_contains "skills/code/SKILL.md" 'archived version 中的 `plan` 不可执行'
```

并在验收测试中加入可执行断言，例如：

```bash
assert_contains "skills/code/SKILL.md" '只读取该 `plan` 的 `## 文档引用` 闭包'
assert_not_contains "skills/code/SKILL.md" '扫描整个 version'
assert_contains "skills/triage/SKILL.md" '不修改文档，不运行 archive，不替用户创建 DR'
```

如果当前仓库已有 `tests/test-code-contract.sh` 或等价测试文件，则在其中加入 archived version 的负向验证；若没有，则在 `tests/test-mvp-acceptance.sh` 中新增最小断言，至少验证：

```bash
assert_not_contains "skills/code/SKILL.md" '读取整个版本'
assert_contains "skills/code/SKILL.md" '若目标 `plan` 所在 version 已归档，直接失败'
```

- [ ] **Step 2: 运行失败测试，确认当前 Skill 仍缺少这些边界说明**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-reference-validation.sh && bash tests/test-mvp-acceptance.sh`

Expected: FAIL。

- [ ] **Step 3: 用 `/skill-creator` 规范重写 `skills/archive/SKILL.md`**

保留当前模型并显式写出：

```md
- `/sdd:archive` 归档的是整个 active version。
- 归档不移动版本目录。
- 版本保留在 `docs/versions/vX.Y.Z/` 原位置。
- 版本内生成或更新 `ARCHIVE.md`。
- `docs/archive/INDEX.md` 维护全局归档索引。
- archived version 进入只读，只能查询和引用。
```

并把模板中的旧目录示例改成新目录：

```md
| Plans | [plan/](./plan/) | 实施记录 |
| DRs | [dr/](./dr/) | 决策记录 |
```

- [ ] **Step 4: 用 `/skill-creator` 规范重写 `skills/triage/SKILL.md` 与 `skills/code/SKILL.md`**

`triage` 至少写明：

```md
- 主要输出下一步应走哪个 SDD 文档路径。
- 可读取 archived version 的文档作为参考。
- 不修改文档，不运行 archive，不替用户创建 DR。
```

`code` 至少写明：

```md
- `/sdd:code` 的直接输入必须是某份 `plan`。
- 只读取该 `plan` 的 `## 文档引用` 闭包。
- 不默认扫描整个 version。
- 不默认读取未被该 `plan` 正式引用的文档。
- 若目标 `plan` 所在 version 已归档，直接失败。
```

- [ ] **Step 5: 运行边界测试**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-reference-validation.sh && bash tests/test-mvp-acceptance.sh`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add skills/archive/SKILL.md skills/triage/SKILL.md skills/code/SKILL.md tests/test-skill-contracts.sh tests/test-reference-validation.sh tests/test-mvp-acceptance.sh
git commit -m "fix: align archive triage and code contracts"
```

---

### Task 9: 删除 `doctor` 与 `status`，清理 README、TESTING 与测试合同

**Files:**
- Delete: `skills/doctor/SKILL.md`
- Delete: `skills/status/SKILL.md`
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `tests/test-skill-contracts.sh`
- Modify: `tests/test-doctor-contract.sh`
- Modify: `tests/test-mvp-acceptance.sh`
- Modify: `tests/test-package-local.sh`

**Interfaces:**
- Consumes: 当前 README、TESTING、测试脚本、fixture 与共享 helper 中的 `doctor / status` 命令说明与断言。
- Produces: 删除这两个命令后的文档、测试、fixture 与公共提示合同；README 中新的文档树、模板矩阵和命令集合说明；不再残留 `doctor`、`docs/requirements/`、旧目录命名的帮助语义。

- [ ] **Step 1: 写出删除 `doctor/status` 后的失败断言**

在 `tests/test-skill-contracts.sh` 中将旧断言替换为：

```bash
assert_file_not_exists "skills/doctor/SKILL.md"
assert_file_not_exists "skills/status/SKILL.md"
assert_not_contains "README.md" '/sdd:doctor'
assert_not_contains "README.md" '/sdd:status'
assert_not_contains "TESTING.md" '/sdd:doctor'
assert_not_contains "TESTING.md" '/sdd:status'
```

同时在 `tests/test-package-local.sh` 中移除对 `skills/doctor`、`skills/status` 打包存在性的要求。

- [ ] **Step 2: 运行失败测试，确认旧命令仍存在**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-doctor-contract.sh && bash tests/test-mvp-acceptance.sh && bash tests/test-package-local.sh`

Expected: FAIL。

- [ ] **Step 3: 删除 Skill 并更新 README / TESTING**

删除：

```text
skills/doctor/SKILL.md
skills/status/SKILL.md
```

同时在 `README.md`：

- 删除 `/sdd:doctor`、`/sdd:status` 的命令说明
- 把版本树示例改为 `research / prd / spec / plan / dr`
- 把 `decisions/` 的说明改为 `dr/`
- 把 `archive`、`review`、`code` 的边界更新为本次 spec 定义

在 `TESTING.md`：

- 删除 `doctor` / `status` 相关手工验证与自动验证步骤
- 增加 archived version 只读、`review` 自动识别类型和 `code` 依赖 `plan` 引用闭包的说明
- 把测试工程目录树与 Hook 示例改到 `research / prd / spec / plan / dr`

- [ ] **Step 4: 清理旧测试入口并移除命令残留**

`tests/test-doctor-contract.sh` 若只服务于已删除命令，应删除该测试文件并从文档/脚本集合中移除其调用；如果仍承担 README/结构合同检查，则重命名并改写为非 `doctor` 命令专属测试。

本任务只负责以下收口动作：

```bash
- `README.md`、`TESTING.md`、`tests/test-skill-contracts.sh`、`tests/test-mvp-acceptance.sh`、`tests/test-package-local.sh` 中不再保留 `/sdd:doctor` 与 `/sdd:status`
- 删除或改写 `tests/test-doctor-contract.sh`
- 从测试入口集合中移除对已删除命令的依赖
```

至少要确保：

```bash
bash tests/test-skill-contracts.sh
bash tests/test-mvp-acceptance.sh
bash tests/test-package-local.sh
```

不再依赖 `doctor/status`。

- [ ] **Step 5: 运行文档与测试合同**

Run: `bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh && bash tests/test-package-local.sh`

Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add README.md TESTING.md tests/test-skill-contracts.sh tests/test-mvp-acceptance.sh tests/test-package-local.sh
git rm skills/doctor/SKILL.md skills/status/SKILL.md tests/test-doctor-contract.sh
git commit -m "refactor: remove doctor and status commands"
```

---

### Task 10: 为高风险 Skill 建立 eval 入口并完成第一批完整 `/skill-creator` 评估

**Files:**
- Modify: `docs/superpowers/plans/2026-07-21-sdd-skills-claude-code-normalization-implementation.md` (this file)
- Create: `skills/review/evals/evals.json`
- Create: `skills/archive/evals/evals.json`
- Create: `skills/code/evals/evals.json`
- Create: `skills/dr/evals/evals.json`
- Create: `skills/spec/evals/evals.json`
- Create: `skills/plan/evals/evals.json`
- Create: `skills/review-workspace/iteration-1/` 下的 eval 结果产物
- Create: `skills/code-workspace/iteration-1/` 下的 eval 结果产物
- Create: `skills/dr-workspace/iteration-1/` 下的 eval 结果产物

**Interfaces:**
- Consumes: `/skill-creator` 的评估流程、已规范化后的高风险 Skill。
- Produces: 全部高风险 Skill 的第一轮 eval prompt 集，以及至少一批高风险 Skill（`review`、`code`、`dr`）的完整 eval loop 结果，用于满足 spec 的验收标准而不只是预留入口。

- [ ] **Step 1: 为高风险 Skill 写出最小 eval prompt 集**

分别创建以下 JSON：

`skills/review/evals/evals.json`

```json
{
  "skill_name": "review",
  "evals": [
    {
      "id": 1,
      "prompt": "请 review 当前版本的 spec 文档并自动识别类型与 mode。",
      "expected_output": "根据 doc-path 自动识别 spec，并执行 quality 后再决定 feasibility。",
      "files": []
    },
    {
      "id": 2,
      "prompt": "请对一个 archived version 下的 plan 运行 /sdd:review。",
      "expected_output": "明确失败，说明 archived version 的文档不能执行 review。",
      "files": []
    }
  ]
}
```

按同样结构分别为 `archive`、`code`、`dr`、`spec`、`plan` 写 2 条高风险 prompt。

- [ ] **Step 2: 运行 JSON 结构校验**

Run: `python -m json.tool skills/review/evals/evals.json >/dev/null && python -m json.tool skills/archive/evals/evals.json >/dev/null && python -m json.tool skills/code/evals/evals.json >/dev/null && python -m json.tool skills/dr/evals/evals.json >/dev/null && python -m json.tool skills/spec/evals/evals.json >/dev/null && python -m json.tool skills/plan/evals/evals.json >/dev/null`

Expected: no output, zero exit code.

- [ ] **Step 3: 至少对一批高风险 Skill 跑完整 `/skill-creator` eval loop**

选择以下第一批高风险 Skill：

- `review`
- `code`
- `dr`

对每个 Skill 至少完成：

```text
1. 用 `/skill-creator` 读取并确认当前 Skill 合同
2. 运行 with-skill / baseline（或旧版本）测试提示
3. 生成 benchmark / viewer 所需产物
4. 完成人工评审反馈回收
5. 根据结果做至少一轮迭代或确认无需迭代
```

产物至少包括各自 workspace 下的：

```text
iteration-1/
benchmark.json
benchmark.md
feedback.json（如有）
```

- [x] **Step 4: 在计划或后续 handoff 中记录评估完成范围与完成证据**

当前实现阶段已对 `review`、`code`、`dr` 完成第一批完整 `/skill-creator` eval loop；`archive`、`spec`、`plan` 已具备 eval 入口，可作为下一批继续扩展。

本轮完成证据如下：

```text
review
- skills/review/evals/evals.json
- skills/review-workspace/iteration-1/benchmark.json
- skills/review-workspace/iteration-1/benchmark.md
- skills/review-workspace/iteration-1/feedback.json
- skills/review-workspace/iteration-2/benchmark.json
- skills/review-workspace/iteration-2/benchmark.md
- skills/review-workspace/iteration-2/feedback.json
- iteration-2 benchmark: with_skill 100% / without_skill 0% / delta +1.00

code
- skills/code/evals/evals.json
- skills/code-workspace/iteration-1/benchmark.json
- skills/code-workspace/iteration-1/benchmark.md
- skills/code-workspace/iteration-1/feedback.json
- skills/code-workspace/iteration-2/benchmark.json
- skills/code-workspace/iteration-2/benchmark.md
- skills/code-workspace/iteration-2/feedback.json
- iteration-2 benchmark: with_skill 100% / without_skill 0% / delta +1.00

dr
- skills/dr/evals/evals.json
- skills/dr-workspace/iteration-1/benchmark.json
- skills/dr-workspace/iteration-1/benchmark.md
- skills/dr-workspace/iteration-1/feedback.json
- skills/dr-workspace/iteration-2/benchmark.json
- skills/dr-workspace/iteration-2/benchmark.md
- skills/dr-workspace/iteration-2/feedback.json
- skills/dr-workspace/iteration-3/benchmark.json
- skills/dr-workspace/iteration-3/benchmark.md
- skills/dr-workspace/iteration-3/feedback.json
- iteration-3 benchmark: with_skill 100% / without_skill 35% / delta +0.65

next batch eval-entry only
- skills/archive/evals/evals.json
- skills/spec/evals/evals.json
- skills/plan/evals/evals.json
```

完成判定按以下规则执行，且本轮 `review`、`code`、`dr` 已满足：

```text
- 若关键断言未通过，或 benchmark / 人工反馈显示结果明显不满足合同，必须至少再跑一轮迭代。
- 若关键断言通过，且人工反馈为空或明确接受当前输出，可将该 Skill 视为本轮 eval 完成。
```

- [x] **Step 5: Commit**

```bash
git add skills/review/evals/evals.json skills/archive/evals/evals.json skills/code/evals/evals.json skills/dr/evals/evals.json skills/spec/evals/evals.json skills/plan/evals/evals.json skills/review-workspace skills/code-workspace skills/dr-workspace docs/superpowers/plans/2026-07-21-sdd-skills-claude-code-normalization-implementation.md
git commit -m "test: run first eval loop for high-risk skills"
```

---

## Self-Review

### Spec coverage

- Skill 改造必须经过 `/skill-creator`：Task 2-10 和 Global Constraints 已覆盖。
- 所有保留 Skill 的正文统一中文：Task 2-9 在重写 `SKILL.md` 时统一覆盖，Task 1 覆盖模板正文与标准说明。
- 新 version-scoped 信息架构 `research / prd / spec / plan / dr`：Task 2、3、4、5、7、9 覆盖。
- `.sdd/templates/` 纳入 `dr` 并维持统一矩阵：Task 1 覆盖。
- `archive` 原位归档和 archived 只读：Task 7、8、9 覆盖。
- `review` 路径自动识别与 mode 自动决定、规则下沉：Task 6 覆盖。
- 共享 helper、Hook 门控、fixture 与验收测试同步迁移到新矩阵：Task 7 与 Task 9 覆盖。
- `code` 仅依赖 `plan` 及其正式引用闭包：Task 8 覆盖。
- 删除 `doctor / status`：Task 9 覆盖。
- 高风险 Skill 至少一批完成完整 eval loop：Task 10 覆盖。

### Placeholder scan

- 无 `TBD`、`TODO`、`implement later`、`similar to Task N`。
- 每个任务都给出精确文件路径。
- 每个代码或测试步骤都提供了具体断言、内容或命令。

### Type consistency

- 文档目录统一使用 `research / prd / spec / plan / dr`。
- 模板矩阵统一使用 `research/prd/dr -> quality`，`spec/plan -> quality + feasibility`。
- `code` 输入始终是 `plan`，未在后续任务中被改写成版本扫描式实现器。
- `dr` 文件命名始终保持 `NNN-<tag>-<slug>.md`，仅目录从 `decisions/` 改为 `dr/`。
- Hook、fixture、公共 helper 与 README / TESTING 的目录语义与 Skill 合同保持一致。
