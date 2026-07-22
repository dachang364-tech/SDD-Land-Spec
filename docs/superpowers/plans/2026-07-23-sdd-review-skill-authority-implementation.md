# SDD Review Skill Authority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 `PostToolUse Hook` 与 `sdd-review-runner.sh`，将受管文档的 review 触发与执行权威统一收敛到 `/sdd:review` Skill，并让文档 Skill 在 create 流程中显式调用 `/sdd:review <doc-path>`。

**Architecture:** 先用测试锁定新合同：`/sdd:review` 成为唯一 review 编排入口，`research / prd / dr / spec / plan` 在 create 后显式调用它，update 不自动 review。随后把 Hook 与 runner 的职责迁入 `skills/review/SKILL.md`，再删除 Hook/runner 运行时路径，最后同步 README、TESTING 与验收测试，确保用户入口、Skill 合同与运行时一致。

**Tech Stack:** Claude Code Skills, shell contract tests, Bash hook scripts, JSON schema references, Markdown spec/plan docs.

## Global Constraints

- 任何 `skills/*/SKILL.md` 的新增、重写、扩展、规范化改造，都必须遵守项目级 `/skill-creator` 约束。
- 删除 `PostToolUse Hook` 与 `scripts/lib/sdd-review-runner.sh`，不保留 review 双权威结构。
- `/sdd:review` 必须成为唯一 review 编排入口，并在 Skill 中直接调用 `doc-reviewer` subagent。
- `research / prd / dr / spec / plan` 必须区分 create 与 update：create 显式调用 `/sdd:review <doc-path>`，update 不自动 review。
- `spec` 与 `plan` 在 create review 未得到有效结果前必须保持 `draft`，不得绕过 gate。
- review 仍只读取项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 下对应类型的模板与标准；缺失时直接失败，不降级到 Plugin 内置资产。
- 所有面向用户的 Skill、README、TESTING、计划说明统一使用中文。
- 测试合同必须从“Hook/runner 存在”切换为“Skill 驱动 review”。
- 不修改 `doc-reviewer` 的 schema、评分模型或模板资产内容。

---

### Task 1: 先用测试锁定删除 Hook 与 runner 后的新合同

**Files:**
- Modify: `tests/test-skill-contracts.sh`
- Modify: `tests/test-mvp-acceptance.sh`
- Modify: `tests/test-template-runtime-contract.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-mvp-acceptance.sh`
- Test: `tests/test-template-runtime-contract.sh`

**Interfaces:**
- Consumes: 现有 Skill/README/运行时合同文本。
- Produces: 一组失败测试，要求 `PostToolUse` 和 `sdd-review-runner.sh` 不再存在，并要求 `/sdd:review` 与文档 Skill 使用显式 create/update review 语义。

- [ ] **Step 1: 在 `tests/test-skill-contracts.sh` 写出新的 review Skill 合同断言**

```bash
assert_contains "skills/review/SKILL.md" '/sdd:review 是唯一 review 编排入口'
assert_contains "skills/review/SKILL.md" '由当前 Skill 负责识别 `document_type` 与 mode 链路'
assert_contains "skills/review/SKILL.md" '当前 Skill 直接调用 `doc-reviewer` subagent'
assert_contains "skills/review/SKILL.md" 'research / prd / dr -> quality'
assert_contains "skills/review/SKILL.md" 'spec / plan -> quality -> feasibility'
assert_contains "skills/review/SKILL.md" '对每个 mode 的结构化结果执行 schema 校验'
assert_contains "skills/review/SKILL.md" '`document_path`、`document_type`、`executed_modes`、`blocked`、`requires_user_confirmation`、`remaining_items`'
assert_contains "skills/review/SKILL.md" '当 reviewer 返回 `requires_user_confirmation` 时，由当前 Skill 承接用户确认'
assert_contains "skills/review/SKILL.md" '写回后重新执行 `/sdd:review <doc-path>`'
assert_not_contains "skills/review/SKILL.md" '共享 review runner'
assert_not_contains "skills/review/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_not_contains "skills/review/SKILL.md" 'PostToolUse Hook'
```

- [ ] **Step 2: 在 `tests/test-skill-contracts.sh` 写出文档 Skill 的 create/update 新合同断言**

```bash
for skill in research prd spec plan; do
  assert_contains "skills/$skill/SKILL.md" '目标文件不存在：视为 create；存在：视为 update'
  assert_contains "skills/$skill/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
  assert_contains "skills/$skill/SKILL.md" 'update：修改已有文档时，不自动执行 review'
  assert_contains "skills/$skill/SKILL.md" '文档已更新；如需复审，请执行 `/sdd:review <doc-path>`'
  assert_not_contains "skills/$skill/SKILL.md" 'PostToolUse Hook'
  assert_not_contains "skills/$skill/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
  assert_not_contains "skills/$skill/SKILL.md" '共享 review runner'
done

assert_contains "skills/dr/SKILL.md" 'create mode 只创建新 DR 文件，因此本次写入结果恒为 create'
assert_contains "skills/dr/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/dr/SKILL.md" '这属于 update：修改已有 DR 时，不自动执行 review'
assert_not_contains "skills/dr/SKILL.md" 'PostToolUse Hook'
assert_not_contains "skills/dr/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
```

- [ ] **Step 3: 在 `tests/test-mvp-acceptance.sh` 与 `tests/test-template-runtime-contract.sh` 写出删除 Hook/runner 的断言**

```bash
assert_not_contains "hooks/hooks.json" '"PostToolUse"'
assert_file_not_exists "scripts/hooks/post-tool-use.sh"
assert_file_not_exists "scripts/lib/sdd-review-runner.sh"
assert_contains "skills/review/SKILL.md" '/sdd:review'
assert_contains "skills/review/SKILL.md" 'doc-reviewer'
assert_contains "skills/spec/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/plan/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
```

- [ ] **Step 4: 在 `tests/test-mvp-acceptance.sh` 写出“显式 review 新路径仍可工作”的回归断言**

```bash
assert_contains "skills/review/SKILL.md" '当前 Skill 直接调用 `doc-reviewer` subagent'
assert_contains "skills/review/SKILL.md" '当 reviewer 返回 `requires_user_confirmation` 时，由当前 Skill 承接用户确认'
assert_contains "skills/spec/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/plan/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "TESTING.md" '生成新 `spec` 或 `plan`，确认流程显式进入 `/sdd:review <doc-path>`'
assert_contains "TESTING.md" '更新已有 `spec` 或 `plan`，确认不会自动 review'
```

- [ ] **Step 5: 运行测试，验证当前实现按预期失败**

Run:
```bash
bash tests/test-skill-contracts.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-mvp-acceptance.sh
```

Expected: FAIL，失败点应集中在以下事实仍然存在：
- Skill 文本仍提到 `PostToolUse Hook`
- 运行时仍注册 `PostToolUse`
- `scripts/lib/sdd-review-runner.sh` 仍存在
- `/sdd:review` 尚未承接 schema 校验、聚合字段与确认后重试语义

- [ ] **Step 6: Commit**

```bash
git add tests/test-skill-contracts.sh tests/test-template-runtime-contract.sh tests/test-mvp-acceptance.sh
git commit -m "test: redefine review authority contracts"
```

---

### Task 2: 重写 `/sdd:review` Skill，使其接管 runner 编排职责

**Files:**
- Modify: `skills/review/SKILL.md`
- Read: `skills/review/references/reviewer-result.schema.json`
- Read: `agents/doc-reviewer.md`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: `doc-reviewer` subagent、`reviewer-result.schema.json` 中已存在的结果结构、项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 资产约束。
- Produces: 新的 `/sdd:review` 合同，明确由该 Skill 自己负责 `document_type` 识别、mode 链路、schema 校验、用户回执和确认项承接。

- [ ] **Step 1: 先读 schema 与 agent 合同，避免重写 Skill 时引入虚构字段**

Run:
```bash
sed -n '1,220p' skills/review/references/reviewer-result.schema.json
sed -n '1,260p' agents/doc-reviewer.md
```

Expected: 读到 reviewer 当前真实字段与 `doc-reviewer` 的调用边界，后续 Skill 文本只复用现有字段名。

- [ ] **Step 2: 将 `skills/review/SKILL.md` 重写为唯一 review 编排入口**

```md
`/sdd:review` 是唯一 review 编排入口。

当前 Skill 必须：
- 校验 `<doc-path>` 是否属于受管文档。
- 识别 `document_type`。
- 决定 review mode 或 mode 链路：`research / prd / dr -> quality`；`spec / plan -> quality -> feasibility`。
- 直接调用 `doc-reviewer` subagent，而不是委托 `scripts/lib/sdd-review-runner.sh`。
- 对每个 mode 的结构化结果执行 schema 校验。
- 聚合并输出一份用户回执，包含 `document_path`、`document_type`、`executed_modes`、`blocked`、`requires_user_confirmation`、`remaining_items`。
- 当 reviewer 返回 `requires_user_confirmation` 时，由当前 Skill 承接用户确认；写回后重新执行 `/sdd:review <doc-path>`。
```

- [ ] **Step 3: 删除旧的 Hook/runner 叙述，保留唯一权威说法**

```md
禁止保留以下旧语义：
- `共享 review runner`
- `scripts/lib/sdd-review-runner.sh`
- `PostToolUse Hook`
- “手工入口 + runner 包装层”
```

- [ ] **Step 4: 运行 Skill 合同测试，确认 `/sdd:review` 文本通过新断言**

Run:
```bash
bash tests/test-skill-contracts.sh
```

Expected: 仍可能 FAIL，但 `skills/review/SKILL.md` 相关断言应转为 PASS；剩余失败应来自其他文档 Skill 与运行时文件尚未收敛。

- [ ] **Step 5: 在 `tests/test-mvp-acceptance.sh` 补充 `/sdd:review` 新路径的聚合回执断言**

```bash
assert_contains "skills/review/SKILL.md" '`document_path`、`document_type`、`executed_modes`、`blocked`、`requires_user_confirmation`、`remaining_items`'
assert_contains "skills/review/SKILL.md" '写回后重新执行 `/sdd:review <doc-path>`'
```

- [ ] **Step 6: Commit**

```bash
git add skills/review/SKILL.md tests/test-mvp-acceptance.sh
git commit -m "refactor: make review skill authoritative"
```

---

### Task 3: 重写文档 Skills 的 create/update review 合同

**Files:**
- Modify: `skills/research/SKILL.md`
- Modify: `skills/prd/SKILL.md`
- Modify: `skills/dr/SKILL.md`
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: Task 2 产出的 `/sdd:review <doc-path>` 唯一入口合同。
- Produces: 各文档 Skill 的统一 create/update 语义，以及 `spec` / `plan` 的 gate 说明。

- [ ] **Step 1: 把 `research / prd / spec / plan` 的 Review 段落改为统一模板**

```md
- 写入前显式判断目标文件：目标文件不存在：视为 create；存在：视为 update。
- create：成功写入后必须显式调用 `/sdd:review <doc-path>`；拿不到有效 review 结果时，当前流程不得宣称完成。
- update：修改已有文档时，不自动执行 review。
- 回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
- 当前 Skill 不再依赖 `PostToolUse Hook` 或 `scripts/lib/sdd-review-runner.sh`。
```

- [ ] **Step 2: 为 `dr` 保留 create-only 与 accept/dismiss update 的差异化表述**

```md
- create mode 只创建新 DR 文件，因此本次写入结果恒为 create。
- create：成功写入后必须显式调用 `/sdd:review <doc-path>`；`dr` 的 review mode 为 `quality`。
- accept / dismiss 属于 update：修改已有 DR 时，不自动执行 review。
```

- [ ] **Step 3: 保留 `spec` / `plan` 的状态 gate 与 mode 链路**

```md
- `spec`：create review mode 为 `quality -> feasibility`；新建文档拿不到有效 review 结果时保持 `draft`，不得进入普通审批。
- `plan`：create review mode 为 `quality -> feasibility`；新建文档拿不到有效 review 结果时保持 `draft`，不得推进为 `planned`。
```

- [ ] **Step 4: 运行 Skill 合同测试，确认五个文档 Skill 通过新断言**

Run:
```bash
bash tests/test-skill-contracts.sh
```

Expected: 仍可能 FAIL，但失败不应再来自文档 Skill 中的 `PostToolUse Hook` / runner 旧文本。

- [ ] **Step 5: Commit**

```bash
git add skills/research/SKILL.md skills/prd/SKILL.md skills/dr/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md
git commit -m "refactor: make document skills call review explicitly"
```

---

### Task 4: 删除 Hook 与 runner 运行时路径，并补上新路径回归测试

**Files:**
- Modify: `hooks/hooks.json`
- Delete: `scripts/hooks/post-tool-use.sh`
- Delete: `scripts/lib/sdd-review-runner.sh`
- Delete or Modify: `tests/test-post-tool-use.sh`
- Modify: `tests/test-mvp-acceptance.sh`
- Modify: `TESTING.md`
- Test: `tests/test-template-runtime-contract.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: Task 1 的新运行时合同，以及 Task 2-3 中 `/sdd:review` 与文档 Skill 的显式调用语义。
- Produces: 不再注册 `PostToolUse` 的运行时配置，以及一组确认“旧路径已删除、新路径仍可工作”的回归测试。

- [ ] **Step 1: 从 `hooks/hooks.json` 删除整个 `PostToolUse` 注册块**

```json
{
  "hooks": {
    "SessionStart": [ ... ],
    "PreToolUse": [ ... ]
  }
}
```

- [ ] **Step 2: 删除 `scripts/hooks/post-tool-use.sh` 与 `scripts/lib/sdd-review-runner.sh`**

Run:
```bash
rm scripts/hooks/post-tool-use.sh scripts/lib/sdd-review-runner.sh
```

Expected: 两个文件从工作树移除，不再作为运行时路径存在。

- [ ] **Step 3: 删除或改写 `tests/test-post-tool-use.sh`，使其不再验证已移除路径**

```bash
rm tests/test-post-tool-use.sh
```

如果测试矩阵需要保留同名文件，则改成最小断言：

```bash
assert_not_contains "hooks/hooks.json" '"PostToolUse"'
assert_file_not_exists "scripts/hooks/post-tool-use.sh"
```

- [ ] **Step 4: 在 `tests/test-mvp-acceptance.sh` 与 `TESTING.md` 补上“旧路径已删、新路径仍可工作”的回归验证**

```bash
assert_contains "skills/review/SKILL.md" '当前 Skill 直接调用 `doc-reviewer` subagent'
assert_contains "skills/review/SKILL.md" '写回后重新执行 `/sdd:review <doc-path>`'
assert_contains "TESTING.md" '生成新 `spec` 或 `plan`，确认流程显式进入 `/sdd:review <doc-path>`'
assert_contains "TESTING.md" '更新已有 `spec` 或 `plan`，确认不会自动 review'
```

并将 `TESTING.md` 的手工步骤改为：

```md
6. 生成新 `research`、`prd`、`dr`、`spec`、`plan` 文档后，确认所属 Skill 显式进入 `/sdd:review <doc-path>`。
7. 确认 `research`、`prd`、`dr` create 只触发 `quality`；`spec` 与 `plan` create 按顺序触发 `quality -> feasibility`。
8. 更新已有文档时，确认不会自动 review，只输出手工复审提示。
```

- [ ] **Step 5: 运行运行时合同测试，验证 Hook/runner 路径已移除且显式 review 路径仍被合同覆盖**

Run:
```bash
bash tests/test-template-runtime-contract.sh
bash tests/test-mvp-acceptance.sh
```

Expected: 与 `PostToolUse`、`post-tool-use.sh`、`sdd-review-runner.sh` 存在性相关的断言全部 PASS，且 `/sdd:review` 与 create/update 新路径相关断言也 PASS。

- [ ] **Step 6: Commit**

```bash
git add hooks/hooks.json TESTING.md tests/test-post-tool-use.sh tests/test-mvp-acceptance.sh
git rm scripts/hooks/post-tool-use.sh scripts/lib/sdd-review-runner.sh
if [ -f tests/test-post-tool-use.sh ]; then git add tests/test-post-tool-use.sh; else git rm tests/test-post-tool-use.sh; fi
git commit -m "refactor: remove post-tool-use review path"
```

---

### Task 5: 同步 README、TESTING 与最终验收合同

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `tests/test-mvp-acceptance.sh`
- Modify: `tests/test-skill-contracts.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: Task 2-4 的最终 Skill 与运行时合同。
- Produces: 面向用户和验收脚本的一致叙述：review 由 `/sdd:review` 统一承接，create 显式 review，update 不自动 review。

- [ ] **Step 1: 把 README 中的 review 说明改成 Skill 驱动模型**

```md
- `/sdd:review <doc-path>` 是统一 review 入口。
- 新建 `research / prd / dr / spec / plan` 文档后，所属 Skill 会显式进入 `/sdd:review <doc-path>`。
- 修改已有文档时，不自动 review；如需复审，请手工执行 `/sdd:review <doc-path>`。
- 系统不再依赖 `PostToolUse Hook` 或 shell runner 触发 review。
```

- [ ] **Step 2: 把 TESTING 中的手工验证步骤改成 create/update 分流验证**

```md
1. 生成新 `spec` 或 `plan`，确认流程显式进入 `/sdd:review <doc-path>`。
2. 更新已有 `spec` 或 `plan`，确认不会自动 review，只输出手工复审提示。
3. 确认 `research / prd / dr` create 只触发 `quality`；`spec / plan` create 触发 `quality -> feasibility`。
4. 确认 `hooks/hooks.json` 只保留 `SessionStart` 与 `PreToolUse`。
```

- [ ] **Step 3: 运行聚焦测试与回归测试**

Run:
```bash
bash tests/test-skill-contracts.sh && \
bash tests/test-template-runtime-contract.sh && \
bash tests/test-common-library.sh && \
bash tests/test-pre-tool-use.sh && \
bash tests/test-reference-validation.sh && \
bash tests/test-mvp-acceptance.sh
```

Expected:
```text
PASS: skill contracts
PASS: template runtime contract
PASS: common library
PASS: pre-tool-use hook
PASS: reference validation
PASS: MVP acceptance
```

- [ ] **Step 4: 进行人工边界复核**

```text
- `/sdd:review` 是唯一 review 编排入口。
- `PostToolUse Hook` 已删除。
- `sdd-review-runner.sh` 已删除。
- create 显式 review，update 不自动 review。
- `spec` 与 `plan` create review 未通过时保持 `draft`。
```

- [ ] **Step 5: Commit**

```bash
git add README.md TESTING.md tests/test-skill-contracts.sh tests/test-mvp-acceptance.sh
git commit -m "docs: align review flow with skill authority"
```

## Self-Review

### Spec coverage
- 覆盖了删除 `PostToolUse Hook` 与 `sdd-review-runner.sh` 的实现与测试收敛。
- 覆盖了 `/sdd:review` 接管 runner 职责后的细粒度合同：`document_type`/mode 链路、schema 校验、聚合回执字段与 `requires_user_confirmation` 重试语义。
- 覆盖了 `research / prd / dr / spec / plan` 的 create/update 分流。
- 覆盖了 `spec` / `plan` 的 `draft` gate 约束。
- 覆盖了 Hook 删除后的新路径回归：显式 `/sdd:review` 与 create/update 行为仍被验收合同锁定。
- 覆盖了 README、TESTING 与验收测试从 Hook/runner 叙述切换到 Skill 驱动叙述。

### Placeholder scan
- 没有 `TBD`、`TODO`、`implement later`、`path/to/file` 一类占位符。
- 每个任务都给出了明确文件路径、测试命令和预期结果。
- 代码或文本改动步骤均给出了可执行或可直接抄写的内容。

### Type consistency
- 全文统一使用 `/sdd:review <doc-path>` 作为唯一 review 入口。
- 统一使用 `quality` 与 `quality -> feasibility` 作为 mode 语义。
- 统一使用 `blocked`、`requires_user_confirmation`、`remaining_items` 作为 reviewer 聚合字段名。
