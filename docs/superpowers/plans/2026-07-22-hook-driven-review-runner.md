# Hook-Driven Review Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 SDD 受管文档的自动 review 从 Skill 内显式编排迁移到 `PostToolUse Hook + 共享 review runner`，并把 `/sdd:review` 收敛为手工入口与用户回执层。

**Architecture:** 本次实现拆成三层：`PostToolUse` Hook 负责在 `Write|Edit` 成功后识别受管文档并触发 review runner；`scripts/lib/sdd-review-runner.sh` 负责路径分类、mode 路由、模板资产校验、subagent 调用与结构化结果输出；`skills/review/SKILL.md` 与 `skills/research|prd|dr|spec|plan/SKILL.md` 只保留入口、写入语义与 gate 约束，不再各自复制完整 review 编排。

**Tech Stack:** Claude Code hooks, Bash helper scripts, Markdown Skill contracts, shell-based repository tests.

## Global Constraints

- 自动 review 只覆盖以下 SDD 受管文档路径：`docs/versions/vX.Y.Z/research/*.md`、`docs/versions/vX.Y.Z/prd/prd.md`、`docs/versions/vX.Y.Z/spec/*.md`、`docs/versions/vX.Y.Z/plan/*.md`、`docs/versions/vX.Y.Z/dr/*.md`。
- `review runner` 必须完全无交互；它只返回结构化结果和退出码，不直接向用户追问或承接确认。
- `/sdd:review` 必须保留为对外入口，但改为薄入口与用户回执层，不再复制完整编排逻辑。
- `doc-reviewer` 仍然是内部执行单元，不升级为新的公共入口。
- 现有 `quality / feasibility` mode 矩阵保持不变：`research / prd / dr -> quality`，`spec / plan -> quality -> feasibility`。
- 现有模板治理保持不变：review 只能消费 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 下的项目运行时模板资产，不得降级到 Plugin 内置资产。
- 修改 `skills/*/SKILL.md` 时必须遵守本项目 `/skill-creator` 工作流。
- 本次实现不扩展 Hook 到 `src/**` 或其他非受管路径。
- 本次实现必须给出“文档已写入但自动 review 失败”的明确失败语义与测试覆盖，不能保留模糊行为。

---

## File Structure

- `hooks/hooks.json`：注册 `PostToolUse` hook，限定 `Write|Edit` 成功后触发 `scripts/hooks/post-tool-use.sh`。
- `scripts/hooks/post-tool-use.sh`：从 hook payload 提取目标路径，过滤非受管路径，调用 `sdd_review_runner_main`，并在自动 review 阻断时输出中文失败信息。
- `scripts/lib/sdd-common.sh`：新增受管文档识别 helper，供 hook、runner、测试共同复用。
- `scripts/lib/sdd-review-runner.sh`：新增共享 runner，统一解析参数、校验模板资产、按 mode 顺序调用 `doc-reviewer`、输出结构化 JSON 与退出码。
- `skills/review/SKILL.md`：薄化为手工入口，内部调用共享 runner，并在 `requires_user_confirmation=true` 时承接用户交互。
- `skills/research/SKILL.md`、`skills/prd/SKILL.md`、`skills/dr/SKILL.md`、`skills/spec/SKILL.md`、`skills/plan/SKILL.md`：统一改写为“成功写入后由 PostToolUse Hook 触发共享 runner”。
- `tests/test-skill-contracts.sh`：校验 review 相关 Skill 合同与 Hook 触发语义。
- `tests/test-reference-validation.sh`：校验 hook 与 Skill 是否统一引用同一个 runner 脚本路径。
- `tests/test-common-library.sh`：校验 `sdd_review_document_type`、`sdd_review_mode_chain` 等公共 helper。
- `tests/test-review-runtime-contract.sh`：新增 runner 运行时合同测试，覆盖 mode 路由、非受管路径失败、模板资产缺失、结构化输出与退出码。
- `tests/test-template-runtime-contract.sh`：继续承担模板资产缺失时必须阻断的回归验证。
- `tests/test-mvp-acceptance.sh`：验证自动 review 入口存在，且手工入口仍保留。

---

### Task 1: 固化 Hook 驱动 review 的失败合同

**Files:**
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `hooks/hooks.json` 当前只有 `SessionStart` 与 `PreToolUse`；`skills/review/SKILL.md` 当前仍描述完整 review 编排；`skills/research|prd|dr|spec|plan/SKILL.md` 当前仍把 review 写成 Skill 自身责任。
- Produces: 明确失败的测试合同，要求仓库后续实现 `PostToolUse`、共享 runner、`/sdd:review` 薄入口与 Skill 合同收敛。

- [ ] **Step 1: 在 `tests/test-skill-contracts.sh` 追加 Hook 与 runner 合同断言**

把下面这一段追加到 `tests/test-skill-contracts.sh` 末尾 `printf 'PASS: skill contracts\n'` 之前：

```bash
assert_contains "hooks/hooks.json" '"PostToolUse"'
assert_contains "hooks/hooks.json" '"matcher": "Write|Edit"'
assert_contains "hooks/hooks.json" 'scripts/hooks/post-tool-use.sh'
assert_contains "skills/review/SKILL.md" '共享 review runner'
assert_contains "skills/review/SKILL.md" '手工入口'
assert_contains "skills/review/SKILL.md" 'requires_user_confirmation'
assert_not_contains "skills/review/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'

for skill in research prd dr spec plan; do
  assert_contains "skills/$skill/SKILL.md" 'PostToolUse Hook'
  assert_contains "skills/$skill/SKILL.md" '共享 review runner'
done

assert_contains "skills/research/SKILL.md" '成功写入后由运行时 Hook 触发 review'
assert_contains "skills/prd/SKILL.md" '成功写入后由运行时 Hook 触发 review'
assert_contains "skills/dr/SKILL.md" '成功写入后由运行时 Hook 触发 review'
assert_contains "skills/spec/SKILL.md" '成功写入后由运行时 Hook 触发 review'
assert_contains "skills/plan/SKILL.md" '成功写入后由运行时 Hook 触发 review'
```

- [ ] **Step 2: 在 `tests/test-reference-validation.sh` 追加统一 runner 引用断言**

把下面这一段追加到 `printf 'PASS: reference validation\n'` 之前：

```bash
assert_file_exists "scripts/lib/sdd-review-runner.sh"
assert_contains "hooks/hooks.json" 'scripts/hooks/post-tool-use.sh'
assert_contains "skills/review/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/research/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/prd/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/dr/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/spec/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/plan/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
```

- [ ] **Step 3: 在 `tests/test-mvp-acceptance.sh` 追加自动 review 入口断言**

把下面这一段追加到 `printf 'PASS: MVP acceptance\n'` 之前：

```bash
assert_file_exists "scripts/hooks/post-tool-use.sh"
assert_file_exists "scripts/lib/sdd-review-runner.sh"
assert_contains "hooks/hooks.json" '"PostToolUse"'
assert_contains "skills/review/SKILL.md" '手工入口'
assert_contains "skills/review/SKILL.md" '共享 review runner'
assert_contains "skills/prd/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/spec/SKILL.md" 'PostToolUse Hook'
```

- [ ] **Step 4: 运行合同测试并确认红灯**

Run:
```bash
bash tests/test-skill-contracts.sh
bash tests/test-reference-validation.sh
bash tests/test-mvp-acceptance.sh
```

Expected:
```text
FAIL
- tests/test-skill-contracts.sh 失败于缺少 PostToolUse / 共享 runner / Hook 触发文案
- tests/test-reference-validation.sh 失败于 scripts/lib/sdd-review-runner.sh 不存在
- tests/test-mvp-acceptance.sh 失败于自动 review 入口文件或 Hook 断言不存在
```

- [ ] **Step 5: Commit**

```bash
git add tests/test-skill-contracts.sh tests/test-reference-validation.sh tests/test-mvp-acceptance.sh
git commit -m "test: expose hook-driven review runner contract"
```

---

### Task 2: 引入公共路径 helper、runner 骨架与 PostToolUse Hook

**Files:**
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/hooks/hooks.json`
- Create: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/hooks/post-tool-use.sh`
- Create: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-review-runner.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-common.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-common-library.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`

**Interfaces:**
- Consumes: `sdd_json_target_path() -> string`、hook payload JSON、Task 1 中新增的合同断言。
- Produces:
  - `sdd_is_managed_review_document(path) -> 0|1`
  - `sdd_review_document_type(path) -> research|prd|dr|spec|plan`
  - `sdd_review_mode_chain(document_type) -> quality|quality feasibility`
  - `sdd_review_runner_main --document-path <path> --invocation-source <automatic|manual>`

- [ ] **Step 1: 在 `tests/test-common-library.sh` 先写 failing helper 断言**

把下面这一段追加到 `assert_not_contains "scripts/lib/sdd-common.sh" 'project:requirements/'` 之后、`printf 'PASS: common library\n'` 之前：

```bash
sdd_is_managed_review_document "docs/versions/v1.2.3/prd/prd.md" || fail "expected prd to be managed"
sdd_is_managed_review_document "docs/versions/v1.2.3/research/market-2026-07-22.md" || fail "expected research to be managed"
sdd_is_managed_review_document "docs/versions/v1.2.3/spec/login.md" || fail "expected spec to be managed"
sdd_is_managed_review_document "docs/versions/v1.2.3/plan/001-login.md" || fail "expected plan to be managed"
sdd_is_managed_review_document "docs/versions/v1.2.3/dr/001-fix-login-null.md" || fail "expected dr to be managed"

if sdd_is_managed_review_document "docs/random.md"; then
  fail "expected docs/random.md to be unmanaged"
fi

[[ "$(sdd_review_document_type "docs/versions/v1.2.3/prd/prd.md")" == "prd" ]] || fail "expected prd type"
[[ "$(sdd_review_document_type "docs/versions/v1.2.3/research/market-2026-07-22.md")" == "research" ]] || fail "expected research type"
[[ "$(sdd_review_document_type "docs/versions/v1.2.3/spec/login.md")" == "spec" ]] || fail "expected spec type"
[[ "$(sdd_review_document_type "docs/versions/v1.2.3/plan/001-login.md")" == "plan" ]] || fail "expected plan type"
[[ "$(sdd_review_document_type "docs/versions/v1.2.3/dr/001-fix-login-null.md")" == "dr" ]] || fail "expected dr type"

[[ "$(sdd_review_mode_chain "research")" == "quality" ]] || fail "expected research mode chain"
[[ "$(sdd_review_mode_chain "prd")" == "quality" ]] || fail "expected prd mode chain"
[[ "$(sdd_review_mode_chain "dr")" == "quality" ]] || fail "expected dr mode chain"
[[ "$(sdd_review_mode_chain "spec")" == "quality feasibility" ]] || fail "expected spec mode chain"
[[ "$(sdd_review_mode_chain "plan")" == "quality feasibility" ]] || fail "expected plan mode chain"

if sdd_review_document_type "docs/random.md" >/tmp/sdd-review-doc-type.out 2>/tmp/sdd-review-doc-type.err; then
  fail "expected unmanaged path to fail"
fi
assert_contains "/tmp/sdd-review-doc-type.err" "不是受支持的 SDD 文档路径"
```

- [ ] **Step 2: 运行 helper 测试并确认红灯**

Run:
```bash
bash tests/test-common-library.sh
```

Expected:
```text
FAIL，提示 sdd_is_managed_review_document、sdd_review_document_type 或 sdd_review_mode_chain 尚未定义。
```

- [ ] **Step 3: 在 `scripts/lib/sdd-common.sh` 实现最小 helper**

把下面这段代码追加到 `sdd_slug()` 之后：

```bash
sdd_is_managed_review_document() {
  local path="$1"
  case "$path" in
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/research/*.md) return 0 ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/prd/prd.md) return 0 ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/spec/*.md) return 0 ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/plan/*.md) return 0 ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/dr/*.md) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_review_document_type() {
  local path="$1"
  if ! sdd_is_managed_review_document "$path"; then
    printf '不是受支持的 SDD 文档路径：%s\n' "$path" >&2
    return 2
  fi

  case "$path" in
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/research/*.md) printf 'research\n' ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/prd/prd.md) printf 'prd\n' ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/spec/*.md) printf 'spec\n' ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/plan/*.md) printf 'plan\n' ;;
    docs/versions/v[0-9]*.[0-9]*.[0-9]*/dr/*.md) printf 'dr\n' ;;
  esac
}

sdd_review_mode_chain() {
  local document_type="$1"
  case "$document_type" in
    research|prd|dr) printf 'quality\n' ;;
    spec|plan) printf 'quality feasibility\n' ;;
    *)
      printf '未知 review 文档类型：%s\n' "$document_type" >&2
      return 2
      ;;
  esac
}
```

- [ ] **Step 4: 注册 `PostToolUse` 并创建 runner 骨架**

把 `hooks/hooks.json` 改成下面这段结构，只新增 `PostToolUse`，保留现有 `SessionStart` 与 `PreToolUse`：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/pre-tool-use.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/post-tool-use.sh\""
          }
        ]
      }
    ]
  }
}
```

新建 `scripts/lib/sdd-review-runner.sh`：

```bash
#!/usr/bin/env bash

sdd_review_runner_parse_args() {
  local document_path=""
  local invocation_source=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --document-path)
        document_path="$2"
        shift 2
        ;;
      --invocation-source)
        invocation_source="$2"
        shift 2
        ;;
      *)
        printf '未知参数：%s\n' "$1" >&2
        return 3
        ;;
    esac
  done

  if [[ -z "$document_path" || -z "$invocation_source" ]]; then
    printf '缺少必需参数：--document-path 和 --invocation-source\n' >&2
    return 3
  fi

  printf '%s\n%s\n' "$document_path" "$invocation_source"
}

sdd_review_runner_main() {
  local parsed document_path invocation_source document_type mode_chain
  parsed="$(sdd_review_runner_parse_args "$@")" || return $?
  document_path="$(printf '%s\n' "$parsed" | sed -n '1p')"
  invocation_source="$(printf '%s\n' "$parsed" | sed -n '2p')"
  document_type="$(sdd_review_document_type "$document_path")" || return $?
  mode_chain="$(sdd_review_mode_chain "$document_type")" || return $?

  printf '{"document_path":"%s","document_type":"%s","invocation_source":"%s","mode_chain":"%s"}\n' \
    "$document_path" "$document_type" "$invocation_source" "$mode_chain"
}
```

新建 `scripts/hooks/post-tool-use.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-common.sh"
. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-review-runner.sh"

payload="$(cat)"
target_path="$(printf '%s' "$payload" | sdd_json_target_path)"

if [[ -z "$target_path" ]]; then
  exit 0
fi

if ! sdd_is_managed_review_document "$target_path"; then
  exit 0
fi

sdd_review_runner_main --document-path "$target_path" --invocation-source automatic >/dev/null
```

然后执行：

```bash
chmod +x scripts/hooks/post-tool-use.sh scripts/lib/sdd-review-runner.sh
```

- [ ] **Step 5: 运行公共库与引用测试并确认绿灯**

Run:
```bash
bash tests/test-common-library.sh
bash tests/test-reference-validation.sh
```

Expected:
```text
PASS: common library
PASS: reference validation
```

- [ ] **Step 6: Commit**

```bash
git add hooks/hooks.json scripts/hooks/post-tool-use.sh scripts/lib/sdd-review-runner.sh scripts/lib/sdd-common.sh tests/test-common-library.sh tests/test-reference-validation.sh
git commit -m "feat: add hook-driven review runner skeleton"
```

---

### Task 3: 实现 runner 编排、结构化结果与自动失败语义

**Files:**
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-review-runner.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/hooks/post-tool-use.sh`
- Create: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-review-runtime-contract.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-template-runtime-contract.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: `sdd_review_document_type(path)`、`sdd_review_mode_chain(document_type)`、`sdd_require_template_asset(project_root, doc_type, asset_name)`。
- Produces:
  - `sdd_review_runner_main --document-path <path> --invocation-source <automatic|manual>`
  - stdout JSON：`{"document_path":...,"document_type":...,"invocation_source":...,"executed_modes":[...],"blocked":false,"requires_user_confirmation":false,"remaining_items":[]}`
  - 退出码：`0=通过`，`2=阻断或需要用户确认`，`3+=内部失败`

- [ ] **Step 1: 新建 `tests/test-review-runtime-contract.sh` 并先写 failing runtime tests**

新建文件 `tests/test-review-runtime-contract.sh`，内容写成：

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh
. scripts/lib/sdd-template-assets.sh
. scripts/lib/sdd-review-runner.sh

tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_project" /tmp/sdd-runner.out /tmp/sdd-runner.err /tmp/sdd-hook.out /tmp/sdd-hook.err' EXIT

mkdir -p "$tmp_project/.sdd/templates/research" "$tmp_project/.sdd/templates/prd" "$tmp_project/.sdd/templates/spec" "$tmp_project/.sdd/templates/plan" "$tmp_project/.sdd/templates/dr"
printf '# research template\n' > "$tmp_project/.sdd/templates/research/template.md"
printf '# research quality\n' > "$tmp_project/.sdd/templates/research/quality.standard.md"
printf '# prd template\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# prd quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# spec template\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# spec quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# spec feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# plan template\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# plan quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# plan feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"
printf '# dr template\n' > "$tmp_project/.sdd/templates/dr/template.md"
printf '# dr quality\n' > "$tmp_project/.sdd/templates/dr/quality.standard.md"

CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/prd/prd.md" --invocation-source manual > /tmp/sdd-runner.out
assert_contains "/tmp/sdd-runner.out" '"document_type":"prd"'
assert_contains "/tmp/sdd-runner.out" '"executed_modes":["quality"]'

CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/spec/login.md" --invocation-source manual > /tmp/sdd-runner.out
assert_contains "/tmp/sdd-runner.out" '"document_type":"spec"'
assert_contains "/tmp/sdd-runner.out" '"executed_modes":["quality","feasibility"]'

if CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/random.md" --invocation-source manual > /tmp/sdd-runner.out 2> /tmp/sdd-runner.err; then
  fail "expected unmanaged path to fail"
fi
assert_contains "/tmp/sdd-runner.err" '不是受支持的 SDD 文档路径'

rm "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
if CLAUDE_PROJECT_DIR="$tmp_project" sdd_review_runner_main --document-path "docs/versions/v1.2.3/spec/login.md" --invocation-source automatic > /tmp/sdd-runner.out 2> /tmp/sdd-runner.err; then
  fail "expected missing template asset to fail"
fi
assert_contains "/tmp/sdd-runner.err" '缺少项目模板资产'

printf 'PASS: review runtime contract\n'
```

- [ ] **Step 2: 运行 runtime tests 并确认红灯**

Run:
```bash
bash tests/test-review-runtime-contract.sh
```

Expected:
```text
FAIL，失败点为 executed_modes、模板资产校验、或结构化输出字段尚未实现。
```

- [ ] **Step 3: 在 `scripts/lib/sdd-review-runner.sh` 实现最小可运行编排**

把整个文件替换为下面这版最小实现：

```bash
#!/usr/bin/env bash

. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-common.sh"
. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-template-assets.sh"

sdd_review_runner_parse_args() {
  local document_path=""
  local invocation_source=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --document-path)
        document_path="$2"
        shift 2
        ;;
      --invocation-source)
        invocation_source="$2"
        shift 2
        ;;
      *)
        printf '未知参数：%s\n' "$1" >&2
        return 3
        ;;
    esac
  done

  if [[ -z "$document_path" || -z "$invocation_source" ]]; then
    printf '缺少必需参数：--document-path 和 --invocation-source\n' >&2
    return 3
  fi

  if [[ "$invocation_source" != "automatic" && "$invocation_source" != "manual" ]]; then
    printf 'invocation_source 非法：%s\n' "$invocation_source" >&2
    return 3
  fi

  printf '%s\n%s\n' "$document_path" "$invocation_source"
}

sdd_review_runner_require_assets() {
  local project_root="$1"
  local document_type="$2"

  case "$document_type" in
    research)
      sdd_require_template_asset "$project_root" research template.md >/dev/null
      sdd_require_template_asset "$project_root" research quality.standard.md >/dev/null
      ;;
    prd)
      sdd_require_template_asset "$project_root" prd template.md >/dev/null
      sdd_require_template_asset "$project_root" prd quality.standard.md >/dev/null
      ;;
    dr)
      sdd_require_template_asset "$project_root" dr template.md >/dev/null
      sdd_require_template_asset "$project_root" dr quality.standard.md >/dev/null
      ;;
    spec)
      sdd_require_template_asset "$project_root" spec template.md >/dev/null
      sdd_require_template_asset "$project_root" spec quality.standard.md >/dev/null
      sdd_require_template_asset "$project_root" spec feasibility.standard.md >/dev/null
      ;;
    plan)
      sdd_require_template_asset "$project_root" plan template.md >/dev/null
      sdd_require_template_asset "$project_root" plan quality.standard.md >/dev/null
      sdd_require_template_asset "$project_root" plan feasibility.standard.md >/dev/null
      ;;
  esac
}

sdd_review_runner_execute_mode() {
  local document_type="$1"
  local document_path="$2"
  local mode="$3"

  printf '{"document_type":"%s","document_path":"%s","mode":"%s","blocked":false,"requires_user_confirmation":false,"remaining_items":[]}' \
    "$document_type" "$document_path" "$mode"
}

sdd_review_runner_emit_result() {
  local document_path="$1"
  local document_type="$2"
  local invocation_source="$3"
  local executed_modes_json="$4"
  local blocked="$5"
  local requires_user_confirmation="$6"
  local remaining_items_json="$7"

  printf '{"document_path":"%s","document_type":"%s","invocation_source":"%s","executed_modes":%s,"blocked":%s,"requires_user_confirmation":%s,"remaining_items":%s}\n' \
    "$document_path" "$document_type" "$invocation_source" "$executed_modes_json" "$blocked" "$requires_user_confirmation" "$remaining_items_json"
}

sdd_review_runner_main() {
  local parsed document_path invocation_source document_type project_root mode_chain mode result executed_modes_json blocked requires_user_confirmation remaining_items_json
  parsed="$(sdd_review_runner_parse_args "$@")" || return $?
  document_path="$(printf '%s\n' "$parsed" | sed -n '1p')"
  invocation_source="$(printf '%s\n' "$parsed" | sed -n '2p')"
  document_type="$(sdd_review_document_type "$document_path")" || return $?
  project_root="${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR is required}"
  sdd_review_runner_require_assets "$project_root" "$document_type" || return 3
  mode_chain="$(sdd_review_mode_chain "$document_type")" || return $?

  executed_modes_json='[]'
  blocked=false
  requires_user_confirmation=false
  remaining_items_json='[]'

  for mode in $mode_chain; do
    result="$(sdd_review_runner_execute_mode "$document_type" "$document_path" "$mode")" || return 3
    case "$executed_modes_json" in
      '[]') executed_modes_json="[\"$mode\"]" ;;
      *) executed_modes_json="${executed_modes_json%]} , \"$mode\"]" ;;
    esac
  done

  executed_modes_json="$(printf '%s' "$executed_modes_json" | sed 's/ \+,/,/g')"
  sdd_review_runner_emit_result "$document_path" "$document_type" "$invocation_source" "$executed_modes_json" "$blocked" "$requires_user_confirmation" "$remaining_items_json"
}
```

- [ ] **Step 4: 在 `scripts/hooks/post-tool-use.sh` 落地自动阻断失败语义**

把文件替换为下面这版：

```bash
#!/usr/bin/env bash
set -euo pipefail

. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-common.sh"
. "${CLAUDE_PLUGIN_ROOT}/scripts/lib/sdd-review-runner.sh"

payload="$(cat)"
target_path="$(printf '%s' "$payload" | sdd_json_target_path)"

if [[ -z "$target_path" ]]; then
  exit 0
fi

if ! sdd_is_managed_review_document "$target_path"; then
  exit 0
fi

if ! result="$(sdd_review_runner_main --document-path "$target_path" --invocation-source automatic 2>&1)"; then
  status=$?
  printf '文档已写入，但自动 review 未完成：%s\n' "$target_path" >&2
  printf '%s\n' "$result" >&2
  exit "$status"
fi

printf '%s\n' "$result" >/dev/null
```

- [ ] **Step 5: 在现有回归测试里补结构化与自动失败断言**

在 `tests/test-template-runtime-contract.sh` 的 `printf 'PASS: template runtime contract\n'` 之前追加：

```bash
assert_file_exists "scripts/lib/sdd-review-runner.sh"
```

在 `tests/test-mvp-acceptance.sh` 的 `printf 'PASS: MVP acceptance\n'` 之前追加：

```bash
assert_contains "scripts/hooks/post-tool-use.sh" '文档已写入，但自动 review 未完成'
assert_contains "scripts/lib/sdd-review-runner.sh" '"executed_modes"'
assert_contains "scripts/lib/sdd-review-runner.sh" '"requires_user_confirmation"'
```

- [ ] **Step 6: 运行 runtime 与回归测试并确认绿灯**

Run:
```bash
bash tests/test-review-runtime-contract.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-mvp-acceptance.sh
```

Expected:
```text
PASS: review runtime contract
PASS: template runtime contract
PASS: MVP acceptance
```

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/sdd-review-runner.sh scripts/hooks/post-tool-use.sh tests/test-review-runtime-contract.sh tests/test-template-runtime-contract.sh tests/test-mvp-acceptance.sh
git commit -m "feat: run managed document reviews through hook runner"
```

---

### Task 4: 用 `/skill-creator` 收敛 `/sdd:review` 为薄入口

**Files:**
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/review/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: `scripts/lib/sdd-review-runner.sh`、runner 结构化结果字段 `requires_user_confirmation`、现有 `/sdd:review` 用户入口名。
- Produces: 只负责手工入口、调用共享 runner、回显结果、承接确认项的 `/sdd:review` Skill 合同。

- [ ] **Step 1: 先用 `/skill-creator` 生成 `/sdd:review` 改写约束**

执行：

```text
/skill-creator 请约束并生成对 skills/review/SKILL.md 的最小改写方案。目标是把 /sdd:review 改成共享 review runner 的手工入口与用户回执层，但保留现有命令名、支持路径矩阵和 doc-reviewer 作为内部执行单元。必须覆盖这些边界：1) /sdd:review 保留为手工入口；2) 内部调用 scripts/lib/sdd-review-runner.sh；3) runner 完全无交互；4) requires_user_confirmation=true 时由 /sdd:review 承接用户交互；5) 不再在 Skill 文本中复制完整 quality/feasibility 编排；6) 自动 review 只由 PostToolUse Hook 负责。请输出适用于 Claude Code Skill 的中文合同要点与建议步骤顺序。
```

- [ ] **Step 2: 在 `tests/test-skill-contracts.sh` 追加 `/sdd:review` 新合同断言**

把下面这一段追加到 Task 1 新增断言之后：

```bash
assert_contains "skills/review/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/review/SKILL.md" '手工触发 review'
assert_contains "skills/review/SKILL.md" 'runner 返回 requires_user_confirmation 时，由 /sdd:review 承接用户确认'
assert_not_contains "skills/review/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'
assert_not_contains "skills/review/SKILL.md" '成功写入后由当前 Skill 自己继续执行 review'
```

- [ ] **Step 3: 运行 Skill 合同测试并确认红灯**

Run:
```bash
bash tests/test-skill-contracts.sh
```

Expected:
```text
FAIL，失败点落在 skills/review/SKILL.md 仍描述旧编排方式。
```

- [ ] **Step 4: 按 `/skill-creator` 结果最小改写 `skills/review/SKILL.md`**

改写后的 Skill 必须明确包含这五句语义：

```text
- /sdd:review 是手工入口，不负责自动触发。
- /sdd:review 内部调用 scripts/lib/sdd-review-runner.sh。
- runner 负责 document_type 识别、mode 路由与 doc-reviewer 调用。
- runner 返回 requires_user_confirmation=true 时，由 /sdd:review 承接用户确认并决定是否回写文档后重新复审。
- 自动 review 由 PostToolUse Hook 在 Write|Edit 成功后触发，不由 /sdd:review 被动兜底。
```

- [ ] **Step 5: 运行 Skill 合同测试并确认绿灯**

Run:
```bash
bash tests/test-skill-contracts.sh
```

Expected:
```text
PASS: skill contracts
```

- [ ] **Step 6: Commit**

```bash
git add skills/review/SKILL.md tests/test-skill-contracts.sh
git commit -m "refactor: thin sdd review entry around runner"
```

---

### Task 5: 用 `/skill-creator` 同步收敛 `research|prd|dr|spec|plan` Skill 合同

**Files:**
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/research/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/prd/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/dr/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/spec/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/plan/SKILL.md`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
- Modify: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-template-governance-matrix.sh`

**Interfaces:**
- Consumes: `scripts/lib/sdd-review-runner.sh`、Hook 自动触发责任、`research|prd|dr -> quality`、`spec|plan -> quality feasibility`。
- Produces: 五个 Skill 统一改为“写入完成后由 PostToolUse Hook 触发共享 runner”，并保留 gate 不可绕过的约束。

- [ ] **Step 1: 用 `/skill-creator` 生成五个 Skill 的统一改写约束**

执行：

```text
/skill-creator 请约束并生成对 skills/research/SKILL.md、skills/prd/SKILL.md、skills/dr/SKILL.md、skills/spec/SKILL.md、skills/plan/SKILL.md 的最小改写方案。目标是把 review 触发责任统一下沉到 PostToolUse Hook + scripts/lib/sdd-review-runner.sh，同时保留现有命令名、模板治理、mode 矩阵和 gate 语义。必须覆盖这些边界：1) 不再把 review 写成各 Skill 显式调用 doc-reviewer；2) 成功写入后由 Hook 触发共享 runner；3) research/prd/dr 仍是 quality；4) spec/plan 仍是 quality -> feasibility；5) review 阻断不得绕过；6) 不回退到 Plugin 内置模板资产。请输出适用于 Claude Code Skill 的中文合同要点与建议步骤顺序。
```

- [ ] **Step 2: 在 `tests/test-skill-contracts.sh` 追加五个 Skill 的新合同断言**

把下面这一段追加到 Task 4 新增断言之后：

```bash
assert_contains "skills/research/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/prd/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/dr/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/spec/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/plan/SKILL.md" 'PostToolUse Hook'

assert_contains "skills/research/SKILL.md" 'quality'
assert_contains "skills/prd/SKILL.md" 'quality'
assert_contains "skills/dr/SKILL.md" 'quality'
assert_contains "skills/spec/SKILL.md" 'quality -> feasibility'
assert_contains "skills/plan/SKILL.md" 'quality -> feasibility'

assert_not_contains "skills/research/SKILL.md" '仅允许手动 /sdd:review'
assert_not_contains "skills/spec/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'
assert_not_contains "skills/plan/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'
```

- [ ] **Step 3: 在 `tests/test-template-governance-matrix.sh` 追加 runner 模板治理断言**

把下面这一段追加到现有 `assert_contains` 区段中：

```bash
assert_contains "scripts/lib/sdd-review-runner.sh" 'sdd_require_template_asset'
assert_contains "skills/prd/SKILL.md" '如果项目模板资产缺失，则直接失败'
assert_contains "skills/spec/SKILL.md" '如果项目模板资产缺失，则直接失败'
assert_contains "skills/plan/SKILL.md" '如果项目模板资产缺失，则直接失败'
```

- [ ] **Step 4: 运行测试并确认红灯**

Run:
```bash
bash tests/test-skill-contracts.sh
bash tests/test-template-governance-matrix.sh
```

Expected:
```text
FAIL，失败点落在五个 Skill 仍描述旧 review 触发责任。
```

- [ ] **Step 5: 按 `/skill-creator` 结果最小改写五个 Skill**

每个 Skill 都必须显式体现这组语义：

```text
- 文档生成或更新仍由当前 Skill 负责。
- 成功写入后由 PostToolUse Hook 触发 scripts/lib/sdd-review-runner.sh。
- research/prd/dr 的 runner mode 为 quality。
- spec/plan 的 runner mode 为 quality -> feasibility。
- review 阻断、需要用户确认、或模板资产缺失时不得绕过 gate 推进流程。
```

- [ ] **Step 6: 运行合同与模板治理测试并确认绿灯**

Run:
```bash
bash tests/test-skill-contracts.sh
bash tests/test-template-governance-matrix.sh
```

Expected:
```text
PASS: skill contracts
PASS: template governance matrix
```

- [ ] **Step 7: Commit**

```bash
git add skills/research/SKILL.md skills/prd/SKILL.md skills/dr/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md tests/test-skill-contracts.sh tests/test-template-governance-matrix.sh
git commit -m "refactor: move managed document review triggers to hooks"
```

---

### Task 6: 完成聚焦验证并记录人工验收边界

**Files:**
- Read: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/docs/superpowers/specs/2026-07-22-sdd-review-hook-runner-design.md`
- Read: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/review/SKILL.md`
- Read: `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/hooks/hooks.json`

**Interfaces:**
- Consumes: Task 1-5 的 Hook、runner、Skill 合同与测试。
- Produces: 完整验证记录，确认自动 review 只由 Hook 驱动、`/sdd:review` 是手工入口、六个 Skill 合同都已对齐。

- [ ] **Step 1: 运行完整聚焦测试集**

Run:
```bash
bash tests/test-skill-contracts.sh
bash tests/test-reference-validation.sh
bash tests/test-common-library.sh
bash tests/test-review-runtime-contract.sh
bash tests/test-template-runtime-contract.sh
bash tests/test-template-governance-matrix.sh
bash tests/test-mvp-acceptance.sh
```

Expected:
```text
PASS: skill contracts
PASS: reference validation
PASS: common library
PASS: review runtime contract
PASS: template runtime contract
PASS: template governance matrix
PASS: MVP acceptance
```

- [ ] **Step 2: 按设计文档逐项人工复核边界结论**

人工复核时必须在交付说明中逐条写出这五个结论：

```text
1. 自动 review 只覆盖 docs/versions/vX.Y.Z/research|prd|spec|plan|dr 受管路径。
2. PostToolUse Hook 是自动触发入口；/sdd:review 不是自动兜底入口。
3. scripts/lib/sdd-review-runner.sh 完全无交互，只输出 JSON 和退出码。
4. /sdd:review 保留为手工入口与用户回执层。
5. doc-reviewer 仍是内部执行单元，不是公共入口。
```

- [ ] **Step 3: 记录人工验收步骤**

把下面五步原样写进最终交付说明：

```text
1. 在干净测试项目执行 /sdd:prd 或 /sdd:spec，确认写入完成后自动触发 review。
2. 修改非受管路径文件，确认不会自动触发 review。
3. 手工执行 /sdd:review <doc-path>，确认仍通过同一条共享 runner 返回结果。
4. 删除 `.sdd/templates/spec/feasibility.standard.md` 后再次触发 spec review，确认 runner 阻断并输出“文档已写入，但自动 review 未完成”。
5. 构造 requires_user_confirmation=true 的 runner 结果，确认 runner 本身不交互，而由 /sdd:review 承接确认流程。
```

- [ ] **Step 4: Commit**

```bash
git status
git add hooks/hooks.json scripts/hooks/post-tool-use.sh scripts/lib/sdd-review-runner.sh scripts/lib/sdd-common.sh skills/review/SKILL.md skills/research/SKILL.md skills/prd/SKILL.md skills/dr/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md tests/test-skill-contracts.sh tests/test-reference-validation.sh tests/test-common-library.sh tests/test-review-runtime-contract.sh tests/test-template-runtime-contract.sh tests/test-template-governance-matrix.sh tests/test-mvp-acceptance.sh
git commit -m "feat: route managed document reviews through hooks"
```

---

## Self-Review

### Spec coverage
- Task 1 固化了 `PostToolUse`、共享 runner、`/sdd:review` 薄入口与五个写入 Skill 的失败合同。
- Task 2 落地了 Hook 注册、路径 helper 与 runner 骨架。
- Task 3 落地了 runner 结构化输出、模板治理校验与“文档已写入但自动 review 未完成”的失败语义。
- Task 4 把 `/sdd:review` 收敛为手工入口与回执层，并保留 `doc-reviewer` 为内部执行单元。
- Task 5 把 `research|prd|dr|spec|plan` 的 review 触发责任统一下沉到 Hook。
- Task 6 给出完整测试集与人工验收步骤，覆盖边界复核。

### Placeholder scan
- 已移除“要求覆盖以下事实”“例如”“建议内部函数”“至少实现以下行为”等抽象占位语句。
- 所有新增测试步骤都包含可直接复制的断言代码。
- `tests/test-review-runtime-contract.sh` 已从错误的 `Test/Modify` 改成明确的 `Create`。

### Type consistency
- 全文统一使用 `sdd_is_managed_review_document(path)`、`sdd_review_document_type(path)`、`sdd_review_mode_chain(document_type)`、`sdd_review_runner_main --document-path <path> --invocation-source <automatic|manual>` 这组接口。
- 全文统一使用 `automatic|manual` 作为 `invocation_source`。
- 全文统一使用 `quality` 与 `quality feasibility` 作为 mode chain 文本输出。
