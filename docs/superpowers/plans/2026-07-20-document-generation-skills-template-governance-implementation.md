# Document Generation Skills Template Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the unified template governance model for `research`, `prd`, `spec`, and `plan`, so runtime document generation and review consume only project `.sdd/templates/` assets initialized from plugin template packs.

**Architecture:** Keep document-generation behavior contracts in `skills/*/SKILL.md`, move runtime template content fully into `assets/template-packs/backend/`, and make `scripts/lib/sdd-template-assets.sh` the single shell helper that lists packs, selects the default pack, copies missing assets into `${CLAUDE_PROJECT_DIR}/.sdd/templates/`, and resolves runtime template paths. Extend the existing review contract instead of redesigning it: `research` joins the current `/sdd:review` system through `quality` only, while `spec` and `plan` keep `quality -> feasibility` unchanged.

**Tech Stack:** Claude Code plugin skills, Markdown templates and standards, Bash helper libraries, Bash contract tests, JSON schema-backed review output, ZIP/TAR packaging.

## Global Constraints

- 文档生成 skills 在运行时只读取项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`。
- plugin 内置模板只存在于 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/<pack>/`，只由 `/sdd:init` 使用。
- `/sdd:init` 支持模板风格选择合同；本次规格先落地 `backend` 模板，并为未来扩展 `frontend` 预留结构。
- 统一四个文档生成 skills 的中文风格、章节结构、路径变量写法和失败语义。
- 本次落地模板包与项目运行时模板的正文语言为中文，确保 skills 合同与模板内容语言一致。
- 删除 skill 目录中会形成双事实来源的历史模板残留。
- `research` 接入 `quality` reviewer，并把 `research/quality.standard.md` 定义为 reviewer 正式消费的标准文件。
- 同步更新 `doctor`、README、测试与模板资产检查逻辑，使系统围绕同一套事实来源工作。
- `research` 在 review 时只接入 `quality`，不接入 `feasibility`。
- 任何必要模板或标准文件缺失时，相关命令直接失败，并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
- 第一阶段不允许在运行时回退到 `${CLAUDE_PLUGIN_ROOT}/assets/template-packs/`。
- 本次版本中不实现 `frontend` 模板内容，只保留未来扩展所需的模板风格选择合同与目录结构预留。
- 不重写 reviewer JSON schema、review mode 定义或 reviewer admission contract。
- 不为 skill 目录保留第二套 references 模板作为兼容兜底。

---

### Task 1: Rebuild template-pack assets and shell helpers around `backend`

**Files:**
- Create: `assets/template-packs/backend/research/template.md`
- Create: `assets/template-packs/backend/research/quality.standard.md`
- Create: `assets/template-packs/backend/prd/template.md`
- Create: `assets/template-packs/backend/prd/quality.standard.md`
- Create: `assets/template-packs/backend/spec/template.md`
- Create: `assets/template-packs/backend/spec/quality.standard.md`
- Create: `assets/template-packs/backend/spec/feasibility.standard.md`
- Create: `assets/template-packs/backend/plan/template.md`
- Create: `assets/template-packs/backend/plan/quality.standard.md`
- Create: `assets/template-packs/backend/plan/feasibility.standard.md`
- Modify: `scripts/lib/sdd-template-assets.sh`
- Test: `tests/test-template-assets.sh`
- Test: `tests/test-template-runtime-contract.sh`

**Interfaces:**
- Consumes: `sdd_list_template_packs(plugin_root) -> stdout lines`, `sdd_default_template_pack() -> pack name`, `sdd_copy_template_pack(plugin_root, project_root, pack_name) -> 0|2`, `sdd_require_template_asset(project_root, doc_type, asset_name) -> absolute path`.
- Produces: a runtime asset matrix under `${CLAUDE_PROJECT_DIR}/.sdd/templates/{research,prd,spec,plan}/`, with `research` requiring `template.md` and `quality.standard.md`, `prd` requiring `template.md` and `quality.standard.md`, and `spec`/`plan` requiring all three standard/template files.

- [ ] **Step 1: Write the failing template-pack test updates**

Add these assertions to `tests/test-template-assets.sh` and `tests/test-template-runtime-contract.sh`:

```bash
assert_file_exists "assets/template-packs/backend/research/template.md"
assert_file_exists "assets/template-packs/backend/research/quality.standard.md"
assert_file_exists "assets/template-packs/backend/prd/template.md"
assert_file_exists "assets/template-packs/backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/plan/feasibility.standard.md"
assert_not_contains "scripts/lib/sdd-template-assets.sh" "default-backend"
assert_contains "scripts/lib/sdd-template-assets.sh" "printf 'backend\\n'"
```

Extend the temporary fixture in `tests/test-template-assets.sh` to create `research` assets and call:

```bash
mkdir -p "$tmp_plugin/assets/template-packs/backend/research"
printf '# Research\n' > "$tmp_plugin/assets/template-packs/backend/research/template.md"
printf '# research quality\n' > "$tmp_plugin/assets/template-packs/backend/research/quality.standard.md"
sdd_copy_template_pack "$tmp_plugin" "$tmp_project" "backend"
assert_file_exists "$tmp_project/.sdd/templates/research/template.md"
assert_file_exists "$tmp_project/.sdd/templates/research/quality.standard.md"
```

Run:

```bash
bash tests/test-template-assets.sh
bash tests/test-template-runtime-contract.sh
```

Expected: FAIL because `assets/template-packs/backend/` does not exist, `research` is not copied, and the helper still returns `default-backend`.

- [ ] **Step 2: Create the backend template-pack files in Chinese**

Create these files with Chinese headings and no English narrative outside required identifiers:

```text
assets/template-packs/backend/research/template.md
assets/template-packs/backend/research/quality.standard.md
assets/template-packs/backend/prd/template.md
assets/template-packs/backend/prd/quality.standard.md
assets/template-packs/backend/spec/template.md
assets/template-packs/backend/spec/quality.standard.md
assets/template-packs/backend/spec/feasibility.standard.md
assets/template-packs/backend/plan/template.md
assets/template-packs/backend/plan/quality.standard.md
assets/template-packs/backend/plan/feasibility.standard.md
```

Use this minimum `research/template.md` content so later tests can assert the canonical sections:

```md
# Research: <topic>

- 日期：YYYY-MM-DD
- 主题：<topic>
- 目的：<why this matters>
- 适用范围：<which PRD/spec/DR this may inform>

## 1. 背景
## 2. 研究问题
## 3. 信息来源
## 4. 关键发现
## 5. 方案比较 / 取舍分析
## 6. 结论与建议
## 7. 对后续文档的影响
```

Use this minimum `research/quality.standard.md` content so the reviewer contract has concrete quality dimensions:

```md
# Research 质量标准

## 最小结构要求
- 必须包含背景、研究问题、信息来源、关键发现、结论与建议、对后续文档的影响。

## 检查维度
- 完整性
- 证据性
- 清晰性
- 可复用性
- 非越界性

## 自动修复边界
- 允许低风险的结构补齐、标题规范化、措辞澄清。
- 不允许把 research 改写为 PRD、spec、plan 或 DR。
```

For `prd/spec/plan`, preserve the current runtime contract semantics but move the source-of-truth content into `assets/template-packs/backend/...`.

- [ ] **Step 3: Update the shell helper for `backend` and `research`**

Replace `scripts/lib/sdd-template-assets.sh` with this implementation shape:

```bash
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
  mkdir -p "$target_root/research" "$target_root/prd" "$target_root/spec" "$target_root/plan"

  cp -R -n "$pack_root/research/." "$target_root/research/" || true
  cp -R -n "$pack_root/prd/." "$target_root/prd/" || true
  cp -R -n "$pack_root/spec/." "$target_root/spec/" || true
  cp -R -n "$pack_root/plan/." "$target_root/plan/" || true
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

This keeps the existing helper API but changes the default pack name, extends copying to `research`, and preserves the “fill missing files without overwriting project customizations” contract.

- [ ] **Step 4: Run focused template asset tests**

Run:

```bash
bash tests/test-template-assets.sh
bash tests/test-template-runtime-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the template-pack and helper changes**

```bash
git add assets/template-packs/backend scripts/lib/sdd-template-assets.sh tests/test-template-assets.sh tests/test-template-runtime-contract.sh
git commit -m "feat: add backend template pack runtime assets"
```

---

### Task 2: Move document-generation skills onto runtime `.sdd/templates/` only

**Files:**
- Modify: `skills/research/SKILL.md`
- Modify: `skills/prd/SKILL.md`
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Delete: `skills/research/references/research.md.tmpl`
- Delete: `skills/plan/references/plan.md.tmpl`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/template.md`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`.
- Produces: Chinese `SKILL.md` contracts for `research`, `prd`, `spec`, and `plan` that reference only project runtime templates and fail when required assets are missing.

- [ ] **Step 1: Write the failing contract assertions for runtime-only skills**

Update `tests/test-skill-contracts.sh` with these assertions:

```bash
assert_not_contains "skills/research/SKILL.md" "skills/research/references/research.md.tmpl"
assert_file_not_exists "skills/research/references/research.md.tmpl"
assert_file_not_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`'
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`'
assert_contains "skills/research/SKILL.md" '自动触发 `quality` reviewer'
assert_contains "skills/research/SKILL.md" '不接入 `feasibility`'
assert_contains "skills/init/SKILL.md" '将所选模板包中的 `research / PRD / Spec / Plan` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`'
```

Replace the old assertions:

```bash
assert_file_exists "skills/research/references/research.md.tmpl"
assert_file_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/research/SKILL.md" "Write using `skills/research/references/research.md.tmpl`."
assert_contains "skills/research/references/research.md.tmpl" "# Research：<topic>"
assert_contains "skills/plan/references/plan.md.tmpl" "## 文档引用"
```

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL because `research` still points at `skills/research/references/research.md.tmpl`, `plan` still keeps `skills/plan/references/plan.md.tmpl`, and `init` still says only `PRD / Spec / Plan` are expanded.

- [ ] **Step 2: Rewrite `skills/research/SKILL.md` to the unified Chinese contract**

Replace the current body with this structure:

```md
# /sdd:research

在 `docs/requirements/` 下创建或更新项目级 research 文档。该文档不属于任何 version，也不进入 version lifecycle。

## Preconditions

1. 读取 `docs/CONSTITUTION.md`；若缺失，停止并提示用户执行 `/sdd:init`。
2. 要求 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 存在。
3. 要求 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md` 与 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md` 存在且可读；任一缺失时直接失败，并提示重新执行 `/sdd:init`。
4. `docs/requirements/` 缺失时可创建该目录；不扫描 `docs/versions/v*/state.json`，不要求 active version。

## Dialogue

1. 确认 research 主题。
2. 确认研究目的、约束与预期服务对象。
3. 确认可用信息来源或待补充资料。
4. 确认这份 research 未来可能影响哪些 PRD、spec 或 DR。

## Template Assets

- 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 下的模板与标准。
- 生成时使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`。
- 生成与复审时使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`。
- 不降级到 Plugin 内置资产；Plugin 模板包只由 `/sdd:init` 使用。

## Output

- 输出路径：`docs/requirements/<topic-slug>-<yyyy-mm>.md`
- research 文档不写 `- 状态：` 行，不写 version lifecycle 字段。
- research 文档自身不强制要求 `## 文档引用` 表。

## Review Flow

- 写入完成并通过最小结构校验后，自动触发 `quality` reviewer。
- 手工修改后可通过 `/sdd:review` 重新执行 `quality` 复审。
- `research` 不接入 `feasibility`。

## Boundaries

- 不创建 active version。
- 不读取或修改 `state.json`。
- 不自动修改 `PRD / spec / plan / DR`。
```

- [ ] **Step 3: Update `init/prd/spec/plan` wording and delete legacy templates**

Make these targeted edits:

1. In `skills/init/SKILL.md`, replace:

```md
将所选模板包中的 `PRD / Spec / Plan` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`
```

with:

```md
将所选模板包中的 `research / PRD / Spec / Plan` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`
```

2. In `skills/prd/SKILL.md`, `skills/spec/SKILL.md`, and `skills/plan/SKILL.md`, normalize the `Template Assets` wording so each file explicitly says:

```md
- 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/` 下的模板与标准。
- 缺失时直接失败，并提示重新执行 `/sdd:init`。
- 不降级到 Plugin 内置资产。
```

3. Delete:

```text
skills/research/references/research.md.tmpl
skills/plan/references/plan.md.tmpl
```

- [ ] **Step 4: Run the skill contract test**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the skill-contract unification**

```bash
git add skills/research/SKILL.md skills/prd/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md skills/init/SKILL.md tests/test-skill-contracts.sh
git rm skills/research/references/research.md.tmpl skills/plan/references/plan.md.tmpl
git commit -m "fix: unify document skills around runtime templates"
```

---

### Task 3: Extend `/sdd:review` and doctor contracts for `research -> quality`

**Files:**
- Modify: `skills/review/SKILL.md`
- Modify: `skills/doctor/SKILL.md`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-doctor-contract.sh`

**Interfaces:**
- Consumes: `agents/doc-reviewer.md`, `skills/review/references/reviewer-result.schema.json`, `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`.
- Produces: review orchestration that accepts `document_type: research` in `quality` mode only, plus doctor checks that validate `research` assets in both plugin and project template trees.

- [ ] **Step 1: Write the failing review/doctor assertions**

Add these assertions:

```bash
assert_contains "skills/review/SKILL.md" '"document_type": "research|prd|spec|plan"'
assert_contains "skills/review/SKILL.md" '`research -> quality`'
assert_contains "skills/review/SKILL.md" 'reviewer 在处理 `research` 时，不得假设文档必须具备 `PRD / spec / plan` 的核心章节或统一 `## 文档引用` 表'
assert_contains "skills/doctor/SKILL.md" "assets/template-packs/backend/research/template.md"
assert_contains "skills/doctor/SKILL.md" "assets/template-packs/backend/research/quality.standard.md"
assert_contains "skills/doctor/SKILL.md" 'research/template.md'
assert_contains "skills/doctor/SKILL.md" 'research/quality.standard.md'
```

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-doctor-contract.sh
```

Expected: FAIL because `review` only enumerates `prd|spec|plan`, and `doctor` still checks `default-backend` plus only `prd/spec/plan` runtime assets.

- [ ] **Step 2: Update `skills/review/SKILL.md` for research-aware review**

Make these precise edits:

1. Change the JSON contract block field to:

```json
"document_type": "research|prd|spec|plan"
```

2. Change the “Structured input” section line:

```md
- 文档类型：`document_type`，支持 `research`、`prd`、`spec`、`plan`
```

3. Change the mode matrix block to:

```md
- `research -> quality`
- `prd -> quality`
- `spec -> quality + feasibility`
- `plan -> quality + feasibility`
```

4. In “Review admission check”, replace the hard requirement:

```md
文档包含该类型模板定义的核心章节、必要元信息和 `## 文档引用` 表
```

with:

```md
文档包含该类型模板定义的核心章节与必要元信息；对于 `prd`、`spec`、`plan` 还必须具备 `## 文档引用` 表，而 `research` 不强制要求该表。
```

5. Add a sentence under admission or modes:

```md
reviewer 在处理 `research` 时，必须依据 `research/template.md` 与 `research/quality.standard.md` 执行最小结构校验，不得复用 `PRD / spec / plan` 的固定章节假设。
```

- [ ] **Step 3: Update `skills/doctor/SKILL.md` for backend/research assets**

Replace the plugin asset checklist fragment:

```text
assets/template-packs/default-backend/prd/template.md
assets/template-packs/default-backend/prd/quality.standard.md
assets/template-packs/default-backend/spec/template.md
assets/template-packs/default-backend/spec/quality.standard.md
assets/template-packs/default-backend/spec/feasibility.standard.md
assets/template-packs/default-backend/plan/template.md
assets/template-packs/default-backend/plan/quality.standard.md
assets/template-packs/default-backend/plan/feasibility.standard.md
```

with:

```text
assets/template-packs/backend/research/template.md
assets/template-packs/backend/research/quality.standard.md
assets/template-packs/backend/prd/template.md
assets/template-packs/backend/prd/quality.standard.md
assets/template-packs/backend/spec/template.md
assets/template-packs/backend/spec/quality.standard.md
assets/template-packs/backend/spec/feasibility.standard.md
assets/template-packs/backend/plan/template.md
assets/template-packs/backend/plan/quality.standard.md
assets/template-packs/backend/plan/feasibility.standard.md
```

Replace the runtime template asset checks with:

```md
- 检查 `research/template.md`、`research/quality.standard.md` 是否存在。
- 检查 `prd/template.md`、`prd/quality.standard.md` 是否存在。
- 检查 `spec/template.md`、`spec/quality.standard.md`、`spec/feasibility.standard.md` 是否存在。
- 检查 `plan/template.md`、`plan/quality.standard.md`、`plan/feasibility.standard.md` 是否存在。
```

- [ ] **Step 4: Run review and doctor contract tests**

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-doctor-contract.sh
bash tests/test-review-output-contract.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the review and doctor alignment**

```bash
git add skills/review/SKILL.md skills/doctor/SKILL.md tests/test-skill-contracts.sh tests/test-doctor-contract.sh
git commit -m "fix: extend review and doctor contracts for research"
```

---

### Task 4: Align README, TESTING, and package contract with the new template model

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `tests/test-doctor-contract.sh`
- Modify: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: plugin installation docs, `/sdd:init` flow, `.sdd/templates/` runtime tree, template-pack naming, `agents/doc-reviewer.md`.
- Produces: docs and contract tests that consistently describe `backend` as the only implemented pack, `research` as part of `.sdd/templates/`, and `research` review through `quality` only.

- [ ] **Step 1: Write the failing doc assertions**

Add these assertions to `tests/test-skill-contracts.sh` and `tests/test-doctor-contract.sh`:

```bash
assert_contains "README.md" '.sdd/templates/research/'
assert_contains "README.md" 'research / prd / spec / plan'
assert_contains "README.md" 'backend'
assert_not_contains "README.md" 'default-backend'
assert_contains "TESTING.md" '.sdd/templates/research/'
assert_contains "TESTING.md" '`/sdd:research demo`'
assert_contains "TESTING.md" 'research 使用 `quality` reviewer'
```

Run:

```bash
bash tests/test-skill-contracts.sh
bash tests/test-doctor-contract.sh
```

Expected: FAIL because README and TESTING still document only `prd/spec/plan` template directories and still mention `default-backend`.

- [ ] **Step 2: Update README runtime and quick-start sections**

Make these exact content changes in `README.md`:

1. In the `/sdd:init` expected results list, add:

```md
- `.sdd/templates/research/`
```

2. Replace:

```md
- `/sdd:init` 会提示模板包选择；未显式切换时默认使用 `default-backend`。
```

with:

```md
- `/sdd:init` 会提示模板包选择；未显式切换时默认使用 `backend`。
```

3. Replace the runtime tree block with:

```text
.sdd/
└── templates/
    ├── research/
    │   ├── template.md
    │   └── quality.standard.md
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

4. Replace:

```md
`/sdd:init` 会将所选模板包展开到 `.sdd/templates/`，这是 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和 `/sdd:review` 的运行时唯一模板来源。
```

with:

```md
`/sdd:init` 会将所选模板包展开到 `.sdd/templates/`，这是 `/sdd:research`、`/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和 `/sdd:review` 的运行时唯一模板来源。
```

5. Add a sentence after the reviewer paragraph:

```md
其中 `research` 只接入 `quality` reviewer，不接入 `feasibility` reviewer。
```

- [ ] **Step 3: Update TESTING manual validation coverage**

Make these edits in `TESTING.md`:

1. In “模板包与 reviewer 手工验证”, replace step 2 with:

```md
2. 确认项目生成 `.sdd/templates/research/`、`.sdd/templates/prd/`、`.sdd/templates/spec/`、`.sdd/templates/plan/`。
```

2. Add a new step after the current spec-failure check:

```md
4. 手工删除 `.sdd/templates/research/quality.standard.md` 后执行 `/sdd:research demo`，期望命令明确失败，并提示缺少项目模板资产。
```

3. Renumber the remaining steps and add this check in the reviewer section:

```md
- `research` 写入完成后会自动触发 `quality` reviewer，不触发 `feasibility` reviewer。
```

4. In the later “重点确认” list, add:

```md
- `/sdd:init` 会创建 `.sdd/templates/research/`、`prd/`、`spec/`、`plan/`。
- `/sdd:research demo` 在 `research/quality.standard.md` 缺失时会明确失败。
```

- [ ] **Step 4: Run doc and package contract tests**

Run:

```bash
bash tests/test-doctor-contract.sh
bash tests/test-skill-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit the documentation alignment**

```bash
git add README.md TESTING.md tests/test-doctor-contract.sh tests/test-skill-contracts.sh
git commit -m "docs: align template governance runtime docs"
```

---

### Task 5: Add focused runtime governance tests for `research` and final matrix verification

**Files:**
- Modify: `tests/test-template-assets.sh`
- Modify: `tests/test-template-runtime-contract.sh`
- Modify: `tests/test-skill-contracts.sh`
- Modify: `tests/test-doctor-contract.sh`
- Create: `tests/test-template-governance-matrix.sh`

**Interfaces:**
- Consumes: `assets/template-packs/backend/`, `scripts/lib/sdd-template-assets.sh`, `skills/*/SKILL.md`, `skills/review/SKILL.md`, `skills/doctor/SKILL.md`.
- Produces: one focused matrix test that proves every implemented template pack contains the full required asset matrix and that no document-generation skill still depends on legacy `skills/*/references/*.tmpl` runtime sources.

- [ ] **Step 1: Write the failing matrix test**

Create `tests/test-template-governance-matrix.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "assets/template-packs/backend/research/template.md"
assert_file_exists "assets/template-packs/backend/research/quality.standard.md"
assert_file_exists "assets/template-packs/backend/prd/template.md"
assert_file_exists "assets/template-packs/backend/prd/quality.standard.md"
assert_file_exists "assets/template-packs/backend/spec/template.md"
assert_file_exists "assets/template-packs/backend/spec/quality.standard.md"
assert_file_exists "assets/template-packs/backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/plan/template.md"
assert_file_exists "assets/template-packs/backend/plan/quality.standard.md"
assert_file_exists "assets/template-packs/backend/plan/feasibility.standard.md"

assert_file_not_exists "skills/research/references/research.md.tmpl"
assert_file_not_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/research/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/research/`'
assert_contains "skills/prd/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/`'
assert_contains "skills/spec/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/`'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/`'
assert_contains "skills/review/SKILL.md" '`research -> quality`'
assert_not_contains "skills/research/SKILL.md" 'skills/research/references/research.md.tmpl'
assert_not_contains "skills/plan/SKILL.md" 'skills/plan/references/plan.md.tmpl'

printf 'PASS: template governance matrix\n'
```

Run:

```bash
bash tests/test-template-governance-matrix.sh
```

Expected: FAIL until all previous tasks are complete and the new test file is executable.

- [ ] **Step 2: Make the matrix test executable and wire it into manual verification docs**

Run:

```bash
chmod +x tests/test-template-governance-matrix.sh
```

Then add this command to the auto-validation block in `TESTING.md`:

```bash
bash tests/test-template-governance-matrix.sh
```

Insert it between `bash tests/test-template-runtime-contract.sh` and `bash tests/test-skill-contracts.sh` if those commands are listed individually, or append it to the combined `&&` chain if the file uses a single chained command.

- [ ] **Step 3: Run the final focused governance suite**

Run:

```bash
bash tests/test-template-assets.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-template-governance-matrix.sh
bash tests/test-skill-contracts.sh
bash tests/test-doctor-contract.sh
```

Expected: PASS with these lines present:

```text
PASS: template assets
PASS: template runtime contract
PASS: template governance matrix
PASS: skill contracts
PASS: skeleton contract
```

- [ ] **Step 4: Run the broader regression suite**

Run:

```bash
bash tests/test-common-library.sh
bash tests/test-pre-tool-use.sh
bash tests/test-reference-validation.sh
bash tests/test-review-output-contract.sh
bash tests/test-document-reviewer.sh
bash tests/test-mvp-acceptance.sh
```

Expected: PASS for every script, proving the governance change did not break existing SDD workflow contracts.

- [ ] **Step 5: Commit the governance matrix coverage**

```bash
git add tests/test-template-assets.sh tests/test-template-runtime-contract.sh tests/test-template-governance-matrix.sh tests/test-skill-contracts.sh tests/test-doctor-contract.sh TESTING.md
git commit -m "test: cover template governance matrix"
```

---

## Self-Review

### Spec coverage

- Template-pack runtime source of truth: covered by Task 1 and Task 5.
- `research / prd / spec / plan` unified runtime template reading: covered by Task 2.
- `/sdd:init` template-pack selection and copy semantics: covered by Task 1 and Task 2.
- Chinese skill/template content and removal of dual sources: covered by Task 1 and Task 2.
- `research -> quality` reviewer integration without `feasibility`: covered by Task 2, Task 3, and Task 4.
- `doctor`/README/TESTING/package alignment: covered by Task 3 and Task 4.
- Automated contract coverage and consistency matrix: covered by Task 5.

### Placeholder scan

- No `TBD`, `TODO`, `implement later`, `add appropriate error handling`, or `similar to Task N` placeholders remain.
- Every file path referenced in tasks is concrete.
- Every code-edit step includes explicit replacement content or full file content.

### Type consistency

- Template helper interface remains `sdd_list_template_packs`, `sdd_default_template_pack`, `sdd_copy_template_pack`, `sdd_require_template_asset` across all tasks.
- Runtime document types are consistently `research`, `prd`, `spec`, `plan`.
- Review mode mapping is consistently `research -> quality`, `prd -> quality`, `spec -> quality + feasibility`, `plan -> quality + feasibility`.
- Implemented pack name is consistently `backend`; `frontend` is never treated as implemented content in any task.
