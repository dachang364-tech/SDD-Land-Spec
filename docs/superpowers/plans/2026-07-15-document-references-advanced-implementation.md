# Document References Advanced Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the SDD plugin from the `docs/vX.Y.Z/` directory model to the `docs/versions/vX.Y.Z/` + per-version `state.json` state-file model, add the unified `## 文档引用` reference table with a 6-value relation enum and locator rules, and rewrite `/sdd:archive` as a non-moving state-file archive that generates `ARCHIVE.md` and `docs/archive/INDEX.md`, so `docs/superpowers/specs/2026-07-14-document-references-advanced-spec.md` (all 65 acceptance criteria) is fully implemented and contract-tested.

**Architecture:** The plugin stays file-driven. Behavior lives in Claude Code Skill markdown under `skills/*/SKILL.md`, document templates under `skills/*/references/*.tmpl`, one shared Bash helper library `scripts/lib/sdd-common.sh`, one PreToolUse hook `scripts/hooks/pre-tool-use.sh`, user-facing contracts `README.md` and `CONSTITUTION.default.md`, and Bash contract tests under `tests/`. The single largest change is the active-version discovery model: helpers and hooks must resolve the unique active version by scanning `docs/versions/v*/state.json` (state `active`) rather than by scanning `docs/v*` directories. Every skill and asset that references `docs/vX.Y.Z/` moves to `docs/versions/vX.Y.Z/`. A packaged copy is regenerated under `dist/sdd-local/` by `scripts/package-local.sh` at the end.

**Tech Stack:** Claude Code Skills markdown, Markdown document templates, Bash 3.2+ helper library and hook, `python3` (already used by `sdd_json_target_path`) for JSON parsing, Bash contract tests using `tests/test-common.sh` assertions, `node` for packaging metadata checks.

## Global Constraints

- New system supports only `docs/versions/vX.Y.Z/`; `docs/vX.Y.Z/` is never a current, compatible, or fallback structure. (spec 4.1)
- Do not introduce `.sdd/state.json` or any centralized state store; version state lives in `docs/versions/vX.Y.Z/state.json`. (spec 6, 8)
- Minimal `state.json`: `{"version","state","created_at","archived_at"}`; `state` is exactly `active` or `archived`. (spec 6)
- Exactly one `state: active` version is required for main-flow skills; 0 active is legal only after `/sdd:archive` or `/sdd:init`, and dependent skills must stop and suggest `/sdd:new vX.Y.Z`. (spec 6)
- SDD-managed status lines keep the format `- 状态：<value>`. (spec 10.1, existing convention)
- Relation enum is exactly: `references`, `derives_from`, `implements`, `modifies`, `replaces`, `deprecates`. (spec 11)
- Unified reference table header is exactly 5 columns: `| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |`. Empty set row is exactly `| 未声明。 | - | - | - | - |`. (spec 10.1)
- Same-version references use source-directory-relative Markdown links; cross-version references additionally require a `vX.Y.Z:<version-relative-path>` locator; project-level requirements require a `project:requirements/<file>.md` locator. (spec 7, 8, 9)
- `plan` must never use `modifies`, `replaces`, `deprecates`. (spec 11, 12, 16.8)
- `/sdd:archive` must not move version directories, must not modify spec/plan/DR status or body, and must only mechanically extract the reference summary from `## 文档引用` tables. (spec 13, 15, 16.5)
- `INDEX.md` links only to each version `ARCHIVE.md`; never to concrete spec/plan/DR/requirements. (spec 13, 15)
- No template placeholders in shipped skills or generated docs: never `TBD`, `TODO`, `待定`, `待补充`, `path/to/file`. Literal display placeholders such as `<dr-id>`, `vX.Y.Z`, `<spec-name>` are allowed only where a template or skill must show that syntax to users.
- Do not stage, commit, or delete the user's existing dirty changes: the deleted `docs/superpowers/specs/2026-07-13-archive-advanced-spec.md`, the untracked `docs/others/`, or the target spec `docs/superpowers/specs/2026-07-14-document-references-advanced-spec.md`. Every commit stages only the exact paths listed in its `git add`. No task stages this plan file itself.
- `tests/test-skill-contracts.sh` is edited by Tasks 2, 4, 5, 6, 7, 8, 9, 10, 11. All line numbers cited for that file refer to the original committed file; because each task shifts subsequent line numbers, always locate the target assertions by their quoted content (the content anchor), and treat the line number only as a hint. No two tasks rewrite the same assertion block.

---

## 1. 实施目标

落地 `docs/superpowers/specs/2026-07-14-document-references-advanced-spec.md` 定义的全部行为，交付完成后可观察结果：

- `/sdd:init` 创建 `docs/requirements/`、`docs/versions/`、`docs/archive/`，不创建版本目录或版本级 `state.json`。
- `/sdd:new vX.Y.Z` 创建 `docs/versions/vX.Y.Z/` + `state.json`(`active`) + `specs/`、`plans/`、`decisions/`。
- 主流程 skill（status/doctor/prd/spec/plan/dr/triage/code/archive）通过 `docs/versions/v*/state.json` 发现唯一 active version，并对 0/1/多 active 与损坏 state 做规定分支。
- PRD、spec、plan、DR 模板都带统一 `## 文档引用` 表；关系枚举、locator、空集合行、blocking/warning 检查规则一致。
- `/sdd:archive` 不移动目录，生成 `ARCHIVE.md`，把 `state.json` 改为 `archived` 并写 `archived_at`，创建/更新 `docs/archive/INDEX.md`。
- 全部 contract tests、fixtures、README、TESTING、CONSTITUTION.default.md、`dist/sdd-local/` 与上述行为一致。

## 2. 契约边界

- 本 plan 只实现 spec 已批准行为，不新增功能契约。
- 若实现中发现 spec 契约不足或矛盾，停止当前 plan，先回到 `/sdd:dr` 或 `/sdd:spec` 修订契约，不在 plan 中私自扩张行为。
- 关系枚举、locator 格式、`state.json` 字段、状态值集合以 spec 第 6、7、9、11、14 节为唯一来源。

## 3. 技术方案

### 3.1 方案概述

采用「先 state helper、再 reference validator、再 hook、再 skills、再模板、再文档、最后打包」的自底向上顺序。helper 库 `sdd-common.sh` 是所有 skill 与 hook 的公共基座，`sdd_active_version_dir` 从目录扫描改为 `state.json` 扫描是本次影响面最大的改动，因此第一批 task 先落地 helper 的新函数与新语义并配套契约测试。spec §7-§14 定义的引用模型（五列表解析、relation enum、source-parent 相对 link 解析、locator、path/link identity、direction matrix、blocking/warning、archive 机械摘要）是本次第二个可独立测试的机械基座，因此单独作为一个 TDD task 落地在 `scripts/lib/sdd-references.sh`，让 `/sdd:archive` 与 `/sdd:doctor` 的引用校验行为有可由 Bash contract test 直接驱动的实现，而不是只靠 skill 文案。随后逐层向上改。测试文件按责任拆分：state helper 行为进 `tests/test-common-library.sh`，reference validator 行为进 `tests/test-reference-validation.sh`，hook 行为进 `tests/test-pre-tool-use.sh`，skill/模板/README/CONSTITUTION 静态契约进 `tests/test-skill-contracts.sh`，打包进 `tests/test-package-local.sh`，聚合验证进 `tests/test-mvp-acceptance.sh` 与 `tests/test-doctor-contract.sh`。fixtures（`valid-project.sh`、`invalid-project.sh`）在改 state helper 的同一 task 内同步迁移到 `docs/versions/` 模型，避免多个 task 反复改同一 fixture。

### 3.2 架构边界

- 只改本仓库内的 skill、模板、helper、hook、tests、fixtures、README、TESTING、CONSTITUTION.default.md、plugin/marketplace 元数据与 `dist/sdd-local/` 生成产物。
- 不实现自动迁移旧 `docs/vX.Y.Z/` 目录的命令。
- 不实现 `/sdd:archive --repair-index`，不实现 partial-state 自动回滚。
- 不引入全局关系图、决策索引或跨版本引用数据库。

### 3.3 模块影响

- `scripts/lib/sdd-common.sh`：新增 `sdd_state_field`、`sdd_locator_valid`，并把 `sdd_active_version_dir` 重写为 state.json 扫描。
- `scripts/lib/sdd-references.sh`（新文件）：`## 文档引用` 表解析、relation enum、source-parent 相对 link 解析与安全 normalize、external/anchor/non-md skip、version/project locator、link/locator identity、source/target 文档分类、direction matrix blocking/warning、plan 强关系 blocking、说明过短 warning、正文关键词启发式 warning、archive summary 机械提取；入口全部可由 Bash tests 调用，内部可用 `python3` 做严谨解析。
- `scripts/hooks/pre-tool-use.sh`：路径匹配从 `docs/v*/...` 改为 `docs/versions/v*/...`，archive 保护改为「不允许直接写 ARCHIVE.md/INDEX.md 之外的手工归档路径」按 spec 调整。
- `skills/*/SKILL.md` × 12 + `skills/*/references/*.tmpl` × 5：路径模型、`## 文档引用`、状态模型、archive 状态文件流程；`/sdd:archive` 与 `/sdd:doctor` 引用校验步骤调用 `scripts/lib/sdd-references.sh`。
- `tests/*.sh` × 9 + `tests/fixtures/*.sh` × 2：契约与夹具迁移，含新增 `tests/test-reference-validation.sh`。
- `README.md`、`TESTING.md`、`CONSTITUTION.default.md`：用户文档与宪法。
- `.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`scripts/package-local.sh`、`dist/sdd-local/**`：版本与打包。

### 3.4 数据流 / 控制流

active version 发现控制流（所有主流程 skill 与 hook 共用）：

```text
scan docs/versions/v*/state.json
  -> parse version + state per file
  -> require dir basename == state.json.version
  -> count state==active
      0  -> stop, suggest /sdd:new vX.Y.Z (research 除外)
      1  -> use it
      >1 -> stop, suggest /sdd:doctor
  -> any missing/unparseable/mismatch/illegal-state -> stop, suggest /sdd:doctor
```

引用检查数据流（`/sdd:archive` 前置 + `/sdd:doctor` 轻量版）：

```text
read ## 文档引用 table of prd/spec/plan/dr
  -> parse rows (关系,当前范围,目标文档,目标标识,说明)
  -> blocking: link target exists / relation in enum / locator format / link==locator target / cross-version has locator / project has project: locator / plan no modifies|replaces|deprecates
  -> warning: matrix-external weak reference / spec references plan / same-version extra locator / short 说明
```

## 4. 测试策略

- 每个改动用 Bash 契约测试证明：先加断言看 FAIL，再改实现看 PASS。
- helper 行为用真实临时项目夹具（`mktemp -d` + `tests/fixtures/*.sh`）驱动，断言 `sdd_active_version_dir` 返回 `docs/versions/vX.Y.Z`，并断言 0/多 active 与损坏 state 的失败信息。
- hook 行为用夹具驱动，断言新 `docs/versions/...` 路径门控与错误码 2。
- skill/模板/README/CONSTITUTION 用 `assert_contains` 断言关键契约字符串存在，用负向 `grep` 断言旧 `docs/vX.Y.Z/`（非 `docs/versions/`）不再作为当前推荐路径出现在指定文件。
- 打包用 `tests/test-package-local.sh` 断言新版本号产物与包内一致性。
- 聚合验证跑全部测试脚本，期望全部 PASS。
- 关键边界：0 active version、多 active version、损坏 state.json、缺 locator、plan 使用禁用关系、INDEX 链接具体文档。

## 5. 风险与约束

- 风险：`sdd_active_version_dir` 是既有多个测试和 hook 的依赖点，签名/返回值改变会波及 `test-common-library.sh`、`test-pre-tool-use.sh`。缓解：在同一 task（Task 1）内同时改 helper、fixtures 与 helper 测试，保证该 task 自洽可测。
- 风险：hook 的 archive 分支旧逻辑禁止直接写 `docs/archive/**`，新模型下 `/sdd:archive` 需写 `docs/archive/INDEX.md`。缓解：Task 4（hook）明确放行 `docs/archive/INDEX.md` 与 `docs/versions/v*/ARCHIVE.md`。
- 约束：不得触碰用户 dirty changes（旧 archive spec 删除、`docs/others/`、目标 spec）。每个 commit 精确 `git add`。
- 约束：Bash 3.2（macOS）兼容，避免 `declare -A` 之外的新特性；沿用现有 `shopt -s nullglob` 风格。
- 设计决策（引用校验的机械实现范围）：spec §7-§14/§16.4 定义的引用校验作为可执行 Bash 接口落地在 `scripts/lib/sdd-references.sh`（Task 2），由 `tests/test-reference-validation.sh` 用真实临时文档夹具直接驱动，覆盖五列表解析与精确空行、relation enum、source-parent 相对 `.md` link 解析与安全 normalize、external/anchor/non-md skip、version/project locator、link/locator identity、source/target 文档分类、direction matrix blocking/warning、plan 强关系 blocking、说明过短 warning、正文关键词启发式 warning、archive summary 机械提取，诊断输出含 source/original/resolved/reason。`/sdd:archive`（Task 10）与 `/sdd:doctor`（Task 9）的 SKILL.md 引用校验步骤调用该 helper 入口，因此引用校验既有 agent 可读的 prose，也有可信的机械实现和 contract test，而不再只是静态 `assert_contains` 文案断言。残余边界：本 plan 不实现自动修复失效链接、不实现全局关系图或跨版本引用数据库（spec §3 non-goals）。

## 6. Implementation Tasks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

### Task 1: Migrate helper library and fixtures to the `docs/versions/` + state.json model

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-common.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/fixtures/valid-project.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/fixtures/invalid-project.sh`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-common-library.sh`

**Interfaces:**
- Inputs:
  - `sdd_active_version_dir <project-root>` reads `<root>/docs/versions/v*/state.json`.
  - New helper `sdd_state_field <state.json-path> <field>` prints one of `version|state|created_at|archived_at`.
- Outputs:
  - `sdd_active_version_dir` prints `docs/versions/vX.Y.Z` on stdout for exactly one active version; exits 2 with a Chinese message otherwise.
- Produces for later tasks:
  - `sdd_active_version_dir` returning `docs/versions/<version>` (consumed by Task 4 hook and referenced by all skills).
  - `sdd_state_field` (consumed by Task 4 hook, Task 9 doctor tests).
  - Fixtures creating `docs/versions/v0.1.0/state.json` with `state: active` (consumed by Task 2 reference validator, Task 4 hook, Task 9 doctor).

**Acceptance Mapping:**
- Covers: spec 6 (Version State Model), spec 18 AC 42, AC 62; spec 16.2/16.3 active discovery.

- [ ] **Step 1: Write the failing test**

Replace the body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-common-library.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash tests/fixtures/valid-project.sh "$tmp/valid"

status="$(sdd_read_status "$tmp/valid/docs/versions/v0.1.0/specs/spec.md")"
[[ "$status" == "approved" ]] || fail "expected approved status, got $status"

active="$(sdd_active_version_dir "$tmp/valid")"
[[ "$active" == "docs/versions/v0.1.0" ]] || fail "expected docs/versions/v0.1.0, got $active"

state="$(sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" state)"
[[ "$state" == "active" ]] || fail "expected active state, got $state"

version="$(sdd_state_field "$tmp/valid/docs/versions/v0.1.0/state.json" version)"
[[ "$version" == "v0.1.0" ]] || fail "expected v0.1.0, got $version"

number="$(sdd_next_plan_number "$tmp/valid/docs/versions/v0.1.0/plans")"
[[ "$number" == "002" ]] || fail "expected next plan 002, got $number"

dr_number="$(sdd_next_dr_number "$tmp/valid/docs/versions/v0.1.0/decisions")"
[[ "$dr_number" == "0002" ]] || fail "expected next DR 0002, got $dr_number"

slug="$(sdd_slug 'Login Null Error!')"
[[ "$slug" == "login-null-error" ]] || fail "expected login-null-error, got $slug"

sdd_locator_valid "v0.3.0:specs/archive.md" || fail "expected version locator to be valid"
sdd_locator_valid "project:requirements/business-rules.md" || fail "expected project locator to be valid"
sdd_locator_valid "-" || fail "expected dash locator to be valid"
if sdd_locator_valid "specs/archive.md"; then fail "expected bare relative path to be an invalid locator"; fi
if sdd_locator_valid "project:notes.txt"; then fail "expected non-requirements project locator to be invalid"; fi

target="$(printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/prd.md"}}' | sdd_json_target_path)"
[[ "$target" == "docs/versions/v0.1.0/prd.md" ]] || fail "expected file_path target, got $target"

bash tests/fixtures/invalid-project.sh "$tmp/invalid"
if sdd_active_version_dir "$tmp/invalid" >/tmp/sdd-invalid.out 2>/tmp/sdd-invalid.err; then
  fail "expected multiple active versions to fail"
fi
assert_contains "/tmp/sdd-invalid.err" "发现多个 active version"

bash tests/fixtures/valid-project.sh "$tmp/zero"
printf '{\n  "version": "v0.1.0",\n  "state": "archived",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": "2026-07-14T12:00:00Z"\n}\n' > "$tmp/zero/docs/versions/v0.1.0/state.json"
if sdd_active_version_dir "$tmp/zero" >/tmp/sdd-zero.out 2>/tmp/sdd-zero.err; then
  fail "expected zero active versions to fail"
fi
assert_contains "/tmp/sdd-zero.err" "未发现 active version"
assert_contains "/tmp/sdd-zero.err" "/sdd:new"

printf 'PASS: common library\n'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-common-library.sh`
Expected: FAIL — `sdd_state_field` is undefined and `sdd_active_version_dir` still returns `docs/v0.1.0`; likely `fail` message `expected docs/versions/v0.1.0, got docs/v0.1.0` or a `sdd_state_field: command not found` error.

- [ ] **Step 3: Write minimal implementation**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-common.sh`, replace the `sdd_active_version_dir()` function (currently lines 38-68) with the following, and append the new `sdd_state_field` and `sdd_locator_valid` functions before the final `sdd_slug` function:

```bash
sdd_state_field() {
  local state_file="$1"
  local field="$2"
  if [[ ! -f "$state_file" ]]; then
    printf 'state 文件不存在：%s\n' "$state_file" >&2
    return 2
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
try:
    data=json.load(open(sys.argv[1]))
except Exception:
    sys.exit(3)
v=data.get(sys.argv[2])
print("" if v is None else v)' "$state_file" "$field"
  else
    sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" "$state_file" | head -n 1
  fi
}

sdd_active_version_dir() {
  local root="$1"
  local versions_dir="$root/docs/versions"
  if [[ ! -d "$versions_dir" ]]; then
    printf '未找到 docs/versions/，请先运行 /sdd:init。\n' >&2
    return 2
  fi

  local actives=()
  local path base state version
  shopt -s nullglob
  for path in "$versions_dir"/v*; do
    [[ -d "$path" ]] || continue
    base="$(basename "$path")"
    case "$base" in
      v[0-9]*.[0-9]*.[0-9]*) ;;
      *) continue ;;
    esac
    if [[ ! -f "$path/state.json" ]]; then
      printf '版本目录缺少 state.json：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    fi
    version="$(sdd_state_field "$path/state.json" version)" || {
      printf 'state.json 无法解析：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    }
    if [[ "$version" != "$base" ]]; then
      printf 'state.json.version 与目录名不一致：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
      shopt -u nullglob
      return 2
    fi
    state="$(sdd_state_field "$path/state.json" state)"
    case "$state" in
      active|archived) ;;
      *)
        printf 'state.json.state 非法：docs/versions/%s，请运行 /sdd:doctor。\n' "$base" >&2
        shopt -u nullglob
        return 2
        ;;
    esac
    if [[ "$state" == "active" ]]; then
      actives+=("docs/versions/$base")
    fi
  done
  shopt -u nullglob

  if [[ "${#actives[@]}" -eq 0 ]]; then
    printf '未发现 active version，请先运行 /sdd:new vX.Y.Z。\n' >&2
    return 2
  fi
  if [[ "${#actives[@]}" -gt 1 ]]; then
    printf '发现多个 active version：%s，请运行 /sdd:doctor。\n' "${actives[*]}" >&2
    return 2
  fi
  printf '%s\n' "${actives[0]}"
}

sdd_locator_valid() {
  local locator="$1"
  case "$locator" in
    -) return 0 ;;
    project:requirements/*.md) return 0 ;;
    v[0-9]*.[0-9]*.[0-9]*:*) return 0 ;;
    *) return 1 ;;
  esac
}
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/fixtures/valid-project.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/versions/v0.1.0/specs" "$root/docs/versions/v0.1.0/plans" "$root/docs/versions/v0.1.0/decisions" "$root/docs/archive" "$root/docs/requirements"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '# PRD\n' > "$root/docs/versions/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：approved\n' > "$root/docs/versions/v0.1.0/specs/spec.md"
printf '# Plan\n\n- 状态：planned\n' > "$root/docs/versions/v0.1.0/plans/001-feature-login.md"
printf '# DR\n\n- 状态：accepted\n- class：code\n- tag：fix\n- spec_change：no\n- plan_required：yes\n- code_required：yes\n- closed_reason: null\n' > "$root/docs/versions/v0.1.0/decisions/fix-0001-login-null.md"
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/fixtures/invalid-project.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/versions/v0.1.0/specs" "$root/docs/versions/v0.2.0/specs" "$root/docs/archive"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '{\n  "version": "v0.2.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.2.0/state.json"
printf '# Functional Specification\n\n- 状态：draft\n' > "$root/docs/versions/v0.1.0/specs/spec.md"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-common-library.sh`
Expected: `PASS: common library`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-common.sh tests/fixtures/valid-project.sh tests/fixtures/invalid-project.sh tests/test-common-library.sh
git commit -m "feat: resolve active version from versions/state.json"
```

---

### Task 2: Migrate `/sdd:init` and `/sdd:new` to the versions/state.json model

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/init/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/new/SKILL.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:init` (no argument); `/sdd:new vX.Y.Z`.
- Outputs:
  - `/sdd:init` creates `docs/requirements/`, `docs/versions/`, `docs/archive/`.
  - `/sdd:new` creates `docs/versions/vX.Y.Z/{state.json,specs/,plans/,decisions/}` with `state: active`.
- Produces for later tasks:
  - Contract strings `docs/versions/` (init) and `docs/versions/vX.Y.Z/state.json` (new), asserted here and reused by Task 8 doctor checks.

**Acceptance Mapping:**
- Covers: spec 16.1, 16.2; spec 18 AC 1-5.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, replace the two existing init assertions (`不要创建 .sdd/state.json` block, lines 10-12) and the three new assertions (lines 14-16) with:

```bash
assert_contains "skills/init/SKILL.md" "description: Initialize SDD project structure"
assert_contains "skills/init/SKILL.md" "docs/CONSTITUTION.md 已存在"
assert_contains "skills/init/SKILL.md" "docs/versions/"
assert_contains "skills/init/SKILL.md" "不创建任何版本目录或版本级 state.json"
assert_contains "skills/init/SKILL.md" "允许处于 0 active version 状态"

assert_contains "skills/new/SKILL.md" "description: Create the unique active SDD version directory"
assert_contains "skills/new/SKILL.md" "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/state.json"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/specs/"
assert_contains "skills/new/SKILL.md" '"state": "active"'
assert_contains "skills/new/SKILL.md" "扫描 docs/versions/v*/state.json"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/init/SKILL.md to contain: docs/versions/`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/init/SKILL.md` with:

```markdown
---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

Initialize the current project for SDD. Create the project-level skeleton only; do not create any version.

## Preconditions

1. Check whether `docs/CONSTITUTION.md` exists.
2. If `docs/CONSTITUTION.md` exists, stop and say: `docs/CONSTITUTION.md 已存在；已初始化，请运行 /sdd:status 查看当前状态。`

## Steps

1. Run `scripts/install-deps.sh`.
2. If dependency installation fails, stop and ask the user to run `scripts/install-deps.sh` manually.
3. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
4. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
5. Do not create `.sdd/state.json`.
6. 不创建任何版本目录或版本级 state.json。
7. Do not create `prd.md`, `specs/*.md`, `plans/*.md`, or `decisions/*.md`.
8. Do not modify `CLAUDE.md` or `AGENTS.md`.

## Output

Report created or confirmed project-level paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/versions/
docs/archive/
```

## State semantics

- 完成后项目允许处于 0 active version 状态。
- 需要 active version 的 skill 在该状态下必须提示用户运行 `/sdd:new vX.Y.Z`。
- `/sdd:init` 不接受版本号参数；第一个版本必须由用户通过 `/sdd:new vX.Y.Z` 创建。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/new/SKILL.md` with:

```markdown
---
name: new
description: Create the unique active SDD version directory. Use for /sdd:new vX.Y.Z.
---

# /sdd:new

Create a single active version directory under `docs/versions/`.

## Required argument

Version must match:

```text
^v[0-9]+\.[0-9]+\.[0-9]+$
```

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and say the structure is incomplete, run `/sdd:init` or `/sdd:doctor`.
3. Target directory `docs/versions/vX.Y.Z/` must not already exist.
4. 扫描 docs/versions/v*/state.json。
5. If one `state: active` version exists, stop and ask the user to run `/sdd:archive` first.
6. If multiple `state: active` versions exist, stop and ask the user to run `/sdd:doctor`.
7. If any version directory is missing `state.json`, has unparseable JSON, has a `version` mismatch, or an illegal `state`, stop and ask the user to run `/sdd:doctor`.
8. If 0 active version and no consistency error, allow creation.

## Steps

Create:

```text
docs/versions/vX.Y.Z/
docs/versions/vX.Y.Z/state.json
docs/versions/vX.Y.Z/specs/
docs/versions/vX.Y.Z/plans/
docs/versions/vX.Y.Z/decisions/
```

Initial `docs/versions/vX.Y.Z/state.json` content:

```json
{
  "version": "vX.Y.Z",
  "state": "active",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "archived_at": null
}
```

Do not create:

```text
docs/versions/vX.Y.Z/prd.md
docs/versions/vX.Y.Z/specs/*.md
docs/versions/vX.Y.Z/plans/*.md
docs/versions/vX.Y.Z/decisions/*.md
.sdd/state.json
```

## State semantics

- `/sdd:new` 只通过 docs/versions/v*/state.json 判断 active version，不通过目录数量判断。
- `/sdd:new` 是从 0 active version 进入 1 active version 的唯一主流程入口。
- `/sdd:new` 不修改任何已存在版本的 state.json。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL later in the file (other skills not yet migrated), but the init/new assertions now PASS. To confirm just this task's assertions in isolation, run:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/init/SKILL.md "docs/versions/" && assert_contains skills/new/SKILL.md "docs/versions/vX.Y.Z/state.json" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/init/SKILL.md skills/new/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: create versions dir and state.json in init and new"
```

---

### Task 3: Implement the mechanical reference parser, validator, and archive-summary extractor

**Files:**
- Create:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-references.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`

**Interfaces:**
- Inputs:
  - `sdd_refs_parse_table <source.md>` / CLI `parse-table <source.md>`: parse only `## 文档引用`, emit JSONL rows.
  - `sdd_refs_validate <project-root> <source.md>` / CLI `validate <project-root> <source.md>`: emit JSONL diagnostics; exit 2 iff blocking diagnostics exist.
  - `sdd_refs_extract_archive <project-root> <version-dir> <cross.md> <strong.md>` / CLI `extract-archive ...`: mechanically write cross/project and same-version-strong table bodies.
- Outputs:
  - Row fields: `source,relation,scope,target_markdown,link_text,original,locator,note,resolved,source_type,target_type`.
  - Diagnostic fields: `level,code,source,original,resolved,reason`.
  - Exact empty output rows are `| 未发现。 | - | - | - | - |` and `| 未发现。 | - | - | - |`; malformed input uses `未能机械提取；请查看原始文档。`.
- Produces for later tasks:
  - `sdd_refs_validate` consumed by Task 9 `/sdd:doctor` and Task 10 `/sdd:archive` preflight.
  - `sdd_refs_extract_archive` consumed by Task 10 `ARCHIVE.md` §6 generation.

**Acceptance Mapping:**
- Covers: spec 7-10.1, 11-14; spec 18 AC 43-49, AC 55-56, AC 65.

- [ ] **Step 1: Write the failing contract test**

Create `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
[[ -f scripts/lib/sdd-references.sh ]] || fail "missing scripts/lib/sdd-references.sh"
. scripts/lib/sdd-references.sh

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
root="$tmp/project"
mkdir -p "$root/docs/requirements" "$root/docs/versions/v0.1.0"/{specs,plans,decisions} "$root/docs/versions/v0.2.0/specs"
printf '{"version":"v0.1.0","state":"active","created_at":"2026-07-14T00:00:00Z","archived_at":null}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '{"version":"v0.2.0","state":"archived","created_at":"2026-06-01T00:00:00Z","archived_at":"2026-06-30T00:00:00Z"}\n' > "$root/docs/versions/v0.2.0/state.json"
printf '# Requirement\n' > "$root/docs/requirements/rules.md"
printf '# Old\n' > "$root/docs/versions/v0.2.0/specs/old.md"
printf '# PRD\n' > "$root/docs/versions/v0.1.0/prd.md"
cat > "$root/docs/versions/v0.1.0/specs/good.md" <<'DOC'
# Good
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| derives_from | 产品目标 | [prd.md](../prd.md) | - | 当前规格继承产品目标 |
| references | 历史规则 | [old.md](../../v0.2.0/specs/old.md) | v0.2.0:specs/old.md | 历史规格作为设计背景 |
| derives_from | 业务约束 | [rules.md](../../../requirements/rules.md) | project:requirements/rules.md | 项目规则约束当前行为 |
普通导航：[site](https://example.com)、[section](#local)、[code](../../../src/app.ts)。
DOC
scripts/lib/sdd-references.sh parse-table "$root/docs/versions/v0.1.0/specs/good.md" > "$tmp/rows"
[[ "$(wc -l < "$tmp/rows" | tr -d ' ')" == 3 ]] || fail "expected three rows"
assert_contains "$tmp/rows" '"resolved": "docs/versions/v0.1.0/prd.md"'
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/good.md" > "$tmp/good"
[[ ! -s "$tmp/good" ]] || fail "valid references emitted diagnostics"
cat > "$root/docs/versions/v0.1.0/specs/empty.md" <<'DOC'
# Empty
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
DOC
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/empty.md" > "$tmp/empty"
[[ ! -s "$tmp/empty" ]] || fail "exact empty row failed"
cat > "$root/docs/versions/v0.1.0/plans/001-bad.md" <<'DOC'
# Bad
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| changes | 非法关系 | [good.md](../specs/good.md) | - | 非法关系测试说明 |
| modifies | 实现范围 | [good.md](../specs/good.md) | - | plan 不得修改契约 |
| references | 错误历史 | [old.md](../../v0.2.0/specs/old.md) | v0.2.0:specs/other.md | 链接和 locator 不一致 |
| references | 越界路径 | [escape.md](../../../../outside.md) | - | 越过项目根目录测试 |
| references | 短说明 | [good.md](../specs/good.md) | - | 参考 |
实现依据见 [prd.md](../prd.md)。
DOC
if scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/plans/001-bad.md" > "$tmp/bad"; then fail "expected blocking failure"; fi
for code in invalid_relation plan_strong_relation locator_mismatch unsafe_path short_note body_link_not_declared; do assert_contains "$tmp/bad" "\"code\": \"$code\""; done
assert_contains "$tmp/bad" '"source": "docs/versions/v0.1.0/plans/001-bad.md"'
assert_contains "$tmp/bad" '"original": "../../v0.2.0/specs/old.md"'
assert_contains "$tmp/bad" '"resolved": "docs/versions/v0.2.0/specs/old.md"'
assert_contains "$tmp/bad" '"reason":'
cat > "$root/docs/versions/v0.1.0/prd.md" <<'DOC'
# PRD
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 实现背景 | [001-bad.md](./plans/001-bad.md) | - | PRD 对 plan 的矩阵外弱引用 |
DOC
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/prd.md" > "$tmp/matrix"
assert_contains "$tmp/matrix" '"code": "direction_matrix_weak"'
assert_contains "$tmp/matrix" '"level": "warning"'
scripts/lib/sdd-references.sh extract-archive "$root" "$root/docs/versions/v0.1.0" "$tmp/cross" "$tmp/strong"
assert_contains "$tmp/cross" 'v0.2.0:specs/old.md'
assert_contains "$tmp/cross" 'project:requirements/rules.md'
assert_contains "$tmp/strong" '| plans/001-bad.md | modifies | [good.md](../specs/good.md) | plan 不得修改契约 |'
printf 'PASS: reference validation\n'
```

The test covers the exact five-column table/empty row, enum, source-parent local resolution, external/anchor/non-md skip (valid body navigation emits no diagnostics), version/project locator identity, normalized path confinement, source/target classification and direction matrix, plan strong blocking, short note, body keyword heuristic, archive extraction, and source/original/resolved/reason diagnostics.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`
Expected: `FAIL: missing scripts/lib/sdd-references.sh`

- [ ] **Step 3: Write the mechanical implementation**

Create `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/lib/sdd-references.sh`:

```bash
#!/usr/bin/env bash
_sdd_refs_python() {
python3 - "$@" <<'PY'
import json,re,sys
from pathlib import Path
H=["关系","当前范围","目标文档","目标标识","说明"]; E=["未声明。","-","-","-","-"]
R={"references","derives_from","implements","modifies","replaces","deprecates"}; S={"modifies","replaces","deprecates"}
K=("依据","来源","派生","修改","替代","决策","实现","implements","modifies","replaces","derives_from")
L=re.compile(r"\[([^\]]+)\]\(([^)]+)\)"); V=re.compile(r"^(v\d+\.\d+\.\d+):(.+\.md)$"); P=re.compile(r"^project:(requirements/.+\.md)$")
A={"requirements":{"requirements"},"prd":{"requirements","prd","spec","dr"},"spec":{"prd","requirements","dr","spec"},"plan":{"spec","dr","plan"},"dr":{"requirements","prd","spec","plan","dr"}}
def relative(root,p):
 try:return Path(p).resolve().relative_to(Path(root).resolve()).as_posix()
 except ValueError:return str(Path(p).resolve())
def kind(p):
 p=Path(p).as_posix()
 if "docs/requirements/" in p:return "requirements"
 if p.endswith("/prd.md"):return "prd"
 if "/specs/" in p:return "spec"
 if "/plans/" in p:return "plan"
 if "/decisions/" in p:return "dr"
 if p.endswith("/ARCHIVE.md"):return "archive"
 if p.endswith("/archive/INDEX.md"):return "index"
 return "other"
def cells(line):return [x.strip() for x in line.strip()[1:-1].split("|")] if line.strip().startswith("|") and line.strip().endswith("|") else None
def table(text):
 lines=text.splitlines(); start=next((i for i,x in enumerate(lines) if x.strip()=="## 文档引用"),None)
 if start is None:raise ValueError("missing_reference_table")
 raw=[]
 for x in lines[start+1:]:
  if x.startswith("## "):break
  if x.strip().startswith("|"):raw.append(x)
  elif raw and x.strip():break
 if len(raw)<3 or cells(raw[0])!=H or len(cells(raw[1]) or [])!=5:raise ValueError("invalid_reference_header")
 rows=[cells(x) for x in raw[2:]]
 if any(x is None or len(x)!=5 for x in rows):raise ValueError("invalid_reference_row")
 if rows==[E]:rows=[]
 elif E in rows:raise ValueError("empty_row_mixed_with_data")
 return rows,(start,start+len(raw))
def resolve(root,source,original):
 raw=original.split("#",1)[0]
 if not raw or original.startswith("#") or re.match(r"^[A-Za-z][\w+.-]*://",original) or not raw.lower().endswith(".md"):return "skip",""
 p=(Path(source).resolve().parent/raw).resolve()
 try:p.relative_to(Path(root).resolve())
 except ValueError:return "unsafe",str(p)
 return "local",p
def locator(root,s):
 m=V.fullmatch(s)
 if m:return (Path(root)/"docs/versions"/m.group(1)/m.group(2)).resolve()
 m=P.fullmatch(s)
 return (Path(root)/"docs"/m.group(1)).resolve() if m else None
def parse(root,source):
 text=Path(source).read_text(encoding="utf-8"); rows,region=table(text); out=[]
 for relation,scope,target,loc,note in rows:
  m=L.fullmatch(target); original=m.group(2) if m else ""; rk,res=resolve(root,source,original) if m else ("invalid","")
  out.append(dict(source=relative(root,source),relation=relation,scope=scope,target_markdown=target,link_text=m.group(1) if m else "",original=original,locator=loc,note=note,resolved=relative(root,res) if rk=="local" else str(res or ""),resolution_kind=rk,source_type=kind(relative(root,source)),target_type=kind(relative(root,res)) if res else "other"))
 return out,text,region
def diag(level,code,source,original="",resolved="",reason=""):return dict(level=level,code=code,source=source,original=original,resolved=resolved,reason=reason)
def validate(root,source):
 sr=relative(root,source); out=[]
 try:rows,text,region=parse(root,source)
 except ValueError as e:return [diag("blocking",str(e),sr,reason="reference table must use exact five-column contract")]
 declared=set()
 for x in rows:
  rel,loc,original,res,rk=x["relation"],x["locator"],x["original"],x["resolved"],x["resolution_kind"]
  if rel not in R:out.append(diag("blocking","invalid_relation",sr,original,res,"relation outside enum"))
  if not x["link_text"]:out.append(diag("blocking","target_not_markdown_link",sr,reason="目标文档 must be Markdown link"));continue
  if rk=="unsafe":out.append(diag("blocking","unsafe_path",sr,original,res,"normalized path escapes project root"));continue
  if rk=="skip":continue
  declared.add(res); rp=(Path(root)/res).resolve()
  if not rp.is_file():out.append(diag("blocking","missing_target",sr,original,res,"local Markdown target does not exist"))
  sv=next((p for p in Path(sr).parts if re.fullmatch(r"v\d+\.\d+\.\d+",p)),None); tv=next((p for p in Path(res).parts if re.fullmatch(r"v\d+\.\d+\.\d+",p)),None)
  cross=bool(sv and tv and sv!=tv); project=res.startswith("docs/requirements/")
  if cross and not V.fullmatch(loc):out.append(diag("blocking","missing_version_locator",sr,original,res,"cross-version locator required"))
  if project and not P.fullmatch(loc):out.append(diag("blocking","missing_project_locator",sr,original,res,"project locator required"))
  if loc!="-":
   lp=locator(root,loc)
   if lp is None:out.append(diag("blocking","invalid_locator",sr,original,res,"invalid locator format"))
   elif lp!=rp:out.append(diag("blocking","locator_mismatch",sr,original,res,"link and locator differ"))
   elif not cross and not project:out.append(diag("warning","same_version_locator",sr,original,res,"same-version locator is unnecessary"))
  if x["source_type"]=="plan" and rel in S:out.append(diag("blocking","plan_strong_relation",sr,original,res,"plan cannot use strong relation"))
  if x["target_type"] not in A.get(x["source_type"],set()):
   if rel in S:out.append(diag("blocking","direction_matrix_strong",sr,original,res,"matrix-external strong relation"))
   elif rel=="references" and x["note"].strip():out.append(diag("warning","direction_matrix_weak",sr,original,res,"matrix-external weak relation"))
  compact=re.sub(r"\s+","",x["note"]); words=re.findall(r"[A-Za-z]+",x["note"])
  if compact in {"参考","相关","见上","N/A","-"} or (re.search(r"[\u4e00-\u9fff]",compact) and len(compact)<6) or (not re.search(r"[\u4e00-\u9fff]",compact) and len(words)<3):out.append(diag("warning","short_note",sr,original,res,"note too short or placeholder"))
 lines=text.splitlines(); a,b=region; body="\n".join(lines[:a]+lines[b+1:])
 for line in body.splitlines():
  if any(k in line for k in K):
   for _,original in L.findall(line):
    rk,res=resolve(root,source,original); rr=relative(root,res) if rk=="local" else ""
    if rk=="local" and rr not in declared:out.append(diag("warning","body_link_not_declared",sr,original,rr,"keyword-bearing body link absent from table"))
 return out
def files(v):
 p=Path(v); out=([p/"prd.md"] if (p/"prd.md").is_file() else [])
 for d in ("specs","plans","decisions"):out+=sorted((p/d).glob("*.md"))
 return out
def extract(root,v,cross_file,strong_file):
 cross=[];strong=[];bad=False;version=Path(v).name
 for source in files(v):
  try:rows,_,_=parse(root,source)
  except ValueError:bad=True;continue
  for x in rows:
   display=Path(x["source"]).relative_to(Path("docs/versions")/version).as_posix()
   if V.fullmatch(x["locator"]) or P.fullmatch(x["locator"]):cross.append(f'| {display} | {x["relation"]} | {x["target_markdown"]} | {x["locator"]} | {x["note"]} |')
   elif x["relation"] in S:strong.append(f'| {display} | {x["relation"]} | {x["target_markdown"]} | {x["note"]} |')
 if bad:
  cross=cross or ["| 未能机械提取；请查看原始文档。 | - | - | - | - |"]
  strong=strong or ["| 未能机械提取；请查看原始文档。 | - | - | - |"]
 Path(cross_file).write_text("\n".join(cross or ["| 未发现。 | - | - | - | - |"])+"\n",encoding="utf-8")
 Path(strong_file).write_text("\n".join(strong or ["| 未发现。 | - | - | - |"])+"\n",encoding="utf-8")
cmd=sys.argv[1]
if cmd=="parse-table":
 source=Path(sys.argv[2]).resolve(); root=next((p for p in source.parents if (p/"docs").is_dir()),Path.cwd())
 rows,_,_=parse(root,source)
 for x in rows:x.pop("resolution_kind",None);print(json.dumps(x,ensure_ascii=False,sort_keys=True))
elif cmd=="validate":
 ds=validate(Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve())
 for x in ds:print(json.dumps(x,ensure_ascii=False,sort_keys=True))
 if any(x["level"]=="blocking" for x in ds):sys.exit(2)
elif cmd=="extract-archive":extract(Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve(),sys.argv[4],sys.argv[5])
else:print("usage: sdd-references.sh parse-table|validate|extract-archive ...",file=sys.stderr);sys.exit(64)
PY
}
sdd_refs_parse_table(){ _sdd_refs_python parse-table "$1"; }
sdd_refs_validate(){ _sdd_refs_python validate "$1" "$2"; }
sdd_refs_extract_archive(){ _sdd_refs_python extract-archive "$1" "$2" "$3" "$4"; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _sdd_refs_python "$@"; fi
```

This implementation fixes all mechanics: normalized `Path.resolve()` identity, project-root confinement, source-parent base, skip semantics, canonical document classification, and table-only extraction. No algorithmic choice is deferred.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`
Expected: `PASS: reference validation`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-references.sh tests/test-reference-validation.sh
git commit -m "feat: add mechanical document reference validation"
```

---

### Task 4: Migrate the PreToolUse hook to `docs/versions/` paths and archive-output rules

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/hooks/pre-tool-use.sh`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-pre-tool-use.sh`

**Interfaces:**
- Inputs:
  - JSON on stdin `{"tool_input":{"file_path":"docs/versions/vX.Y.Z/..."}}` via `sdd_json_target_path`.
- Outputs:
  - Exit 0 when gate passes; exit 2 with a Chinese message when a precondition document is missing or not in the required state.
- Produces for later tasks:
  - Path patterns `docs/versions/v*/specs/*.md`, `docs/versions/v*/plans/[0-9][0-9][0-9]-*.md` (referenced by README Hook section in Task 11).

**Acceptance Mapping:**
- Covers: spec 4.1 (path model), spec 16 hook consistency; spec 18 AC 61.

- [ ] **Step 1: Write the failing test**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-pre-tool-use.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash tests/fixtures/valid-project.sh "$tmp"

run_hook() {
  local root="$1"
  local target="$2"
  (cd "$root" && printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$OLDPWD/scripts/hooks/pre-tool-use.sh")
}

run_hook "$tmp" "docs/versions/v0.1.0/prd.md"
run_hook "$tmp" "docs/versions/v0.1.0/specs/spec.md"
run_hook "$tmp" "docs/versions/v0.1.0/specs/document-references.md"
run_hook "$tmp" "docs/versions/v0.1.0/plans/002-feature-settings.md"
run_hook "$tmp" "docs/versions/v0.1.0/decisions/fix-0002-other.md"
run_hook "$tmp" "docs/requirements/topic-2026-07.md"
run_hook "$tmp" "src/app.ts"

rm "$tmp/docs/versions/v0.1.0/prd.md"
if run_hook "$tmp" "docs/versions/v0.1.0/specs/new-spec.md" >/tmp/sdd-hook.out 2>/tmp/sdd-hook.err; then
  fail "expected spec write without PRD to fail"
fi
assert_contains "/tmp/sdd-hook.err" "无法写入 docs/versions/v0.1.0/specs/new-spec.md"
assert_contains "/tmp/sdd-hook.err" "请先完成 /sdd:prd"

printf '# PRD\n' > "$tmp/docs/versions/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$tmp/docs/versions/v0.1.0/specs/spec.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/003-feature-settings.md" >/tmp/sdd-hook2.out 2>/tmp/sdd-hook2.err; then
  fail "expected feature plan write with draft spec to fail"
fi
assert_contains "/tmp/sdd-hook2.err" "前置文档 docs/versions/v0.1.0/specs/spec.md 状态为 draft，期望 approved"

printf '# DR\n\n- 状态：drafting\n- class：code\n- tag：chg\n- spec_change：yes\n- plan_required：yes\n- code_required：yes\n' > "$tmp/docs/versions/v0.1.0/decisions/chg-0002-policy.md"
if run_hook "$tmp" "docs/versions/v0.1.0/plans/004-chg-0002-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/versions/v0.1.0/decisions/chg-0002-policy.md 状态为 drafting，期望 accepted"

run_hook "$tmp" "docs/archive/INDEX.md"
run_hook "$tmp" "docs/versions/v0.1.0/ARCHIVE.md"

printf 'PASS: pre-tool-use hook\n'
```

Note: the feature-plan gate now applies to any `docs/versions/v*/specs/spec.md`-backed plan named `NNN-feature-*`. The test writes `002-feature-settings.md` which requires `specs/spec.md` at `approved` (the fixture sets it approved), so it passes; the later draft case uses `003-feature-settings.md` after downgrading spec to draft.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-pre-tool-use.sh`
Expected: FAIL — the hook still matches `docs/v*/...`, so `docs/versions/v0.1.0/specs/spec.md` falls through to the default `*)` case; the missing-PRD assertion fails with `expected spec write without PRD to fail`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/hooks/pre-tool-use.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"
. "$root_dir/scripts/lib/sdd-common.sh"

target_path="$(sdd_json_target_path)"
[[ -n "$target_path" ]] || exit 0

target_path="${target_path#./}"

case "$target_path" in
  docs/versions/v*/prd.md)
    exit 0
    ;;
  docs/versions/v*/specs/*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    prd="docs/versions/$version/prd.md"
    if [[ ! -f "$prd" ]]; then
      printf '无法写入 %s：\n前置文档 %s 不存在。\n请先完成 /sdd:prd。\n' "$target_path" "$prd" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/versions/v*/plans/[0-9][0-9][0-9]-feature-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    spec="docs/versions/$version/specs/spec.md"
    status="$(sdd_read_status "$spec")" || exit 2
    if [[ "$status" != "approved" ]]; then
      printf '无法写入 %s：\n前置文档 %s 状态为 %s，期望 approved。\n请先完成 /sdd:spec 并批准 Functional Specification。\n' "$target_path" "$spec" "$status" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/versions/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/versions/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/versions/}"
    version="${version%%/*}"
    base="$(basename "$target_path" .md)"
    dr_id="${base#???-}"
    dr="docs/versions/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/versions/v*/plans/*.md|docs/versions/v*/decisions/*.md|docs/versions/v*/ARCHIVE.md|docs/versions/v*/state.json|docs/archive/INDEX.md|docs/requirements/*.md|src/*|src/**)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-pre-tool-use.sh`
Expected: `PASS: pre-tool-use hook`

- [ ] **Step 5: Commit**

```bash
git add scripts/hooks/pre-tool-use.sh tests/test-pre-tool-use.sh
git commit -m "feat: gate versions-model document writes in pre-tool-use hook"
```

---

### Task 5: Add the unified reference table to PRD, spec, plan, and DR templates

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/prd/references/prd.md.tmpl`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/spec/references/spec.md.tmpl`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/plan/references/plan.md.tmpl`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/dr/references/dr.md.tmpl`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - none (static template content).
- Outputs:
  - Each template contains a `## 文档引用` section with the 5-column header and the fixed empty-set row.
- Produces for later tasks:
  - The exact header line `| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |` and empty row `| 未声明。 | - | - | - | - |` (consumed by Task 5-7 skill rules, Task 9 archive extraction, Task 8 doctor checks).

**Acceptance Mapping:**
- Covers: spec 10.1, spec 16.6/16.7/16.8/16.9 templates; spec 18 AC 46, AC 47.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, add these assertions immediately after the existing PRD template assertions (after line 25 `## 6. 成功标准`) and update the spec template block (replace lines 31, 41-43) and plan/DR template blocks accordingly. Concretely, add:

```bash
assert_contains "skills/prd/references/prd.md.tmpl" "## 文档引用"
assert_contains "skills/prd/references/prd.md.tmpl" "| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |"
assert_contains "skills/prd/references/prd.md.tmpl" "| 未声明。 | - | - | - | - |"
assert_contains "skills/prd/references/prd.md.tmpl" "## 7. 上游需求资料"

assert_contains "skills/spec/references/spec.md.tmpl" "## 文档引用"
assert_contains "skills/spec/references/spec.md.tmpl" "| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |"
assert_contains "skills/spec/references/spec.md.tmpl" "| 未声明。 | - | - | - | - |"
assert_contains "skills/spec/references/spec.md.tmpl" "## 9. 验收标准"

assert_contains "skills/plan/references/plan.md.tmpl" "## 文档引用"
assert_contains "skills/plan/references/plan.md.tmpl" "| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |"
assert_contains "skills/plan/references/plan.md.tmpl" "| 未声明。 | - | - | - | - |"
assert_contains "skills/plan/references/plan.md.tmpl" "## 6. Implementation Tasks"
assert_contains "skills/plan/references/plan.md.tmpl" "## 7. Self-Review"

assert_contains "skills/dr/references/dr.md.tmpl" "## 文档引用"
assert_contains "skills/dr/references/dr.md.tmpl" "| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |"
assert_contains "skills/dr/references/dr.md.tmpl" "| 未声明。 | - | - | - | - |"
assert_contains "skills/dr/references/dr.md.tmpl" "## 7. 影响资产"
```

Also delete the now-obsolete spec-template assertions that reference the old `关联 DRs` table: remove lines 41-42 (`| DR | tag | class | spec_change | 状态 | 关联小节 |` and its separator) and line 60 (`- 关联 DR：null`).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/prd/references/prd.md.tmpl to contain: ## 文档引用`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/prd/references/prd.md.tmpl` with:

```markdown
# PRD：<产品/版本名>

- 版本：vX.Y.Z
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 背景

## 2. 目标用户

## 3. 问题与目标

### 3.1 问题与痛点

### 3.2 产品目标

## 4. 范围

### 4.1 In Scope

### 4.2 Out of Scope

## 5. 成功标准

## 6. 风险与假设

## 7. 上游需求资料

| 路径 | 摘要 |
| ---- | ---- |
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/spec/references/spec.md.tmpl` with:

```markdown
# Functional Specification：<名称>

- 版本：vX.Y.Z
- 状态：draft
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 功能概述

## 2. 功能范围

### 2.1 In Scope

### 2.2 Out of Scope

## 3. 约束

### 3.1 产品约束

### 3.2 技术约束

### 3.3 克制原则

## 4. 用户故事 / 使用场景

## 5. 功能行为

### 5.1 <行为或命令>

- 前置条件：
- 执行规则：
- 输出结果：
- 失败行为：

## 6. 业务规则 / 逻辑规则

## 7. 输入输出

### 7.1 输入

### 7.2 输出

## 8. 边界与异常场景

## 9. 验收标准

### Scenario 1: <场景名>

Given <前置条件>
When <用户动作或系统事件>
Then <可验证结果>
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/plan/references/plan.md.tmpl` with:

```markdown
# NNN-<work-item> Implementation Plan

- 序号：NNN
- 状态：draft
- 类型：feature | fix | feat | chg | arch
- 日期：YYYY-MM-DD

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 实施目标

## 2. 契约边界

## 3. 技术方案

### 3.1 方案概述

### 3.2 架构边界

### 3.3 模块影响

### 3.4 数据流 / 控制流

## 4. 测试策略

## 5. 风险与约束

## 6. Implementation Tasks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

### Task 1: <task name>

**Files:**
- Create:
  - `path/to/new-file`
- Modify:
  - `path/to/existing-file`
- Test:
  - `path/to/test-file`

**Interfaces:**
- Inputs:
  - `<command / function / file / state>`
- Outputs:
  - `<return value / file change / stdout / state transition>`
- Produces for later tasks:
  - `<exact function, helper, fixture, contract, or state shape>`

**Acceptance Mapping:**
- Covers: `<spec section or scenario id>`

- [ ] **Step 1: Write the failing test or contract assertion**

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write minimal implementation**

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

## 7. Self-Review

### 7.1 Spec Coverage

### 7.2 Placeholder Scan

### 7.3 Type / Naming Consistency
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/dr/references/dr.md.tmpl` with:

```markdown
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- class：code | document
- tag：fix | feat | chg | arch | spec | doc | typo
- 日期：YYYY-MM-DD
- spec_change：yes | no | maybe
- plan_required：yes | no
- code_required：yes | no
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |

## 1. 背景

## 2. 决策

## 3. 决策边界

## 4. 影响分析

### 4.1 契约影响

### 4.2 实现影响

### 4.3 文档影响

## 5. 落地要求

## 6. 验证方式

## 7. 影响资产

| 资产 | 章节 / ID |
| ---- | --------- |
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check (the full suite still fails on not-yet-migrated skills):
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && for t in prd/references/prd spec/references/spec plan/references/plan dr/references/dr; do assert_contains "skills/$t.md.tmpl" "## 文档引用"; assert_contains "skills/$t.md.tmpl" "| 未声明。 | - | - | - | - |"; done && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/prd/references/prd.md.tmpl skills/spec/references/spec.md.tmpl skills/plan/references/plan.md.tmpl skills/dr/references/dr.md.tmpl tests/test-skill-contracts.sh
git commit -m "feat: add unified document reference table to templates"
```

---

### Task 6: Rewrite `/sdd:prd` and `/sdd:research` for versions model and reference table

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/prd/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/research/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/research/references/research.md.tmpl`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:prd`; `/sdd:research <topic>`.
- Outputs:
  - `/sdd:prd` writes `docs/versions/vX.Y.Z/prd.md` with a `## 文档引用` table using `project:requirements/<file>.md` locators; `/sdd:research` writes `docs/requirements/<topic-slug>-<yyyy-mm>.md`.
- Produces for later tasks:
  - PRD reference-table rule text (consumed by Task 9 archive extraction and Task 8 doctor reference checks).

**Acceptance Mapping:**
- Covers: spec 16.6, 16.12; spec 18 AC 10, AC 11, AC 38-41.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, add after the PRD template assertions:

```bash
assert_contains "skills/prd/SKILL.md" "docs/versions/vX.Y.Z/prd.md"
assert_contains "skills/prd/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/prd/SKILL.md" "project:requirements/<file>.md"
assert_contains "skills/prd/SKILL.md" "## 文档引用"
assert_contains "skills/prd/SKILL.md" "不写 `- 状态："

assert_contains "skills/research/SKILL.md" "docs/requirements/<topic-slug>-<yyyy-mm>.md"
assert_contains "skills/research/SKILL.md" "不要求 active version"
assert_contains "skills/research/SKILL.md" "不读取或修改 state.json"
assert_contains "skills/research/references/research.md.tmpl" "# Research：<topic>"
assert_contains "skills/research/references/research.md.tmpl" "## 7. 可引用结论"
```

Remove the obsolete research template assertion at line 20 (`assert_contains "skills/research/references/research.md.tmpl" "# 研究：<topic>"`).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/prd/SKILL.md to contain: docs/versions/vX.Y.Z/prd.md`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/prd/SKILL.md` with:

```markdown
---
name: prd
description: Create the product requirements document. Use for /sdd:prd.
---

# /sdd:prd

Create or update `docs/versions/vX.Y.Z/prd.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or an inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Target file is `docs/versions/vX.Y.Z/prd.md`. If it already exists, ask whether to overwrite, update, or cancel.

## Dialogue

1. Scan `docs/requirements/*.md`.
2. Ask which requirement documents to reference.
3. For each selected requirement, write one formal row in the `## 文档引用` table:
   - `关系` usually `derives_from`.
   - `当前范围` the affected product goal, scope, or success criteria.
   - `目标文档` a relative Markdown link from `prd.md`, for example `[business-rules.md](../../requirements/business-rules.md)`.
   - `目标标识` `project:requirements/<file>.md`.
   - `说明` one sentence on how the requirement affects the PRD.
4. Clarify product background, target users, pain points, business goals, scope, success criteria, risks, assumptions.
5. If no requirement is selected, use the fixed empty-set row `| 未声明。 | - | - | - | - |`.

## Output

Write `docs/versions/vX.Y.Z/prd.md` using `skills/prd/references/prd.md.tmpl`.

- `## 文档引用` 是正式机器可检查引用关系。
- `## 上游需求资料` 是人类阅读摘要。
- 影响 PRD 契约内容的 requirement 必须同时出现在 `## 文档引用`。
- 不写 `- 状态：` 行。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 spec/plan/DR、不归档版本、不读取 git log。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/research/SKILL.md` with:

```markdown
---
name: research
description: Create project-level SDD research notes. Use for /sdd:research <topic>.
---

# /sdd:research

Create or update project-level research material under `docs/requirements/`. Not part of any version and not part of the version lifecycle.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Ensure `docs/requirements/` exists; if `docs/CONSTITUTION.md` exists but `docs/requirements/` is missing, create only `docs/requirements/`.
3. 不扫描 docs/versions/v*/state.json。
4. 不要求 active version；0 active version 时仍可运行。

## Dialogue

1. Research topic.
2. Why the topic matters.
3. Sources or local files.
4. Decision output later needed by PRD or spec.
5. If the user names a target PRD or spec, record it as a suggested later reference but do not modify the target document.

## Output path

```text
docs/requirements/<topic-slug>-<yyyy-mm>.md
```

Write using `skills/research/references/research.md.tmpl`.

- research 文档不写 `- 状态：` 行，不写 version lifecycle 字段，不要求 `## 文档引用` 表。
- 如果同名 research 文件已存在，更新同一文档或要求用户确认新 slug；不得创建 version-local 副本。

## Relationship with PRD / spec

- 不自动修改 PRD 或 spec。
- 当 PRD 或 spec 正式引用该 research 时，目标文档在 `## 文档引用` 表用相对 Markdown link、`project:requirements/<file>.md` locator 和 `derives_from` 或 `references` 关系记录。

## Boundaries

- 不创建 active version、不读取或修改 state.json、不创建或修改 PRD/spec/plan/DR、不关闭 DR、不生成 plan、不执行 code、不归档版本。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/research/references/research.md.tmpl` with:

```markdown
# Research：<topic>

- 日期：YYYY-MM-DD
- 范围：project

## 1. 背景

## 2. 调研问题

## 3. 信息来源

| 来源 | 类型 | 摘要 |
| ---- | ---- | ---- |

## 4. 关键事实

## 5. 分析与推论

## 6. 建议

## 7. 可引用结论

| 结论 | 建议引用位置 | 说明 |
| ---- | ------------ | ---- |

## 8. 限制与不确定性
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/prd/SKILL.md "docs/versions/vX.Y.Z/prd.md" && assert_contains skills/research/SKILL.md "docs/requirements/<topic-slug>-<yyyy-mm>.md" && assert_contains skills/research/references/research.md.tmpl "# Research：<topic>" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/prd/SKILL.md skills/research/SKILL.md skills/research/references/research.md.tmpl tests/test-skill-contracts.sh
git commit -m "feat: migrate prd and research skills to versions model"
```

---

### Task 7: Rewrite `/sdd:spec` and `/sdd:dr` for versions model and reference table

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/spec/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/dr/SKILL.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:spec`; `/sdd:dr <tag> <title>`, `/sdd:dr accept <id>`, `/sdd:dr dismiss <id> <reason>`.
- Outputs:
  - `/sdd:spec` writes `docs/versions/vX.Y.Z/specs/<spec-name>.md`; `/sdd:dr` writes `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md`.
- Produces for later tasks:
  - Spec `## 文档引用` rules and DR `## 文档引用`/`## 影响资产` split (consumed by Task 7 plan, Task 9 archive, Task 8 doctor).

**Acceptance Mapping:**
- Covers: spec 16.7, 16.9; spec 18 AC 12-16, AC 22-27, AC 48, AC 60.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, replace the existing spec-skill assertion block (lines 27-43) with:

```bash
assert_contains "skills/spec/SKILL.md" "description: Create or revise the functional specification"
assert_contains "skills/spec/SKILL.md" "docs/versions/vX.Y.Z/specs/<spec-name>.md"
assert_contains "skills/spec/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/spec/SKILL.md" "## 文档引用"
assert_contains "skills/spec/SKILL.md" "[prd.md](../prd.md)"
assert_contains "skills/spec/SKILL.md" "v0.2.0:specs/archive.md"
assert_contains "skills/spec/SKILL.md" '用户确认后，将状态切换为 `approved`'
assert_contains "skills/spec/SKILL.md" "closed_reason: document-updated"
assert_contains "skills/spec/SKILL.md" 'code-class DR 必须保持 `accepted`'
assert_contains "skills/spec/SKILL.md" "不再使用独立 `## 关联 DRs`"
```

In the same file, replace the DR-skill assertion block that references the old model. Specifically remove lines 105-109 (the old `影响资产`/Markdown-link `[spec.md](../specs/spec.md)` assertions) and add after line 104:

```bash
assert_contains "skills/dr/SKILL.md" "docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md"
assert_contains "skills/dr/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/dr/SKILL.md" "## 文档引用"
assert_contains "skills/dr/SKILL.md" "## 影响资产` 只做摘要"
assert_contains "skills/dr/SKILL.md" "project:requirements/<file>.md"
assert_contains "skills/dr/SKILL.md" "closed_reason: dismissed"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/spec/SKILL.md to contain: docs/versions/vX.Y.Z/specs/<spec-name>.md`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/spec/SKILL.md` with:

```markdown
---
name: spec
description: Create or revise the functional specification. Use for /sdd:spec.
---

# /sdd:spec

Create or revise a functional spec at `docs/versions/vX.Y.Z/specs/<spec-name>.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Require `docs/versions/vX.Y.Z/prd.md` to exist; if missing, stop and ask the user to run `/sdd:prd`.
7. Default target may be `specs/spec.md`; a version may hold multiple `specs/<spec-name>.md`.
8. If the target spec already exists, ask whether to overwrite, update, or cancel.

## Dialogue

1. Read the active version `prd.md`.
2. Confirm the target spec filename.
3. Clarify functional boundary, constraints, user stories, business rules, input/output, exception/edge cases, acceptance criteria, non-goals.
4. List associable accepted document-class DRs (`spec`, `doc`, `typo`).
5. List associable accepted code-class DRs (`spec_change: yes`, or `spec_change: maybe` needing a spec update).
6. Ask whether to associate one or more DRs.

## 文档引用

Write formal relationships into the unified `## 文档引用` table:

- 引用当前版本 PRD：`[prd.md](../prd.md)`，关系通常为 `derives_from`。
- 引用当前版本 DR：`[<dr-id>](../decisions/<dr-id>.md)`。
- 引用同版本其他 spec：`[<spec-name>.md](./<spec-name>.md)`。
- 引用旧版本 spec/PRD/plan/DR：必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:specs/archive.md`。
- 引用 project-level requirements：必须同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
- `## 文档引用` 是 spec 的正式引用关系来源。
- 不再使用独立 `## 关联 DRs` 作为权威关系表；如需 DR 汇总只能作为辅助阅读信息，且不得与 `## 文档引用` 冲突。

## Steps

1. Read `prd.md`.
2. Write `docs/versions/vX.Y.Z/specs/<spec-name>.md` from `skills/spec/references/spec.md.tmpl` with `- 状态：draft`.
3. Ask the user to approve or request changes.
4. 用户确认后，将状态切换为 `approved`。

## DR status handling

- 关联 document-class DR 且本次修订完成该 DR：用户确认 spec 后可关闭该 DR，设置 `closed_reason: document-updated` 并写入 `closed_at`；document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`。
- 关联 code-class DR：spec approved 后该 code-class DR 必须保持 `accepted`，不得因 spec 修订完成而关闭。
- code-class DR 下一步按 `plan_required` 输出：`plan_required: yes` → `/sdd:plan <dr-id>`；`plan_required: no` → `/sdd:code <dr-id>`。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 plan、不修改 code、不归档版本、不读取 git log。
- 如果 spec 引用 plan，按引用检查规则作为 warning 级例外，并在 `说明` 中解释原因。

## Failure behavior

If the user does not approve, keep the spec at `draft`.
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/dr/SKILL.md` with:

```markdown
---
name: dr
description: Create, accept, or dismiss SDD decision records. Use for /sdd:dr <tag> <title>, /sdd:dr accept <id>, or /sdd:dr dismiss <id> <reason>.
---

# /sdd:dr

Manage Decision Records under `docs/versions/vX.Y.Z/decisions/`.

## Tags

```text
fix | feat | chg | arch | spec | doc | typo
```

## Tag defaults

| tag | class | spec_change | plan_required | code_required |
| --- | --- | --- | --- | --- |
| fix | code | no | yes | yes |
| feat | code | yes | yes | yes |
| chg | code | yes | yes | yes |
| arch | code | maybe | yes | yes |
| spec | document | yes | no | no |
| doc | document | maybe | no | no |
| typo | document | no | no | no |

简单实现 bug 可以由用户选择轻量 fix 流程：`tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不使用轻量 fix，应保持 `plan_required: yes` 并生成新的增量 Implementation Plan。

`spec_change` 和 `plan_required` 只能在不违反 `class` 与 `code_required` 强约束的前提下调整。

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.

## Dispatch

1. If first argument is `accept`, run accept mode.
2. If first argument is `dismiss`, run dismiss mode.
3. If first argument is a valid tag, run create mode.
4. Otherwise print usage.

## Create mode

Input: `/sdd:dr <tag> <title>`

Steps:

1. Scan `docs/versions/vX.Y.Z/decisions/*.md`.
2. Generate version-local increasing DR number `NNNN`; if none, use `0001`.
3. Slugify title.
4. Write `docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
5. Derive `class`, `spec_change`, `plan_required`, `code_required` from the tag defaults table.
6. Initial status is `drafting`.
7. If the user chooses lightweight fix, set `plan_required: no` but keep `class: code` and `code_required: yes`.
8. Write the `## 文档引用` table; if no formal reference, use the fixed empty-set row `| 未声明。 | - | - | - | - |`.
   - 引用 project-level requirements：同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
   - 引用跨版本文档：同时写相对 Markdown link 和版本 locator。
   - `## 文档引用` 是 DR 的正式关系来源；`## 影响资产` 只做摘要，不作为正式关系来源。
9. Output next step:
   - code-class DR: run `/sdd:dr accept <id>`; after accept, next step depends on `plan_required` and may be `/sdd:plan <id>` or `/sdd:code <id>`. If `spec_change` is `yes` or `maybe`, first evaluate whether `/sdd:spec` is needed.
   - document-class DR: run `/sdd:dr accept <id>`, then `/sdd:spec` or the corresponding document Skill.

## Accept mode

Input: `/sdd:dr accept <id>`

Precondition: DR 状态为 drafting。

Steps:

1. Change `drafting → accepted`.
2. Do not write `closed_reason`.
3. Do not write `closed_at`.
4. Do not update supersede chain.
5. Read `class`, `spec_change`, `plan_required`, `code_required`.
6. Output next step:
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 运行 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: maybe`：说明是否需要修订 spec；如需要先 `/sdd:spec`，再按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`；如不需要直接按 `plan_required` 进入。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan` 或 `/sdd:code`。

## Dismiss mode

Input: `/sdd:dr dismiss <id> <reason>`

Precondition: DR 状态为 drafting。

Steps:

1. Change `drafting → closed`.
2. Set `closed_reason: dismissed`.
3. Set `dismissed_reason` to the provided reason.
4. Set `closed_at` to current UTC timestamp.

## Supersede rules

- accepted 或 closed DR 需要替代时，应新建 DR，并通过 `supersedes` 和 `## 文档引用` 引用被替代 DR。
- 跨版本替代不回写旧版本文档；closed DR 不重新打开；`superseded` 不作为 DR status，只能通过 `superseded_by` 或新 DR 的 `supersedes` 表达。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 spec/plan、不修改 code、不归档版本。
- `/sdd:dr accept` 不关闭 DR；`/sdd:dr dismiss` 不允许作用于 accepted 或 closed DR。
- DR 的正式关系以 `## 文档引用` 为准，`## 影响资产` 只做摘要。
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/spec/SKILL.md "docs/versions/vX.Y.Z/specs/<spec-name>.md" && assert_contains skills/dr/SKILL.md "docs/versions/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/spec/SKILL.md skills/dr/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: migrate spec and dr skills to versions model and reference table"
```

---

### Task 8: Rewrite `/sdd:plan`, `/sdd:code`, and `/sdd:triage` for versions model and reference table

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/plan/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/code/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/triage/SKILL.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:plan <work-item>`; `/sdd:code <work-item>`; `/sdd:triage [--deep]`.
- Outputs:
  - Plan at `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`; code executes plan/lightweight-fix DR; triage read-only classification with a `reference issue` category.
- Produces for later tasks:
  - Plan quality rules and `implements` relation usage (consumed by Task 9 archive summary, Task 8 doctor, Task 10 aggregate).

**Acceptance Mapping:**
- Covers: spec 16.8, 16.10, 16.11; spec 18 AC 17-21, AC 28-37, AC 49.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, add after the plan-skill assertion block (after line 61):

```bash
assert_contains "skills/plan/SKILL.md" "docs/versions/vX.Y.Z/plans/NNN-<slug>.md"
assert_contains "skills/plan/SKILL.md" "docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md"
assert_contains "skills/plan/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/plan/SKILL.md" "## 文档引用"
assert_contains "skills/plan/SKILL.md" "plan 引用 spec 时，关系应为 `implements`"
assert_contains "skills/plan/SKILL.md" "不得使用 `modifies`、`replaces`、`deprecates`"
assert_contains "skills/plan/SKILL.md" "Self-Review"

assert_contains "skills/code/SKILL.md" "docs/versions/vX.Y.Z/plans/NNN-*.md"
assert_contains "skills/code/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/code/SKILL.md" "基于 `## 文档引用` 验证 plan"

assert_contains "skills/triage/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/triage/SKILL.md" "reference issue"
assert_contains "skills/triage/SKILL.md" "关联 DRs`"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/plan/SKILL.md to contain: docs/versions/vX.Y.Z/plans/NNN-<slug>.md`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/plan/SKILL.md` with:

```markdown
---
name: plan
description: Create an implementation plan from approved spec or accepted code-class DR. Use for /sdd:plan <work-item>.
---

# /sdd:plan

Generate a new incremental Implementation Plan under `docs/versions/vX.Y.Z/plans/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Parse `<work-item>` by syntax, not by semantic guessing.

## Mode detection

1. If `<work-item>` matches `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. Otherwise use spec mode.

## Plan number allocation

1. Inspect `docs/versions/vX.Y.Z/plans/[0-9][0-9][0-9]-*.md`.
2. Extract numeric prefixes.
3. Use the next zero-padded 3-digit number after the current maximum; if no plan exists, use `001`.
4. Do not ask the user to choose `NNN`, and do not reuse an existing number.

## Spec mode

- `<work-item>` may be a spec filename, `specs/<spec-name>.md`, or a feature name resolving uniquely to one approved spec.
- Require the target spec to be `approved`; if no approved spec, stop and ask the user to run `/sdd:spec` and approve.
- Output path: `docs/versions/vX.Y.Z/plans/NNN-<slug>.md`.

## Code-class DR mode

- Read `docs/versions/vX.Y.Z/decisions/<dr-id>.md`.
- Require `状态：accepted`, `class: code`, `plan_required: yes`, `code_required: yes`.
- If `plan_required: no`, refuse and tell the user to run `/sdd:code <dr-id>`.
- Output path: `docs/versions/vX.Y.Z/plans/NNN-<dr-id>.md`.

## Technical Planning Dialogue

1. Read the relevant approved spec.
2. Read the DR when in code-class DR mode.
3. Explore current code structure.
4. Identify affected modules and file areas.
5. Present 2-3 approaches.
6. Recommend one with tradeoffs.
7. Confirm architecture boundaries, data/control flow, file impact, testing strategy, risks, constraints.
8. If concrete files, test commands, implementation steps, or acceptance mapping cannot be written, continue the dialogue; do not emit a placeholder plan.
9. Only after user confirmation, generate the plan.

## Plan quality rules

- Use `skills/plan/references/plan.md.tmpl`.
- `Implementation Tasks` 必须是可由 agentic worker 直接执行的 TDD 手册，不是概要 TODO。
- 每个 task 必须包含精确 `Files`、`Interfaces`、`Acceptance Mapping` 和 checkbox steps。
- 测试步骤包含实际测试代码或 contract assertion、运行命令和 expected FAIL/PASS 输出。
- 实现步骤包含足够具体的代码、替换片段、文件内容或修改说明。
- commit 步骤包含具体 `git add` 路径和 `git commit -m` 信息。
- 最终 plan 不得保留占位符（`TBD`、`TODO`、`待定`、`待补充`、`path/to/file` 等）。
- 写出 plan 前必须执行自检：spec coverage、placeholder scan、type/naming consistency，记录在 `## 7. Self-Review`。

## 文档引用

- plan 引用 spec 时，关系应为 `implements`。
- plan 引用 code-class DR 时，关系应为 `implements`。
- plan 引用其他 plan、历史 plan 或历史 DR 作为背景时，关系可为 `references`。
- 引用旧版本 plan 或旧版本 DR 时，必须同时写相对 Markdown link 和版本 locator。
- plan 不得使用 `modifies`、`replaces`、`deprecates`。
- 如果发现需要改变功能契约，停止当前 plan 生成流程，先创建或修订 DR / spec。

## Status flow

- Initial `- 状态：draft`.
- After user approval, `- 状态：planned`.
- 不把任何 DR 改为 closed；不改变 code-class DR 状态（保持 accepted）。

## Boundaries

- 不创建 active version、不修改 state.json、不修改 spec、不修改 DR 状态、不修改 code、不归档版本、不重开 closed DR、不改写 done plan。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/code/SKILL.md` with:

```markdown
---
name: code
description: Execute an SDD implementation plan or eligible lightweight fix DR. Use for /sdd:code.
---

# /sdd:code

Execute an existing Implementation Plan, or execute an accepted lightweight fix DR when `plan_required: no` and `code_required: yes`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Resolve the input through Work item lookup, then use exactly one execution mode.

## Work item lookup

1. If input is `NNN`, match `docs/versions/vX.Y.Z/plans/NNN-*.md` and use plan execution mode.
2. If input is a complete plan basename, match the same `.md` basename and use plan execution mode.
3. If input is a feature name, match by plan suffix and use plan execution mode.
4. If input matches a code-class DR id `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, first check for a matching plan by suffix. If no plan matches, read `docs/versions/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when DR `tag` is `fix` and `plan_required: no`.
5. If zero plans match and no eligible lightweight fix DR matches, stop and ask the user to run `/sdd:plan <work-item>` or confirm a lightweight fix DR.
6. If multiple plans match, stop and ask the user to use the plan number, for example `/sdd:code 002`.

## Plan execution mode

- plan 状态必须是 `planned` 或 `coding`。
- 基于 `## 文档引用` 验证 plan `implements` 的 approved spec 或 accepted code-class DR。
- spec mode plan 必须 `implements` 一个 approved spec。
- code-class DR mode plan 必须 `implements` 一个 accepted code-class DR（`accepted`、`class: code`、`plan_required: yes`、`code_required: yes`）。
- document-class DR 不允许进入 `/sdd:code`。

Steps:

1. Change plan 状态从 `planned` 切换为 `coding`; if already `coding`, keep it.
2. Ask the user to choose execution mode:
   - 高质量模式：`superpowers:subagent-driven-development`
   - 快速模式：`superpowers:executing-plans`
3. Execute the plan.
4. Run `superpowers:verification-before-completion`.
5. When execution succeeds and verification 通过后，将 plan 状态切换为 `done`.
6. If the plan implements an accepted code-class DR, change that DR from `accepted` to `closed`.
7. Set DR `closed_reason: committed`.
8. Set DR `closed_at` to current UTC timestamp.
9. If the DR has `supersedes`, update superseded DR files with `superseded_by`.

Failure behavior:

```text
plan remains coding
associated DR remains accepted
```

## Lightweight fix DR mode

Preconditions:

```text
DR 状态为 accepted
DR `class` is `code`
DR `tag` is `fix`
DR `spec_change: no`
DR `plan_required: no`
DR `code_required: yes`
```

Steps:

1. Execute the local code fix with the chosen Superpowers sub-skill.
2. Run `superpowers:verification-before-completion`.
3. When execution succeeds and verification passes, change the DR from `accepted` to `closed`.
4. Set DR `closed_reason: committed`.
5. Set DR `closed_at` to current UTC timestamp.
6. Because no plan exists, no plan status is changed.

Failure behavior:

```text
DR remains accepted
no plan status is changed
```

## Boundaries

- 不创建 active version、不修改 state.json、不创建或修订 PRD/spec/plan/DR 设计正文、不修复 `## 文档引用` 表、不接受或 dismiss DR、不处理 document-class DR、不归档版本。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/triage/SKILL.md` with:

```markdown
---
name: triage
description: Triage user questions after implementation, review, or testing. Use for /sdd:triage and /sdd:triage --deep.
---

# /sdd:triage

Reference-aware read-only triage before choosing whether to create a DR, revise spec, revise plan, change code, fix references, or explain existing behavior.

## Scope

`/sdd:triage` recommends a path and waits for the user to choose. It does not execute the chosen path.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Only when exactly one legal `state: active` version exists, read documents inside the version.

## Hard rules

- 不创建 DR。
- 不接受 DR。
- 不关闭 DR。
- 不修改 spec。
- 不修改 plan。
- 不修改 code。
- 不改变 plan 状态。
- 不替用户选择后续路径。
- 必须向用户说明推荐路径和可选路径。
- 必须等待用户确认后，才能建议进入其他 skill。
- 不把 `## 影响资产` 当成正式关系来源。

## Token control

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `specs/*.md`。
- 不得默认读取所有 `plans/*.md`。
- 不得默认读取所有 `decisions/*.md`。
- 不得默认读取所有 archived versions。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。

## Reference-aware read order

1. Understand the question; ask for a locator if needed.
2. Read minimal active-version structure (prd existence, `specs/*.md`, `plans/*.md`, `decisions/*.md` filenames).
3. If the user points to a spec, read the relevant section and that file's `## 文档引用` table.
4. If the user points to a plan, read its status, relevant tasks, and `## 文档引用` table.
5. If the user points to a DR, read its process fields, status, `## 文档引用` table, and needed body sections.
6. Follow `## 文档引用` only to directly relevant target documents.
7. Use `project:requirements/<file>.md` locator for project-level requirements.
8. For cross-version references, read only the specific referenced version document.
9. Read code only when comparing implementation against spec/plan/DR.
10. If evidence is insufficient, output a low-confidence triage and state the missing locator or context.

## Depth

```text
/sdd:triage
/sdd:triage --deep
```

`--deep` may read more relevant plan, DR, or code context, but still only after narrowing the candidate range.

## Classification

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 或 accepted code-class DR 基本明确，但 plan 拆解、策略、边界或验收有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `reference issue` | `## 文档引用` 缺失、错误、关系不当、locator 不完整，或仍依赖旧的 `关联 DRs` / `影响资产` 表达正式关系。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

## Output format

```text
我的判断：这是 <分类>。
置信度：low | medium | high
已读取依据：
- <spec 小节或文件，如有>
- <plan 文件，如有>
- <DR 文件，如有>
- <文档引用表或 locator，如有>
- <代码文件，如有>
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

## Recommended paths

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且满足轻量 fix 条件 | `/sdd:dr fix <title>`（lightweight）→ accept → `/sdd:code <id>` |
| B | 代码实现问题，但需要 plan | `/sdd:dr fix <title>` → accept → `/sdd:plan <id>` → `/sdd:code <plan>` |
| C | plan 问题 | `/sdd:dr fix <title>` → accept → 新增 incremental plan → `/sdd:code <plan>` |
| D | spec 缺失或歧义 | `/sdd:dr spec <title>` 或 spec-changing code DR → `/sdd:spec` → 后续按 DR class |
| E | 新需求或行为变更 | `/sdd:dr feat|chg <title>` → `/sdd:spec` → `/sdd:plan <id>` → `/sdd:code <plan>` |
| F | 当前行为符合设计 | explain only，不创建 DR |
| G | 引用关系缺失或错误 | document-class `doc` 或 `spec` DR → `/sdd:spec` 或对应文档修订，不进入 `/sdd:plan` 或 `/sdd:code` |

## Boundaries

- 不创建 active version、不修改 state.json、不创建/接受/关闭 DR、不修改 spec/plan/DR/PRD/requirements/code、不生成 plan、不执行 code、不修复引用表、不运行 archive。
- 不在 0 active、多 active 或 state 损坏时继续分析版本内流程。
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/plan/SKILL.md "docs/versions/vX.Y.Z/plans/NNN-<slug>.md" && assert_contains skills/code/SKILL.md "docs/versions/vX.Y.Z/plans/NNN-*.md" && assert_contains skills/triage/SKILL.md "reference issue" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md skills/code/SKILL.md skills/triage/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: migrate plan code triage skills to versions model"
```

---

### Task 9: Rewrite `/sdd:status` and `/sdd:doctor` for state model and reference checks

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/status/SKILL.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/doctor/SKILL.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:status`; `/sdd:doctor`.
  - `/sdd:doctor` consumes `sdd_refs_validate <project-root> <source.md>` from Task 3 for each active-version PRD/spec/plan/DR; it reports the helper's JSONL `blocking` diagnostics as `ERROR` and `warning` diagnostics as `WARNING` without modifying files.
- Outputs:
  - `/sdd:status` reports 0/1/multiple active version; `/sdd:doctor` runs 7 check groups including reference tables and old-draft-structure detection.
- Produces for later tasks:
  - Doctor plugin-installation check list including `skills/triage/SKILL.md`, `skills/research/SKILL.md`, `scripts/hooks/session-start.sh`, `scripts/lib/sdd-common.sh` (consumed by Task 10 aggregate).

**Acceptance Mapping:**
- Covers: spec 16.3, 16.4; spec 18 AC 6-9, AC 64.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, locate the status/doctor assertion block by its content (the two `assert_contains "skills/status/SKILL.md" ...` lines through the `assert_contains "skills/doctor/SKILL.md" "done 的代码类 DR plan 对应 DR 是否仍 accepted"` line) and replace exactly that status+doctor block with the following. Do not touch the `skills/archive/SKILL.md` assertions that follow it; those are handled in Task 9. Line numbers are omitted deliberately because Tasks 2, 4, 5, 6, 7 above have already shifted this file.

```bash
assert_contains "skills/status/SKILL.md" "description: Show current SDD version status and next-step guidance"
assert_contains "skills/status/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/status/SKILL.md" "Active version：未发现"
assert_contains "skills/status/SKILL.md" "/sdd:new vX.Y.Z"
assert_contains "skills/status/SKILL.md" "发现多个 active version"

assert_contains "skills/doctor/SKILL.md" "description: Diagnose SDD plugin installation and project consistency"
assert_contains "skills/doctor/SKILL.md" 'At execution start, read `docs/CONSTITUTION.md`.'
assert_contains "skills/doctor/SKILL.md" "skills/triage/SKILL.md"
assert_contains "skills/doctor/SKILL.md" "skills/research/SKILL.md"
assert_contains "skills/doctor/SKILL.md" "scripts/lib/sdd-common.sh"
assert_contains "skills/doctor/SKILL.md" "scripts/hooks/pre-tool-use.sh"
assert_contains "skills/doctor/SKILL.md" "docs/versions/"
assert_contains "skills/doctor/SKILL.md" "state.json.version 必须等于版本目录名"
assert_contains "skills/doctor/SKILL.md" "旧草案结构"
assert_contains "skills/doctor/SKILL.md" "docs/vX.Y.Z/"
assert_contains "skills/doctor/SKILL.md" "## 文档引用"
assert_contains "skills/doctor/SKILL.md" "docs/archive/INDEX.md"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/status/SKILL.md to contain: 扫描 docs/versions/v*/state.json`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/status/SKILL.md` with:

```markdown
---
name: status
description: Show current SDD version status and next-step guidance. Use for /sdd:status.
---

# /sdd:status

展示 SDD 项目当前生命周期状态、active version 内容概览和下一步建议。轻量状态查看入口，不是诊断或修复工具。

## Steps

1. Read `docs/CONSTITUTION.md`; if missing, report the project is not initialized, suggest `/sdd:init`, then stop.
2. Check `docs/versions/` exists; if missing, report incomplete structure, suggest `/sdd:init` or `/sdd:doctor`, then stop.
3. 扫描 docs/versions/v*/state.json。
4. If any version directory is missing `state.json`, has unparseable JSON, a `version` mismatch, or an illegal `state`, report a consistency error, suggest `/sdd:doctor`, then stop.
5. If 0 active version:
   - 输出项目已初始化。
   - 输出 `Active version：未发现`。
   - If archived versions exist, list their version and `archived_at`.
   - 下一步建议：`/sdd:new vX.Y.Z`。
   - 不扫描 `prd.md`、`specs/`、`plans/`、`decisions/`。
6. If 1 active version:
   - 输出 active version 路径，例如 `docs/versions/v0.3.0/`。
   - 输出 version state：`active`。
   - Check `prd.md` existence.
   - Scan `specs/*.md`, list each spec file and its Markdown 头部状态。
   - Scan `plans/*.md`, list each plan file and status.
   - Scan `decisions/*.md`, group by `drafting`, `accepted`, `closed`; for `closed` show `closed_reason` / `superseded_by` if present.
   - 输出下一步建议。
7. If multiple active versions:
   - 输出一致性错误，列出所有 active version。
   - 下一步建议：`/sdd:doctor`。

## Boundaries

- 不修复 state.json、不创建版本、不归档版本、不检查 Markdown links、不检查引用表语义、不诊断源码、不读取 git log。
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/doctor/SKILL.md` with:

```markdown
---
name: doctor
description: Diagnose SDD plugin installation and project consistency. Use for /sdd:doctor.
---

# /sdd:doctor

Read-only diagnostic for plugin installation integrity, project structure, version lifecycle, base document status, and reference structure. Does not auto-fix.

## Startup constraint

At execution start, read `docs/CONSTITUTION.md`.
If `docs/CONSTITUTION.md` is missing, report the SDD project is not initialized and suggest running `/sdd:init`. This does not replace the project structure check below.

## 1. Plugin installation checks

Check existence of:

```text
.claude-plugin/plugin.json
skills/init/SKILL.md
skills/new/SKILL.md
skills/research/SKILL.md
skills/prd/SKILL.md
skills/spec/SKILL.md
skills/plan/SKILL.md
skills/code/SKILL.md
skills/dr/SKILL.md
skills/triage/SKILL.md
skills/status/SKILL.md
skills/doctor/SKILL.md
skills/archive/SKILL.md
hooks/hooks.json
scripts/install-deps.sh
scripts/hooks/pre-tool-use.sh
scripts/lib/sdd-common.sh
CONSTITUTION.default.md
```

Check dependency reachability:

```text
superpowers
spec-kit
```

## 2. Project structure checks

- `docs/CONSTITUTION.md`
- `docs/requirements/`
- `docs/versions/`
- `docs/archive/`
- If `docs/CONSTITUTION.md` is missing, report not initialized and suggest `/sdd:init`, but still list other missing items.

## 3. Old draft structure check

- Scan `docs/vX.Y.Z/`.
- If found, report as 旧草案结构 (warning only), not part of the current model; do not auto-migrate; does not block `/sdd:new`.

## 4. Version state checks

- Scan `docs/versions/v*/`.
- Each version directory must have `state.json`, parseable as JSON.
- state.json.version 必须等于版本目录名。
- `state` only `active` or `archived`.
- `created_at` must exist; `archived_at` must be `null` when active and non-empty when archived.
- 0 active version legal (report and suggest `/sdd:new vX.Y.Z`); 1 active legal; multiple active is a consistency error.

## 5. Active version documents (only when exactly 1 active version)

- Check `specs/*.md`, `plans/*.md`, `decisions/*.md` status lines exist, parse, and are legal.
- DR status only `drafting`, `accepted`, `closed`; `closed` DR should have `closed_reason`; `superseded_by` non-empty if present.

## 6. Plan / DR consistency

- accepted code-class DR with `plan_required: yes` should have a matching plan (plan filename minus `NNN-` equals DR slug).
- accepted lightweight fix DR (`tag: fix`, `class: code`, `spec_change: no`, `plan_required: no`, `code_required: yes`) needs no plan; suggest `/sdd:code <dr-id>`.
- done code-class DR whose DR is still `accepted`: report as a close reminder.

## 7. Archive index checks

- Check `docs/archive/INDEX.md` existence.
- For each `state: archived` version, the version directory should have `ARCHIVE.md`.
- `docs/archive/INDEX.md` has at most one row per archived version, linking to `../versions/vX.Y.Z/ARCHIVE.md`.
- `INDEX.md` must not link to concrete spec/plan/DR/requirements.

## 8. Reference tables (lightweight)

- For existing PRD, spec, plan, DR in the active version:
  - Check the `## 文档引用` table exists.
  - Check the 5-column header `关系`, `当前范围`, `目标文档`, `目标标识`, `说明`.
  - Check relation values are in the enum.
  - Check cross-version references have version locators; project-level requirements references have `project:` locators.

## Output rules

- Group output by check range; each group reports `OK`, `WARNING`, or `ERROR`.
- Final next-step suggestions per state (not initialized → `/sdd:init`; 0 active → `/sdd:new vX.Y.Z`; multiple active/broken state → manual `state.json` fix; archive index issue → fix `docs/archive/INDEX.md`; reference table issue → fix reference tables).

## Boundaries

- 不自动创建或修改文件、不修复 state.json、不创建 active version、不归档版本、不生成 ARCHIVE.md、不更新 INDEX.md、不读取 git log、不审计源码、不机器解析 CONSTITUTION must/should、不做正文链接语义启发式扫描。
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/status/SKILL.md "Active version：未发现" && assert_contains skills/doctor/SKILL.md "旧草案结构" && assert_contains skills/doctor/SKILL.md "scripts/lib/sdd-common.sh" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/status/SKILL.md skills/doctor/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: migrate status and doctor skills to state model"
```

---

### Task 10: Rewrite `/sdd:archive` for the state-file model, ARCHIVE.md, and INDEX.md

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/archive/SKILL.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - `/sdd:archive`.
  - Consumes Task 3 `sdd_refs_validate <project-root> <source.md>` for blocking/warning preflight and `sdd_refs_extract_archive <project-root> <version-dir> <cross.md> <strong.md>` for `ARCHIVE.md` §6; diagnostic output preserves `source`, `original`, `resolved`, and `reason`.
- Outputs:
  - Generates `docs/versions/vX.Y.Z/ARCHIVE.md`, flips `state.json` to `archived` with `archived_at`, creates/updates `docs/archive/INDEX.md`; does not move directories.
- Produces for later tasks:
  - ARCHIVE.md 9-section template and INDEX.md row format (consumed by Task 11 README Hook/structure section, Task 8 doctor archive checks already reference INDEX.md).

**Acceptance Mapping:**
- Covers: spec 13, 15, 16.5; spec 18 AC 50-59, AC 63.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, locate the three original archive assertions by content (`assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"`, `... '所有 \`plans/*.md\` 状态为 \`done\`'`, and `... "docs/vX.Y.Z/ → docs/archive/vX.Y.Z/"`) and replace exactly those three lines with the block below. Line numbers are omitted because earlier tasks have already shifted this file.

```bash
assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" "不移动版本目录"
assert_contains "skills/archive/SKILL.md" "docs/versions/vX.Y.Z/ARCHIVE.md"
assert_contains "skills/archive/SKILL.md" "docs/archive/INDEX.md"
assert_contains "skills/archive/SKILL.md" '所有 `specs/*.md` 的 Markdown 头部状态必须为 `approved`'
assert_contains "skills/archive/SKILL.md" '所有 `plans/*.md` 的 Markdown 头部状态必须为 `done`'
assert_contains "skills/archive/SKILL.md" '所有 `decisions/*.md` 的 Markdown 头部状态必须为 `closed`'
assert_contains "skills/archive/SKILL.md" '"state": "archived"'
assert_contains "skills/archive/SKILL.md" "## 6. 文档引用摘要"
assert_contains "skills/archive/SKILL.md" "prd.md` 缺失不阻止归档"
assert_contains "skills/archive/SKILL.md" "只从 `## 文档引用` 表机械提取"
assert_contains "skills/archive/SKILL.md" "../versions/vX.Y.Z/ARCHIVE.md"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected skills/archive/SKILL.md to contain: 不移动版本目录`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/skills/archive/SKILL.md` with:

```markdown
---
name: archive
description: Archive the current active SDD version. Use for /sdd:archive.
---

# /sdd:archive

把唯一 active version 转为 archived 状态，生成版本归档入口，更新全局 archive index，执行归档前引用检查。归档不移动版本目录。

## Preconditions

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，提示运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，提示运行 `/sdd:init` 或 `/sdd:doctor`。
3. 恰好存在一个 `state: active` 的版本。
4. active version 目录名与 `state.json.version` 一致。
5. `state.json.state` 为 `active`，`archived_at` 为 `null`。
6. active version 的 `specs/*.md` 至少一份。
7. 所有 `specs/*.md` 的 Markdown 头部状态必须为 `approved`。
8. 所有 `plans/*.md` 的 Markdown 头部状态必须为 `done`；没有 plan 时通过。
9. 所有 `decisions/*.md` 的 Markdown 头部状态必须为 `closed`；没有 DR 时通过。
10. DR 不得使用 `dismissed` 或 `superseded` 作为状态值。
11. `prd.md` 缺失不阻止归档。
12. active version 内不存在 `ARCHIVE.md`，或用户明确允许覆盖。
13. Blocking 引用检查必须通过。

## Blocking reference checks

- 本地相对 Markdown `.md` 链接目标必须存在。
- 跨版本引用必须有版本 locator；project-level requirements 引用必须有 `project:` locator。
- locator 格式必须合法；Markdown link 和 locator 必须指向同一目标。
- 关系值必须属于枚举：`references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
- `## 文档引用` 表必须可解析。
- 矩阵外强引用（`modifies`、`replaces`、`deprecates`）属于 blocking。
- plan 使用 `modifies`、`replaces`、`deprecates` 属于 blocking。
- `ARCHIVE.md` 不得声明新引用关系；`INDEX.md` 不得声明文档引用关系或链接具体 spec/plan/DR/requirements。

## Warning reference checks

- 矩阵外弱引用（`references` 且有说明）、plan 引用 PRD 或 requirements 作为背景、spec 引用 plan、同版本引用额外写 locator、正文链接疑似证据链但未同步到 `## 文档引用`、`说明` 过短。

## Steps

1. 扫描 `docs/versions/v*/state.json`，解析唯一 active version。
2. 执行归档前置条件检查。
3. 从 active version 的 PRD、spec、plans、DR 提取归档摘要信息。
4. 从 PRD、spec、plans、DR 的 `## 文档引用` 表机械提取 `文档引用摘要`：只读取引用表，不阅读全文；提取 `目标标识` 匹配 `vX.Y.Z:` 或 `project:` 的行写入「跨版本与项目级关系」；提取关系为 `modifies`/`replaces`/`deprecates` 的同版本行写入「本版本强关系」；不根据正文链接补推关系。
5. 在 active version 目录内生成或覆盖 `docs/versions/vX.Y.Z/ARCHIVE.md`。
6. 检查生成后的 `ARCHIVE.md` 中本地相对 Markdown `.md` 链接。
7. 将该版本 `state.json.state` 从 `active` 改为 `archived`，保留 `created_at`，写入 `archived_at`。
8. 创建或更新 `docs/archive/INDEX.md`（每个 archived version 最多一行，链接 `../versions/vX.Y.Z/ARCHIVE.md`）。
9. 检查 `docs/archive/INDEX.md` 本次新增或修改的本地相对 Markdown `.md` 链接。
10. 输出归档结果：归档版本、`ARCHIVE.md` 路径、`INDEX.md` 路径、当前 0 active version、下一步建议 `/sdd:new vX.Y.Z`。

归档后的 `state.json`：

```json
{
  "version": "vX.Y.Z",
  "state": "archived",
  "created_at": "<原值>",
  "archived_at": "YYYY-MM-DDTHH:MM:SSZ"
}
```

## ARCHIVE.md template

```markdown
# Archive：vX.Y.Z

- 状态：archived
- archived_at：YYYY-MM-DDTHH:MM:SSZ
- source_version：docs/versions/vX.Y.Z
- archive_entry：docs/archive/INDEX.md

## 1. 版本摘要

## 2. 关键入口

| 类型 | 链接 | 说明 |
| ---- | ---- | ---- |
| PRD | <存在时 [prd.md](./prd.md)，否则 未发现。> | 产品目标与范围 |
| Spec | <至少一份 spec 链接> | 功能契约 |
| Plans | [plans/](./plans/) | 实施记录 |
| DRs | [decisions/](./decisions/) | 决策记录 |

## 3. Specs

| Spec | 状态 | 摘要 |
| ---- | ---- | ---- |

## 4. Plans

| Plan | 状态 | 关联来源 | 验证摘要 |
| ---- | ---- | -------- | -------- |

## 5. DRs

| DR | class | tag | 状态 | 摘要 |
| -- | ----- | --- | ---- | ---- |

## 6. 文档引用摘要

### 6.1 跨版本与项目级关系

| 来源文档 | 关系 | 目标文档 | 目标标识 | 说明 |
| -------- | ---- | -------- | -------- | ---- |
| 未发现。 | - | - | - | - |

### 6.2 本版本强关系

| 来源文档 | 关系 | 目标文档 | 说明 |
| -------- | ---- | -------- | ---- |
| 未发现。 | - | - | - |

## 7. 验证摘要

## 8. 遗留事项

## 9. 已知限制 / 风险
```

## INDEX.md template

```markdown
# SDD Archive Index

本文件是 archived versions 的全局入口。每个 archived version 最多一行，详情见对应版本的 `ARCHIVE.md`。

| 版本 | 归档时间 | 摘要 | 入口 |
| ---- | -------- | ---- | ---- |
| vX.Y.Z | YYYY-MM-DDTHH:MM:SSZ | <一句话摘要> | [ARCHIVE.md](../versions/vX.Y.Z/ARCHIVE.md) |
```

Rules:

- 只从 `## 文档引用` 表机械提取 `文档引用摘要`，不从正文链接推断新关系。
- 空集合使用固定行 `未发现。`；无法机械提取时使用 `未能机械提取；请查看原始文档。`。
- `INDEX.md` 不链接具体 spec、plan、DR 或 requirements。

## Error handling

- 前置条件失败、`ARCHIVE.md` 生成或链接检查失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `state.json` 更新失败时，归档失败，不更新 `INDEX.md`。
- `INDEX.md` 创建或更新失败时，整体归档不算成功；此时版本可能已进入 `archived`，提示用户运行 `/sdd:doctor` 或手动修复全局入口。

## Boundaries

- 不移动版本目录、不创建下一版本、不修改 spec/plan/DR 状态或正文、不修复引用表、不修复 Markdown links、不从正文链接生成正式引用关系、不读取 git log、不审计源码、不把 verification 作为归档阻塞条件。
```

- [ ] **Step 4: Run test to verify it passes**

Run this scoped check:
`bash -c 'cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && . tests/test-common.sh && assert_contains skills/archive/SKILL.md "不移动版本目录" && assert_contains skills/archive/SKILL.md "## 6. 文档引用摘要" && assert_contains skills/archive/SKILL.md "../versions/vX.Y.Z/ARCHIVE.md" && echo OK'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add skills/archive/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: rewrite archive skill as state-file model with ARCHIVE and INDEX"
```

---

### Task 11: Update CONSTITUTION.default.md and the skill-contract stale-reference guard

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/CONSTITUTION.default.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`

**Interfaces:**
- Inputs:
  - none (static content) plus a repo-wide grep guard in the contract test.
- Outputs:
  - Constitution phase gate references `docs/versions/` model; contract test asserts no skill still uses the old `docs/vX.Y.Z/` current path (excluding `docs/versions/`).
- Produces for later tasks:
  - A clean skill set for Task 11 README and Task 12 packaging.

**Acceptance Mapping:**
- Covers: spec 4.1, spec 16.5; spec 18 AC 61.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, replace the existing CONSTITUTION assertions (lines 171-176) with:

```bash
assert_contains "CONSTITUTION.default.md" 'docs/versions/vX.Y.Z/'
assert_contains "CONSTITUTION.default.md" '通过 docs/versions/v*/state.json 发现唯一 active version'
assert_contains "CONSTITUTION.default.md" '代码类 DR 默认使用 `plan_required: yes`'
assert_contains "CONSTITUTION.default.md" '文档类 DR 必须使用 `plan_required: no` 和 `code_required: no`'
assert_contains "CONSTITUTION.default.md" "代码类 DR 在 spec 修订完成后不得关闭"
assert_contains "CONSTITUTION.default.md" '轻量 fix DR 通过 `/sdd:code` verification'
assert_contains "CONSTITUTION.default.md" '/sdd:archive` 不移动版本目录'
```

Then add, just before the final `printf 'PASS: skill contracts\n'` line, a stale-path guard:

```bash
for skill in init new research prd spec plan code dr triage status doctor archive; do
  if grep -nE 'docs/v[0-9X]' "skills/$skill/SKILL.md" | grep -v 'docs/versions/' >/tmp/sdd-stale-path.out 2>/dev/null; then
    fail "skills/$skill/SKILL.md still references legacy docs/vX.Y.Z path outside docs/versions/"
  fi
done
```

Note: `/tmp/sdd-stale-path.out` is written only when a match exists; the doctor skill intentionally references `docs/vX.Y.Z/` as the legacy-draft example, so it is exempted below.

Because `/sdd:doctor` must mention `docs/vX.Y.Z/` as the old-draft example, exclude it from the loop by changing the loop list to omit `doctor`:

```bash
for skill in init new research prd spec plan code dr triage status archive; do
  if grep -nE 'docs/v[0-9X]' "skills/$skill/SKILL.md" | grep -v 'docs/versions/' >/tmp/sdd-stale-path.out 2>/dev/null; then
    fail "skills/$skill/SKILL.md still references legacy docs/vX.Y.Z path outside docs/versions/"
  fi
done
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected CONSTITUTION.default.md to contain: docs/versions/vX.Y.Z/`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/CONSTITUTION.default.md` with:

```markdown
# CONSTITUTION

> SDD Plugin 项目级流程强制约束。用户可以修改本文件；修改后，本文件即为当前项目新的流程宪法。

## 1. 阶段门控
- must: SDD 主流程必须按 `/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive` 推进。
- must: 主流程 skill 通过 docs/versions/v*/state.json 发现唯一 active version。
- must: 版本目录统一位于 `docs/versions/vX.Y.Z/`；`docs/vX.Y.Z/` 不是当前结构。
- must: `/sdd:spec` 必须在 `prd.md` 存在后执行。
- must: feature plan 必须在对应 spec 状态为 `approved` 后生成。
- must: `/sdd:code` 可以执行状态为 `planned` 或 `coding` 的 plan，也可以执行符合条件的 lightweight fix DR。

## 2. 版本状态
- must: 每个版本目录内必须有 `state.json`，字段包含 `version`、`state`、`created_at`、`archived_at`。
- must: `state` 只能是 `active` 或 `archived`。
- must: 可执行主流程状态下必须恰好存在一个 `state: active` 的版本；`/sdd:archive` 成功后允许 0 active version。
- must: 不引入集中式 `.sdd/state.json`。
- must: 不把 spec / plan / DR 工作流状态迁移到 `state.json`。

## 3. 文档状态
- must: SDD 管理的状态行只能使用 `- 状态：<value>` 格式。
- must: spec 状态只能是 `draft` 或 `approved`。
- must: plan 状态只能是 `draft`、`planned`、`coding` 或 `done`。
- must: DR 状态只能是 `drafting`、`accepted` 或 `closed`。
- should: 状态推进应由对应 SDD Skill 完成，不应手工直接改状态。

## 4. 文档引用
- must: PRD、spec、plan、DR 使用统一 `## 文档引用` 表表达正式文档关系。
- must: 关系类型只允许 `references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
- must: 同版本引用使用来源文件目录相对 Markdown link；跨版本引用必须填写版本 locator；project-level requirements 引用必须填写 `project:requirements/<file>.md` locator。
- must: plan 不得使用 `modifies`、`replaces`、`deprecates` 改变契约。
- must: 无引用时使用固定行 `| 未声明。 | - | - | - | - |`。

## 5. DR 流程
- must: 会影响代码实现的变更必须使用代码类 DR：`fix`、`feat`、`chg` 或 `arch`。
- must: 只影响文档表达且不改变系统行为的变更可以使用文档类 DR：`spec`、`doc` 或 `typo`。
- must: 代码类 DR 必须使用 `code_required: yes`；代码类 DR 默认使用 `plan_required: yes`，但简单实现 bug 的轻量 fix DR 可以使用 `plan_required: no`。
- must: 轻量 fix DR 必须是 `fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`，并只能在 `/sdd:code` verification 通过后关闭。
- must: 文档类 DR 必须使用 `plan_required: no` 和 `code_required: no`。
- must: 代码类 DR 必须先 `accepted`，才能生成对应 Implementation Plan。
- must: 代码类 DR 在 spec 修订完成后不得关闭，必须保持 `accepted`，直到关联 plan 完成并通过 verification，或轻量 fix DR 通过 `/sdd:code` verification。
- must: 代码类 DR 只有在关联 plan 完成并通过 verification 后，或轻量 fix DR 通过 `/sdd:code` verification 后，才能关闭为 `committed`。
- must: `dismissed` 和 `superseded` 不作为 DR status；`dismissed` 通过 `closed_reason: dismissed` 表达，`superseded` 通过 `superseded_by` 表达。
- may: typo 类修订可以按项目约定跳过 DR。

## 6. Plan 约束
- must: plan 是增量实施记录，文件名必须带版本内递增序号 `NNN-`。
- must: Implementation Tasks 必须达到可执行密度：精确 Files、Interfaces、Acceptance Mapping、TDD steps、命令与预期输出、commit 信息。
- must: 如果实现过程中需要改变功能契约，应通过代码类 DR 或 spec 修订表达，并创建新的增量 plan。
- must: 当前存在 `coding` plan 时，不把新功能或行为变更直接塞进正在 coding 的原 plan。

## 7. 归档
- must: `/sdd:archive` 不移动版本目录。
- must: `/sdd:archive` 归档成功时生成 `ARCHIVE.md`，将 `state.json.state` 改为 `archived` 并写入 `archived_at`，创建或更新 `docs/archive/INDEX.md`。
- must: `INDEX.md` 只链接版本 `ARCHIVE.md`，不链接具体 spec、plan、DR 或 requirements。
- must: 归档不修改 spec、plan、DR 的状态字段或正文。

## 8. Skill 身份
- must: SDD Skill 执行前必须读取本文件，并将其作为本次 Skill 的项目流程约束上下文。
- must: 若用户请求与本文件冲突，Skill 必须先指出冲突；除非用户先修改本文件，否则不直接执行冲突操作。
- must: 各 Skill 只做自己职责范围内的事情。

## 9. Subagent / Code Worker 约束
- must: subagent 或 code worker 不应自行推进 SDD 文档状态，除非当前 `/sdd:code` Skill 明确要求。
- must: code worker 必须按 plan 执行，并在完成前运行 verification。

## 10. Hook 行为
- must: MVP Hook 只守护 L1 路径 → 前置文档状态门控。
- must: Hook 失败时使用退出码 2，并输出中文错误说明。
- must: Hook 不做文档质量判断、不解析本文件 must / should、不拦截 `src/**`。

## 11. 错误处理
- must: Skill 失败时不得破坏上一稳定文档状态。
- should: 执行失败或 verification 失败时，plan 保持 `coding`，关联 DR 保持 `accepted`。

## 12. 用户修改
- may: 用户可以修改本文件以改变项目流程约束。
- should: 修改本文件后，后续 SDD Skill 应以修改后的内容为准。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: `PASS: skill contracts`

- [ ] **Step 5: Commit**

```bash
git add CONSTITUTION.default.md tests/test-skill-contracts.sh
git commit -m "feat: align constitution and stale-path guard with versions model"
```

---

### Task 12: Update README.md and TESTING.md to the versions model

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/README.md`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/TESTING.md`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-doctor-contract.sh`

**Interfaces:**
- Inputs:
  - none (user documentation).
- Outputs:
  - README documents `docs/versions/vX.Y.Z/`, `## 文档引用`, state-file archive; TESTING uses the versions paths.
- Produces for later tasks:
  - README strings asserted by both `test-skill-contracts.sh` and `test-doctor-contract.sh`.

**Acceptance Mapping:**
- Covers: spec 4.1, spec 17; spec 18 AC 61.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`, replace the README assertion block (lines 149-153 and 168-170) with:

```bash
assert_contains "README.md" "/sdd:triage"
assert_contains "README.md" "用户疑问分诊"
assert_contains "README.md" "轻量 fix DR"
assert_contains "README.md" "最终由用户选择"
assert_contains "README.md" "docs/versions/vX.Y.Z/"
assert_contains "README.md" "state.json"
assert_contains "README.md" "## 文档引用"
assert_contains "README.md" "docs/archive/INDEX.md"
assert_contains "README.md" "class / spec_change / plan_required / code_required"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh`
Expected: FAIL — `expected README.md to contain: docs/versions/vX.Y.Z/`.

- [ ] **Step 3: Write minimal implementation**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/README.md`, apply these edits:

Replace the `## 功能概览` bullet block (lines 9-21) with:

```markdown
- 初始化项目级 SDD 目录和流程宪法 `docs/CONSTITUTION.md`
- 创建唯一活跃版本目录 `docs/versions/vX.Y.Z/` 与版本级 `state.json`
- 生成项目级调研资料 `docs/requirements/*.md`
- 生成无状态 PRD：`docs/versions/vX.Y.Z/prd.md`
- 生成 Functional Specification：`docs/versions/vX.Y.Z/specs/<spec-name>.md`
- 生成 Implementation Plan：`docs/versions/vX.Y.Z/plans/NNN-*.md`
- 在 PRD、spec、plan、DR 中使用统一 `## 文档引用` 表表达证据链
- 按 plan 执行代码实现
- 创建、接受、驳回 Decision Record
- 对实现后、验收中或测试中的用户疑问执行 `/sdd:triage` 用户疑问分诊，只推荐后续路径，最终由用户选择
- 查看当前 SDD 状态
- 做插件安装和项目一致性诊断
- 以状态文件模型归档已完成版本，生成 `ARCHIVE.md` 并更新 `docs/archive/INDEX.md`
- 通过 PreToolUse Hook 做最小 L1 文档门控
```

Replace the `预期结果` block (lines 128-138) with:

```markdown
- `/sdd:init` 创建：
  - `docs/CONSTITUTION.md`
  - `docs/requirements/`
  - `docs/versions/`
  - `docs/archive/`
- `/sdd:new v0.2.0` 创建：
  - `docs/versions/v0.2.0/state.json`
  - `docs/versions/v0.2.0/specs/`
  - `docs/versions/v0.2.0/plans/`
  - `docs/versions/v0.2.0/decisions/`
- `/sdd:status` 展示当前活跃版本状态和下一步建议。
```

Add, immediately after the `## 变更流程` sentence block that mentions Markdown links (after line 183), the reference-model paragraph:

```markdown
V0.4 起，PRD、spec、plan、DR 使用统一 `## 文档引用` 表记录正式关系。关系类型只允许 `references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。同版本引用使用来源目录相对 Markdown link；跨版本引用必须额外写 `vX.Y.Z:<version-relative-path>` locator；project-level requirements 引用必须写 `project:requirements/<file>.md` locator。plan 不得使用 `modifies`、`replaces`、`deprecates`。
```

Replace the `## 文档结构` code block (lines 217-231) with:

```markdown
docs/
├── CONSTITUTION.md
├── requirements/
│   └── *.md
├── versions/
│   └── vX.Y.Z/
│       ├── state.json
│       ├── prd.md
│       ├── ARCHIVE.md          # archived 后生成
│       ├── specs/
│       │   └── <spec-name>.md
│       ├── plans/
│       │   └── NNN-*.md
│       └── decisions/
│           └── <tag>-NNNN-<slug>.md
└── archive/
    └── INDEX.md
```

Replace the `## Hook 门控` bullets (lines 235-242) with:

```markdown
- 写 `docs/versions/vX.Y.Z/specs/<spec-name>.md` 前要求 `docs/versions/vX.Y.Z/prd.md` 存在
- 写 `docs/versions/vX.Y.Z/plans/NNN-feature-*.md` 前要求对应 spec 状态为 `approved`
- 写 `docs/versions/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md` 前要求对应 DR 状态为 `accepted`
- 放行 `docs/versions/vX.Y.Z/ARCHIVE.md` 与 `docs/archive/INDEX.md`
- 不拦截 `src/**`
- 不解析 `docs/CONSTITUTION.md` 的 `must` / `should`
- 不创建 `.sdd/state.json`
```

In the `## MVP Non-Goals` block (lines 296-308), replace the line `- 不支持多个未归档活跃版本` with `- 不支持多个 active version`, and leave the rest.

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/TESTING.md`, replace all `docs/v0.1.0/` occurrences with `docs/versions/v0.1.0/` and `docs/v0.2.0` with `docs/versions/v0.2.0`, and update the section 5 fixture setup block (lines 61-63) to:

```markdown
```bash
tmp="$(mktemp -d)"
mkdir -p "$tmp/docs/versions/v0.1.0/specs" "$tmp/docs/versions/v0.1.0/plans" "$tmp/docs/versions/v0.1.0/decisions"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$tmp/docs/versions/v0.1.0/state.json"
```
```

Update the section 5 verification commands and section 6 trial block similarly so every `docs/v0.1.0/...` and `docs/v0.2.0` path becomes `docs/versions/...`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-skill-contracts.sh && bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-doctor-contract.sh`
Expected:
```text
PASS: skill contracts
PASS: skeleton contract
```

- [ ] **Step 5: Commit**

```bash
git add README.md TESTING.md tests/test-skill-contracts.sh
git commit -m "docs: update README and TESTING for versions model"
```

---

### Task 13: Bump plugin version, packaging, and package-local test; run the full suite

**Files:**
- Modify:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.claude-plugin/plugin.json`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.claude-plugin/marketplace.json`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/package-local.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-package-local.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-doctor-contract.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-mvp-acceptance.sh`
- Test:
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-reference-validation.sh`
  - `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-package-local.sh`
  - all `tests/*.sh`

**Interfaces:**
- Inputs:
  - `bash scripts/package-local.sh`.
- Outputs:
  - `dist/sdd-plugin-v0.3.0.zip` and `dist/sdd-plugin-v0.3.0.tar.gz`, plus regenerated `dist/sdd-local/**`.
- Produces for later tasks:
  - none; final task.

**Acceptance Mapping:**
- Covers: spec 17 (supporting assets, release package, dist generation); spec 18 AC 61, AC 65.

- [ ] **Step 1: Write the failing test**

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-package-local.sh`, replace lines 12-15 and 18-19 and 29 (version strings) so every `v0.2.0` becomes `v0.3.0`:

```bash
assert_file_exists "dist/sdd-plugin-v0.3.0.zip"
assert_file_exists "dist/sdd-plugin-v0.3.0.tar.gz"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v0.3.0.zip"
assert_contains "/tmp/sdd-package-local.out" "dist/sdd-plugin-v0.3.0.tar.gz"
```

and:

```bash
archive_contents="/tmp/sdd-package-local-contents.out"
tar -tzf dist/sdd-plugin-v0.3.0.tar.gz >"$archive_contents"
```

and:

```bash
tar -xzf dist/sdd-plugin-v0.3.0.tar.gz -C /tmp sdd/README.md
```

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-doctor-contract.sh`, replace line 8 with:

```bash
assert_contains ".claude-plugin/plugin.json" '"version": "0.3.0"'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-doctor-contract.sh`
Expected: FAIL — `expected .claude-plugin/plugin.json to contain: "version": "0.3.0"`.

- [ ] **Step 3: Write minimal implementation**

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.claude-plugin/plugin.json` with:

```json
{
  "name": "sdd",
  "version": "0.3.0",
  "description": "Specification Driven Development workflow plugin for Claude Code"
}
```

Replace the entire body of `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.claude-plugin/marketplace.json` with:

```json
{
  "name": "sdd-local",
  "description": "Local marketplace for SDD Plugin development",
  "metadata": {
    "description": "Local marketplace for SDD Plugin development",
    "version": "0.3.0"
  },
  "owner": {
    "name": "SDD Plugin",
    "email": "local@example.com"
  },
  "plugins": [
    {
      "name": "sdd",
      "description": "Specification Driven Development workflow plugin for Claude Code",
      "version": "0.3.0",
      "source": "./"
    }
  ]
}
```

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/scripts/package-local.sh`, update the packaged README heredoc `## 项目文档结构` block (lines 164-175) so it shows the versions model:

```text
docs/
├── CONSTITUTION.md
├── requirements/
├── versions/
│   └── vX.Y.Z/
│       ├── state.json
│       ├── prd.md
│       ├── specs/
│       ├── plans/
│       └── decisions/
└── archive/
    └── INDEX.md
```

(No other logic changes: `package-local.sh` already derives name/version from `plugin.json` and syncs marketplace metadata.)

In `/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/tests/test-mvp-acceptance.sh`, add `triage` to the skill loop (line 13) so it reads:

```bash
for skill in init new research prd spec plan code dr triage status doctor archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done
```

- [ ] **Step 4: Run test to verify it passes**

Run the full suite:

```bash
cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-reference-validation.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh && bash tests/test-package-local.sh
```

Expected:

```text
PASS: skeleton contract
PASS: common library
PASS: reference validation
PASS: pre-tool-use hook
PASS: skill contracts
PASS: MVP acceptance
PASS: local package script
```

- [ ] **Step 5: Regenerate the packaged dist tree and stage exact paths**

`scripts/package-local.sh` already regenerated `dist/sdd-plugin-v0.3.0.{zip,tar.gz}` in Step 4. To also refresh the tracked `dist/sdd-local/**` copy that mirrors the plugin, run:

```bash
cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec && rm -rf dist/sdd-local && mkdir -p dist/sdd-local && for p in .claude-plugin CONSTITUTION.default.md LICENSE README.md hooks scripts skills; do cp -R "$p" "dist/sdd-local/$p"; done
```

Verify the packaged copy carries the new model:

```bash
grep -rl "docs/versions/" /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/dist/sdd-local/skills | head
```

Expected: at least the migrated skill paths listed.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json scripts/package-local.sh tests/test-package-local.sh tests/test-doctor-contract.sh tests/test-mvp-acceptance.sh dist/sdd-local dist/sdd-plugin-v0.3.0.zip dist/sdd-plugin-v0.3.0.tar.gz
git commit -m "chore: bump plugin to v0.3.0 and regenerate local package"
```

Note: do not `git add` the old `dist/sdd-plugin-v0.2.1.*` artifacts for deletion in this task unless the repository policy requires pruning; if they must be removed, do so in a separate explicit `git rm dist/sdd-plugin-v0.2.1.zip dist/sdd-plugin-v0.2.1.tar.gz` step after user confirmation, since deleting tracked release artifacts is a separate decision.

---

## 7. Self-Review

### 7.1 Spec Coverage

- spec 4.1 path model → Task 1 (helper), Task 2 (init/new), Task 3 (hook), Task 5-9 (all skills), Task 10 (constitution guard), Task 11 (README/TESTING), Task 12 (dist).
- spec 6 version state model + AC 42, 62 → Task 1 (`sdd_active_version_dir`, `sdd_state_field`), Task 2 (`state.json` creation), Task 8 (doctor state checks).
- spec 7-9 reference model, same/cross-version, locator + AC 43-45 → Task 4 (templates), Task 5 (prd), Task 6 (spec/dr), Task 7 (plan/code/triage), Task 9 (archive checks).
- spec 10.1 reference table + AC 46, 47 → Task 4 (all four templates).
- spec 11 relation enum + AC 48, 49 → Task 4, Task 7 (plan forbidden relations), Task 10 (constitution).
- spec 12 direction policy + warnings → Task 9 (archive blocking/warning), Task 8 (doctor reference checks).
- spec 13 archive reference summary + AC 55 → Task 9 (`文档引用摘要` extraction rules).
- spec 14 validation → Task 9 (blocking/warning lists), Task 8 (lightweight doctor checks).
- spec 15 archive workflow + AC 50-59, 63 → Task 9 (ARCHIVE.md/INDEX.md/state flip/no move).
- spec 16.1 init + AC 1, 2 → Task 2.
- spec 16.2 new + AC 3, 4, 5 → Task 2.
- spec 16.3 status + AC 6, 7 → Task 8.
- spec 16.4 doctor + AC 8, 9, 64 → Task 8.
- spec 16.5 archive + AC 51-58 → Task 9.
- spec 16.6 prd + AC 10, 11 → Task 5.
- spec 16.7 spec + AC 12-16 → Task 6.
- spec 16.8 plan + AC 17-21 (plan quality density) → Task 7 (plan quality rules) and this plan's own task structure demonstrates the density.
- spec 16.9 dr + AC 22-27, 60 → Task 6.
- spec 16.10 triage + AC 28-31 → Task 7.
- spec 16.11 code + AC 32-37 → Task 7.
- spec 16.12 research + AC 38-41 → Task 5.
- spec 17 impacted skills + supporting assets + AC 61, 65 → all tasks; helper (Task 1), hook (Task 3), templates (Task 4), README (Task 11), CONSTITUTION.default.md (Task 10), fixtures (Task 1), contract tests (every task), package-local + dist (Task 12).
- All 12 user skills covered: init/new (Task 2), status/doctor (Task 8), prd/research (Task 5), spec/dr (Task 6), plan/code/triage (Task 7), archive (Task 9).

### 7.2 Placeholder Scan

- Result: no unresolved template placeholders remain. Literal display tokens such as `vX.Y.Z`, `<spec-name>`, `<dr-id>`, `NNN`, `<tag>-NNNN-<slug>` appear only inside skill/template content where the plugin must show that syntax to users, which is required and correct. No `TBD`, `TODO`, `待定`, `待补充`, `path/to/file`, `<exact signatures>`, `fill in details`, or `implement later` appear in shipped skill/asset content produced by these tasks (the `path/to/*` strings appear only inside the plan template's own example task body, matching the spec's template).

### 7.3 Type / Naming Consistency

- Result: consistent. Helper names `sdd_active_version_dir`, `sdd_state_field`, `sdd_locator_valid`, `sdd_read_status`, `sdd_next_plan_number`, `sdd_next_dr_number`, `sdd_json_target_path`, `sdd_slug` are spelled identically across Task 1 (definition) and Task 3 (consumption). Path model `docs/versions/vX.Y.Z/{state.json,prd.md,specs/,plans/,decisions/,ARCHIVE.md}` and `docs/archive/INDEX.md` are used identically in helper, hook, skills, templates, README, TESTING, fixtures, and dist. Relation enum `references|derives_from|implements|modifies|replaces|deprecates`, state values `active|archived`, DR statuses `drafting|accepted|closed`, and the empty-set row `| 未声明。 | - | - | - | - |` are identical everywhere. Test-file responsibilities do not overlap: helper→`test-common-library.sh`, hook→`test-pre-tool-use.sh`, static skill/template/README/CONSTITUTION contracts→`test-skill-contracts.sh`, packaging→`test-package-local.sh`, plugin metadata→`test-doctor-contract.sh`, aggregation→`test-mvp-acceptance.sh`. `test-skill-contracts.sh` is edited incrementally across Tasks 2, 4, 5, 6, 7, 8, 9, 10, 11, and each edit targets a distinct skill's assertion block (init/new, templates, prd/research, spec/dr, plan/code/triage, status/doctor, archive, constitution/guard, README). Residual risk: every task cites line numbers from the original committed file, but earlier edits shift those numbers; the Global Constraints note requires locating each assertion by its quoted content anchor rather than trusting the line number. The status/doctor block (Task 8) and the archive block (Task 9) are adjacent in the original file; Task 8 stops at the doctor assertions and Task 9 targets only the three `skills/archive/SKILL.md` lines, so they do not collide.

Placeholder note on the shipped template body: Task 4 ships `skills/plan/references/plan.md.tmpl` containing literal `path/to/new-file`, `path/to/existing-file`, `path/to/test-file`, `<task name>`, `<language>`, `<spec section or scenario id>`, and similar `<...>` tokens. These are the product template's own required syntax (they are what `/sdd:plan` shows users and later fills in), not unresolved placeholders in this implementation plan. The Global Constraints placeholder ban applies to shipped skill instructions and generated documents, not to the intentionally templated example task body inside `plan.md.tmpl`, which the spec's §16.8 template mandates verbatim.
