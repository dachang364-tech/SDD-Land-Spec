# SDD Plugin MVP Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the SDD Plugin MVP described by `docs/superpowers/specs/2026-07-11-sdd-plugin-mvp-workflow-spec-design.md`, including 11 Skills, document templates, L1 PreToolUse gating, install checks, and smoke-test coverage.

**Architecture:** The plugin is file-driven: Skills read and write Markdown documents under `docs/`, and document headers are the source of workflow state. Shell scripts provide mechanical checks only: dependency installation, hook registration targets, active-version/status parsing, and PreToolUse path gating. Skills remain the orchestration layer for dialogue, approvals, state transitions, and calls to Superpowers / Spec-Kit.

**Tech Stack:** Claude Code Plugin layout, Claude Code Skills (`skills/<name>/SKILL.md`), Markdown templates under `skills/<name>/references/`, POSIX-compatible Bash scripts, JSON hook registration, shell smoke tests.

## Global Constraints

- MVP 不创建、不读取、不维护 `.sdd/state.json`。
- MVP 不引入 current-version 文件。
- 活跃版本 = `docs/` 下唯一一个未归档的 `vX.Y.Z` 目录。
- MVP Hook 只实现 `PreToolUse: Write/Edit` L1 文档门控。
- Hook 不实现 `src/**` 源码路径门控。
- Hook 不实现 L2 / L3 CONSTITUTION `must` / `should` 机器解析。
- Hook 不实现 PostToolUse 进度记账。
- Hook 不实现 PreCompact 状态持久化。
- Hook 不实现 git log CONFORMANCE 回溯。
- Hook 不实现字段级 status 防篡改。
- `/sdd:init` 不自动修改用户已有的 `CLAUDE.md` / `AGENTS.md`。
- `docs/CONSTITUTION.md` 是项目内 SDD Plugin 工作流的规范性约束源。
- 除 `/sdd:init` 外，所有 SDD Skill 执行前都必须读取 `docs/CONSTITUTION.md`。
- 所有由 SDD Plugin 管理状态的文档，状态行唯一格式为 `- 状态：<value>`。
- `specs/spec.md` 状态只能是 `draft` / `approved`。
- `plans/*.md` 状态只能是 `draft` / `planned` / `coding` / `done`。
- `decisions/*.md` 状态只能是 `drafting` / `accepted` / `closed`。
- `prd.md` 和 `docs/requirements/*.md` 无状态字段。
- 文档类 DR：`spec | doc | typo` 不生成 Implementation Plan，不执行 `/sdd:code`。
- 代码类 DR：`fix | feat | chg | arch` 必须先 `accepted`，才能生成对应 Implementation Plan。
- MVP 不实现公开插件市场分发。

---

## File Structure

Create this plugin structure at repository root:

```text
.claude-plugin/
└── plugin.json
CONSTITUTION.default.md
hooks/
└── hooks.json
scripts/
├── install-deps.sh
├── hooks/
│   ├── pre-tool-use.sh
│   └── session-start.sh
└── lib/
    └── sdd-common.sh
skills/
├── init/
│   └── SKILL.md
├── new/
│   └── SKILL.md
├── research/
│   ├── SKILL.md
│   └── references/
│       └── research.md.tmpl
├── prd/
│   ├── SKILL.md
│   └── references/
│       └── prd.md.tmpl
├── spec/
│   ├── SKILL.md
│   └── references/
│       └── spec.md.tmpl
├── plan/
│   ├── SKILL.md
│   └── references/
│       └── plan.md.tmpl
├── code/
│   └── SKILL.md
├── dr/
│   ├── SKILL.md
│   └── references/
│       └── dr.md.tmpl
├── status/
│   └── SKILL.md
├── doctor/
│   └── SKILL.md
└── archive/
    └── SKILL.md
tests/
├── fixtures/
│   ├── valid-project.sh
│   └── invalid-project.sh
├── test-common.sh
├── test-pre-tool-use.sh
└── test-doctor-contract.sh
README.md
```

Responsibilities:

- `.claude-plugin/plugin.json`: plugin metadata only.
- `CONSTITUTION.default.md`: source copied by `/sdd:init` into `docs/CONSTITUTION.md`.
- `hooks/hooks.json`: registers SessionStart and PreToolUse hooks.
- `scripts/install-deps.sh`: installs/verifies Superpowers and Spec-Kit plugin dependencies.
- `scripts/hooks/pre-tool-use.sh`: L1 path gate for Write/Edit targets.
- `scripts/hooks/session-start.sh`: dependency and constitution presence guidance.
- `scripts/lib/sdd-common.sh`: shared Bash helpers for active version, status parsing, DR/plan naming, and JSON target-path extraction.
- `skills/*/SKILL.md`: slash-command entrypoints and workflow instructions.
- `skills/*/references/*.tmpl`: document templates copied/adapted by Skills.
- `tests/*.sh`: shell smoke tests for mechanical behavior.
- `README.md`: concise plugin install/use reference.

---

### Task 1: Plugin Skeleton, Manifest, Constitution, and Dependency Installer

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `CONSTITUTION.default.md`
- Create: `scripts/install-deps.sh`
- Create: `README.md`
- Create: `tests/test-common.sh`

**Interfaces:**
- Consumes: none.
- Produces:
  - Executable script: `scripts/install-deps.sh`
  - Test helper functions in `tests/test-common.sh`:
    - `assert_file_exists(path: string) -> exits 0|1`
    - `assert_executable(path: string) -> exits 0|1`
    - `assert_contains(path: string, needle: string) -> exits 0|1`

- [ ] **Step 1: Write the failing skeleton contract test**

Create `tests/test-common.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_executable() {
  local path="$1"
  [[ -x "$path" ]] || fail "expected file to be executable: $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}
```

Create `tests/test-doctor-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists ".claude-plugin/plugin.json"
assert_contains ".claude-plugin/plugin.json" '"name": "sdd"'
assert_contains ".claude-plugin/plugin.json" '"version": "0.1.0"'

assert_file_exists "CONSTITUTION.default.md"
assert_contains "CONSTITUTION.default.md" "must: SDD 主流程必须按"
assert_contains "CONSTITUTION.default.md" "must: SDD 管理的状态行只能使用"
assert_contains "CONSTITUTION.default.md" "must: 代码类 DR 必须先"

assert_file_exists "scripts/install-deps.sh"
assert_executable "scripts/install-deps.sh"
assert_contains "scripts/install-deps.sh" 'claude plugin install "claude-plugins-official/superpowers"'
assert_contains "scripts/install-deps.sh" 'claude plugin install "claude-plugins-official/spec-kit"'

assert_file_exists "README.md"
assert_contains "README.md" "/sdd:init"
assert_contains "README.md" "/sdd:archive"

printf 'PASS: skeleton contract\n'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-doctor-contract.sh
```

Expected:

```text
FAIL: expected file to exist: .claude-plugin/plugin.json
```

- [ ] **Step 3: Create plugin skeleton files**

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "sdd",
  "version": "0.1.0",
  "description": "Specification Driven Development workflow plugin for Claude Code"
}
```

Create `CONSTITUTION.default.md`:

```markdown
# CONSTITUTION

> SDD Plugin 项目级流程强制约束。用户可以修改本文件；修改后，本文件即为当前项目新的流程宪法。

## 1. 阶段门控
- must: SDD 主流程必须按 `/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive` 推进。
- must: `/sdd:spec` 必须在 `prd.md` 存在后执行。
- must: feature plan 必须在 `spec.md` 状态为 `approved` 后生成。
- must: `/sdd:code` 只能执行状态为 `planned` 或 `coding` 的 plan。

## 2. 文档状态
- must: SDD 管理的状态行只能使用 `- 状态：<value>` 格式。
- must: spec 状态只能是 `draft` 或 `approved`。
- must: plan 状态只能是 `draft`、`planned`、`coding` 或 `done`。
- must: DR 状态只能是 `drafting`、`accepted` 或 `closed`。
- should: 状态推进应由对应 SDD Skill 完成，不应手工直接改状态。

## 3. DR 流程
- must: 会影响代码实现的变更必须使用代码类 DR：`fix`、`feat`、`chg` 或 `arch`。
- must: 只影响文档表达且不改变系统行为的变更可以使用文档类 DR：`spec`、`doc` 或 `typo`。
- must: 代码类 DR 必须先 `accepted`，才能生成对应 Implementation Plan。
- must: 代码类 DR 只有在关联 plan 完成并通过 verification 后才能关闭为 `committed`。
- may: typo 类修订可以按项目约定跳过 DR。

## 4. Plan 约束
- must: plan 是增量实施记录，文件名必须带版本内递增序号 `NNN-`。
- must: Implementation Tasks 是 Technical Design 的执行展开，不是独立设计层。
- must: 如果实现过程中需要改变技术方案、架构边界、模块影响、数据流 / 控制流、测试策略或实现范围，应通过代码类 DR 创建新的增量 plan。
- must: 当前存在 `coding` plan 时，不把新功能或行为变更直接塞进正在 coding 的原 plan。

## 5. Skill 身份
- must: SDD Skill 执行前必须读取本文件，并将其作为本次 Skill 的项目流程约束上下文。
- must: 若用户请求与本文件冲突，Skill 必须先指出冲突；除非用户先修改本文件，否则不直接执行冲突操作。
- must: 各 Skill 只做自己职责范围内的事情。

## 6. Subagent / Code Worker 约束
- must: subagent 或 code worker 不应自行推进 SDD 文档状态，除非当前 `/sdd:code` Skill 明确要求。
- must: code worker 必须按 plan 执行，并在完成前运行 verification。

## 7. Hook 行为
- must: MVP Hook 只守护 L1 路径 → 前置文档状态门控。
- must: Hook 失败时使用退出码 2，并输出中文错误说明。
- must: Hook 不做文档质量判断、不解析本文件 must / should、不拦截 `src/**`。

## 8. 错误处理
- must: Skill 失败时不得破坏上一稳定文档状态。
- should: 执行失败或 verification 失败时，plan 保持 `coding`，关联 DR 保持 `accepted`。

## 9. 用户修改
- may: 用户可以修改本文件以改变项目流程约束。
- should: 修改本文件后，后续 SDD Skill 应以修改后的内容为准。
```

Create `scripts/install-deps.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

has_plugin() {
  local plugin_name="$1"
  claude plugin list 2>/dev/null | grep -Eq "(^|[[:space:]])${plugin_name}([[:space:]]|$)"
}

install_plugin() {
  local plugin_name="$1"
  local source="$2"
  if has_plugin "$plugin_name"; then
    printf '[skip] %s 已装\n' "$plugin_name"
  else
    printf '[installing] %s...\n' "$plugin_name"
    claude plugin install "$source"
  fi
}

install_plugin "superpowers" "claude-plugins-official/superpowers"
install_plugin "spec-kit" "claude-plugins-official/spec-kit"

printf '[done] 所有依赖已就绪\n'
```

Run:

```bash
chmod +x scripts/install-deps.sh tests/test-common.sh tests/test-doctor-contract.sh
```

Create `README.md`:

```markdown
# SDD Plugin

SDD Plugin provides an MVP Specification Driven Development workflow for Claude Code.

## Commands

- `/sdd:init`
- `/sdd:new vX.Y.Z`
- `/sdd:research <topic>`
- `/sdd:prd`
- `/sdd:spec`
- `/sdd:plan <work-item>`
- `/sdd:code <NNN|work-item>`
- `/sdd:dr <tag> <title>`
- `/sdd:dr accept <id>`
- `/sdd:dr dismiss <id> <reason>`
- `/sdd:status`
- `/sdd:doctor`
- `/sdd:archive`

## Install dependencies

```bash
scripts/install-deps.sh
```

## Workflow

```text
/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive
```

Code-affecting changes use:

```text
/sdd:dr fix|feat|chg|arch <title> → /sdd:dr accept <id> → /sdd:plan <id> → /sdd:code <NNN|id>
```
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/test-doctor-contract.sh
```

Expected:

```text
PASS: skeleton contract
```

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json CONSTITUTION.default.md scripts/install-deps.sh tests/test-common.sh tests/test-doctor-contract.sh README.md
git commit -m "feat: add SDD plugin skeleton"
```

---

### Task 2: Shared Bash Library for Status, Active Version, and Path Parsing

**Files:**
- Create: `scripts/lib/sdd-common.sh`
- Create: `tests/fixtures/valid-project.sh`
- Create: `tests/fixtures/invalid-project.sh`
- Create: `tests/test-common-library.sh`

**Interfaces:**
- Consumes: executable shell environment from Task 1.
- Produces functions in `scripts/lib/sdd-common.sh`:
  - `sdd_read_status(file: string) -> prints status or exits 2`
  - `sdd_assert_status(file: string, allowed_csv: string) -> exits 0|2`
  - `sdd_active_version_dir(root: string) -> prints docs/vX.Y.Z or exits 2`
  - `sdd_next_plan_number(plans_dir: string) -> prints NNN`
  - `sdd_next_dr_number(decisions_dir: string) -> prints NNNN`
  - `sdd_json_target_path(stdin_json: string) -> prints path or empty string`
  - `sdd_slug(input: string) -> prints lowercase kebab-case slug`

- [ ] **Step 1: Write the failing library tests**

Create `tests/fixtures/valid-project.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/v0.1.0/specs" "$root/docs/v0.1.0/plans" "$root/docs/v0.1.0/decisions" "$root/docs/archive" "$root/docs/requirements"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '# PRD\n' > "$root/docs/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：approved\n' > "$root/docs/v0.1.0/specs/spec.md"
printf '# Plan\n\n- 状态：planned\n' > "$root/docs/v0.1.0/plans/001-feature-login.md"
printf '# DR\n\n- 状态：accepted\n- tag：fix\n- closed_reason: null\n' > "$root/docs/v0.1.0/decisions/fix-0001-login-null.md"
```

Create `tests/fixtures/invalid-project.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/v0.1.0/specs" "$root/docs/v0.2.0/specs" "$root/docs/archive/v0.0.1"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$root/docs/v0.1.0/specs/spec.md"
```

Create `tests/test-common-library.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-common.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash tests/fixtures/valid-project.sh "$tmp/valid"

status="$(sdd_read_status "$tmp/valid/docs/v0.1.0/specs/spec.md")"
[[ "$status" == "approved" ]] || fail "expected approved status, got $status"

active="$(sdd_active_version_dir "$tmp/valid")"
[[ "$active" == "docs/v0.1.0" ]] || fail "expected docs/v0.1.0, got $active"

number="$(sdd_next_plan_number "$tmp/valid/docs/v0.1.0/plans")"
[[ "$number" == "002" ]] || fail "expected next plan 002, got $number"

dr_number="$(sdd_next_dr_number "$tmp/valid/docs/v0.1.0/decisions")"
[[ "$dr_number" == "0002" ]] || fail "expected next DR 0002, got $dr_number"

slug="$(sdd_slug 'Login Null Error!')"
[[ "$slug" == "login-null-error" ]] || fail "expected login-null-error, got $slug"

target="$(printf '{"tool_input":{"file_path":"docs/v0.1.0/prd.md"}}' | sdd_json_target_path)"
[[ "$target" == "docs/v0.1.0/prd.md" ]] || fail "expected file_path target, got $target"

target2="$(printf '{"tool_input":{"path":"docs/v0.1.0/specs/spec.md"}}' | sdd_json_target_path)"
[[ "$target2" == "docs/v0.1.0/specs/spec.md" ]] || fail "expected path target, got $target2"

bash tests/fixtures/invalid-project.sh "$tmp/invalid"
if sdd_active_version_dir "$tmp/invalid" >/tmp/sdd-invalid.out 2>/tmp/sdd-invalid.err; then
  fail "expected multiple active versions to fail"
fi
assert_contains "/tmp/sdd-invalid.err" "发现多个未归档版本目录"

printf 'PASS: common library\n'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-common-library.sh
```

Expected:

```text
tests/test-common-library.sh: line ...: scripts/lib/sdd-common.sh: No such file or directory
```

- [ ] **Step 3: Implement shared library**

Create `scripts/lib/sdd-common.sh`:

```bash
#!/usr/bin/env bash

sdd_read_status() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf '文档不存在：%s\n' "$file" >&2
    return 2
  fi

  local line
  line="$(grep -E '^- 状态：' "$file" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    printf '文档缺少状态行：%s，需要格式：- 状态：<value>\n' "$file" >&2
    return 2
  fi

  printf '%s\n' "${line#- 状态：}"
}

sdd_assert_status() {
  local file="$1"
  local allowed_csv="$2"
  local status
  status="$(sdd_read_status "$file")" || return 2

  IFS=',' read -r -a allowed <<< "$allowed_csv"
  local value
  for value in "${allowed[@]}"; do
    if [[ "$status" == "$value" ]]; then
      return 0
    fi
  done

  printf '状态非法：%s 状态为 %s，期望其中之一：%s\n' "$file" "$status" "$allowed_csv" >&2
  return 2
}

sdd_active_version_dir() {
  local root="$1"
  local docs_dir="$root/docs"
  if [[ ! -d "$docs_dir" ]]; then
    printf '未找到 docs/，请先运行 /sdd:init。\n' >&2
    return 2
  fi

  local versions=()
  local path
  shopt -s nullglob
  for path in "$docs_dir"/v*; do
    [[ -d "$path" ]] || continue
    case "$(basename "$path")" in
      v[0-9]*.[0-9]*.[0-9]*) versions+=("docs/$(basename "$path")") ;;
    esac
  done
  shopt -u nullglob

  if [[ "${#versions[@]}" -eq 0 ]]; then
    printf '未找到活跃版本目录，请先运行 /sdd:new vX.Y.Z。\n' >&2
    return 2
  fi

  if [[ "${#versions[@]}" -gt 1 ]]; then
    printf '发现多个未归档版本目录：%s。MVP 不支持多活跃版本，请先运行 /sdd:archive。\n' "${versions[*]}" >&2
    return 2
  fi

  printf '%s\n' "${versions[0]}"
}

sdd_next_plan_number() {
  local plans_dir="$1"
  local max=0
  local file base prefix
  shopt -s nullglob
  for file in "$plans_dir"/[0-9][0-9][0-9]-*.md; do
    base="$(basename "$file")"
    prefix="${base%%-*}"
    if [[ "$prefix" =~ ^[0-9][0-9][0-9]$ ]] && (( 10#$prefix > max )); then
      max=$((10#$prefix))
    fi
  done
  shopt -u nullglob
  printf '%03d\n' "$((max + 1))"
}

sdd_next_dr_number() {
  local decisions_dir="$1"
  local max=0
  local file base rest number
  shopt -s nullglob
  for file in "$decisions_dir"/*.md; do
    base="$(basename "$file" .md)"
    rest="${base#*-}"
    number="${rest%%-*}"
    if [[ "$number" =~ ^[0-9][0-9][0-9][0-9]$ ]] && (( 10#$number > max )); then
      max=$((10#$number))
    fi
  done
  shopt -u nullglob
  printf '%04d\n' "$((max + 1))"
}

sdd_json_target_path() {
  local payload
  payload="$(cat)"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; data=json.load(sys.stdin); ti=data.get("tool_input",{}); print(ti.get("file_path") or ti.get("path") or "")' <<< "$payload"
  else
    printf '%s\n' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
  fi
}

sdd_slug() {
  local input="$1"
  printf '%s\n' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}
```

Run:

```bash
chmod +x scripts/lib/sdd-common.sh tests/fixtures/valid-project.sh tests/fixtures/invalid-project.sh tests/test-common-library.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/test-common-library.sh
```

Expected:

```text
PASS: common library
```

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-common.sh tests/fixtures/valid-project.sh tests/fixtures/invalid-project.sh tests/test-common-library.sh
git commit -m "feat: add SDD workflow shell helpers"
```

---

### Task 3: PreToolUse and SessionStart Hooks

**Files:**
- Create: `hooks/hooks.json`
- Create: `scripts/hooks/pre-tool-use.sh`
- Create: `scripts/hooks/session-start.sh`
- Create: `tests/test-pre-tool-use.sh`

**Interfaces:**
- Consumes from Task 2:
  - `sdd_json_target_path()`
  - `sdd_read_status()`
- Produces:
  - `scripts/hooks/pre-tool-use.sh` executable; reads Claude Code hook JSON on stdin; exits `0` to allow, `2` to block.
  - `scripts/hooks/session-start.sh` executable; prints dependency guidance and exits `0`.

- [ ] **Step 1: Write failing hook tests**

Create `tests/test-pre-tool-use.sh`:

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

run_hook "$tmp" "docs/v0.1.0/prd.md"
run_hook "$tmp" "docs/v0.1.0/specs/spec.md"
run_hook "$tmp" "docs/v0.1.0/plans/001-feature-login.md"
run_hook "$tmp" "docs/v0.1.0/plans/002-fix-0001-login-null.md"
run_hook "$tmp" "docs/v0.1.0/decisions/fix-0002-other.md"
run_hook "$tmp" "docs/requirements/topic-2026-07.md"
run_hook "$tmp" "src/app.ts"

rm "$tmp/docs/v0.1.0/prd.md"
if run_hook "$tmp" "docs/v0.1.0/specs/spec.md" >/tmp/sdd-hook.out 2>/tmp/sdd-hook.err; then
  fail "expected spec write without PRD to fail"
fi
assert_contains "/tmp/sdd-hook.err" "无法写入 docs/v0.1.0/specs/spec.md"
assert_contains "/tmp/sdd-hook.err" "请先完成 /sdd:prd"

printf '# PRD\n' > "$tmp/docs/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$tmp/docs/v0.1.0/specs/spec.md"
if run_hook "$tmp" "docs/v0.1.0/plans/003-feature-settings.md" >/tmp/sdd-hook2.out 2>/tmp/sdd-hook2.err; then
  fail "expected feature plan write with draft spec to fail"
fi
assert_contains "/tmp/sdd-hook2.err" "前置文档 docs/v0.1.0/specs/spec.md 状态为 draft，期望 approved"

printf '# DR\n\n- 状态：drafting\n' > "$tmp/docs/v0.1.0/decisions/chg-0002-policy.md"
if run_hook "$tmp" "docs/v0.1.0/plans/004-chg-0002-policy.md" >/tmp/sdd-hook3.out 2>/tmp/sdd-hook3.err; then
  fail "expected code DR plan write with drafting DR to fail"
fi
assert_contains "/tmp/sdd-hook3.err" "前置 DR docs/v0.1.0/decisions/chg-0002-policy.md 状态为 drafting，期望 accepted"

printf 'PASS: pre-tool-use hook\n'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected:

```text
tests/test-pre-tool-use.sh: line ...: scripts/hooks/pre-tool-use.sh: No such file or directory
```

- [ ] **Step 3: Implement hook registration and scripts**

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "scripts/hooks/session-start.sh"
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
            "command": "scripts/hooks/pre-tool-use.sh"
          }
        ]
      }
    ]
  }
}
```

Create `scripts/hooks/pre-tool-use.sh`:

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
  docs/v*/prd.md)
    exit 0
    ;;
  docs/v*/specs/spec.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    prd="docs/$version/prd.md"
    if [[ ! -f "$prd" ]]; then
      printf '无法写入 %s：\n前置文档 %s 不存在。\n请先完成 /sdd:prd。\n' "$target_path" "$prd" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/plans/[0-9][0-9][0-9]-feature-*.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    spec="docs/$version/specs/spec.md"
    status="$(sdd_read_status "$spec")" || exit 2
    if [[ "$status" != "approved" ]]; then
      printf '无法写入 %s：\n前置文档 %s 状态为 %s，期望 approved。\n请先完成 /sdd:spec 并批准 Functional Specification。\n' "$target_path" "$spec" "$status" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/plans/[0-9][0-9][0-9]-fix-*.md|docs/v*/plans/[0-9][0-9][0-9]-feat-*.md|docs/v*/plans/[0-9][0-9][0-9]-chg-*.md|docs/v*/plans/[0-9][0-9][0-9]-arch-*.md)
    version="${target_path#docs/}"
    version="${version%%/*}"
    base="$(basename "$target_path" .md)"
    dr_id="${base#???-}"
    dr="docs/$version/decisions/$dr_id.md"
    status="$(sdd_read_status "$dr")" || exit 2
    if [[ "$status" != "accepted" ]]; then
      printf '无法写入 %s：\n前置 DR %s 状态为 %s，期望 accepted。\n请先运行 /sdd:dr accept %s。\n' "$target_path" "$dr" "$status" "$dr_id" >&2
      exit 2
    fi
    exit 0
    ;;
  docs/v*/decisions/*.md|docs/requirements/*.md|src/*|src/**)
    exit 0
    ;;
  docs/archive/*|docs/archive/**)
    printf '无法直接写入 %s：archive 内容应由 /sdd:archive 移动生成。\n' "$target_path" >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
```

Create `scripts/hooks/session-start.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

missing=0
if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])superpowers([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 superpowers；请运行 scripts/install-deps.sh。\n' >&2
  missing=1
fi

if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])spec-kit([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 spec-kit；请运行 scripts/install-deps.sh。\n' >&2
  missing=1
fi

if [[ ! -f docs/CONSTITUTION.md ]]; then
  printf 'SDD Plugin: 当前项目尚未初始化；如需使用 SDD 工作流，请运行 /sdd:init。\n' >&2
fi

exit 0
```

Run:

```bash
chmod +x scripts/hooks/pre-tool-use.sh scripts/hooks/session-start.sh tests/test-pre-tool-use.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected:

```text
PASS: pre-tool-use hook
```

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json scripts/hooks/pre-tool-use.sh scripts/hooks/session-start.sh tests/test-pre-tool-use.sh
git commit -m "feat: add SDD document gate hooks"
```

---

### Task 4: Core Workflow Skills for init, new, research, prd, and spec

**Files:**
- Create: `skills/init/SKILL.md`
- Create: `skills/new/SKILL.md`
- Create: `skills/research/SKILL.md`
- Create: `skills/research/references/research.md.tmpl`
- Create: `skills/prd/SKILL.md`
- Create: `skills/prd/references/prd.md.tmpl`
- Create: `skills/spec/SKILL.md`
- Create: `skills/spec/references/spec.md.tmpl`
- Create: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - `CONSTITUTION.default.md`
  - `scripts/install-deps.sh`
  - `sdd_active_version_dir(root)` from Task 2
- Produces Skill entrypoints:
  - `/sdd:init`
  - `/sdd:new vX.Y.Z`
  - `/sdd:research <topic>`
  - `/sdd:prd`
  - `/sdd:spec`

- [ ] **Step 1: Write failing Skill contract tests**

Create `tests/test-skill-contracts.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

for skill in init new research prd spec plan code dr status doctor archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

assert_contains "skills/init/SKILL.md" "description: Initialize SDD project structure"
assert_contains "skills/init/SKILL.md" "docs/CONSTITUTION.md 已存在"
assert_contains "skills/init/SKILL.md" "不要创建 .sdd/state.json"

assert_contains "skills/new/SKILL.md" "description: Create the unique active SDD version directory"
assert_contains "skills/new/SKILL.md" "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
assert_contains "skills/new/SKILL.md" "docs/vX.Y.Z/specs/"

assert_contains "skills/research/SKILL.md" "description: Create project-level SDD research notes"
assert_file_exists "skills/research/references/research.md.tmpl"
assert_contains "skills/research/references/research.md.tmpl" "# 研究：<topic>"

assert_contains "skills/prd/SKILL.md" "description: Create the product requirements document"
assert_file_exists "skills/prd/references/prd.md.tmpl"
assert_contains "skills/prd/references/prd.md.tmpl" "# PRD：<产品/版本名>"
assert_contains "skills/prd/references/prd.md.tmpl" "## 6. 成功标准"

assert_contains "skills/spec/SKILL.md" "description: Create or revise the functional specification"
assert_file_exists "skills/spec/references/spec.md.tmpl"
assert_contains "skills/spec/references/spec.md.tmpl" "- 状态：draft"
assert_contains "skills/spec/SKILL.md" "用户确认后，将状态切换为 `approved`"

printf 'PASS: skill contracts\n'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected:

```text
FAIL: expected file to exist: skills/init/SKILL.md
```

- [ ] **Step 3: Create core workflow Skills and templates**

Create `skills/init/SKILL.md`:

```markdown
---
name: init
description: Initialize SDD project structure. Use for /sdd:init when the project has not yet been initialized for SDD.
---

# /sdd:init

Initialize current project for SDD Plugin MVP.

## Preconditions

1. Check whether `docs/CONSTITUTION.md` exists.
2. If `docs/CONSTITUTION.md` exists, stop and say: `docs/CONSTITUTION.md 已存在；已初始化，请运行 /sdd:status 查看当前状态。`

## Steps

1. Run `scripts/install-deps.sh`.
2. If dependency installation fails, stop and ask the user to run `scripts/install-deps.sh` manually.
3. Create directories:
   - `docs/requirements/`
   - `docs/archive/`
4. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
5. Do not create `.sdd/state.json`.
6. Do not create any version directory.
7. Do not create `prd.md`, `spec.md`, or plan files.
8. Do not modify `CLAUDE.md` or `AGENTS.md`.

## Output

Report created paths:

```text
docs/CONSTITUTION.md
docs/requirements/
docs/archive/
```
```

Create `skills/new/SKILL.md`:

```markdown
---
name: new
description: Create the unique active SDD version directory. Use for /sdd:new vX.Y.Z.
---

# /sdd:new

Create a single active version directory.

## Required argument

Version must match:

```text
^v[0-9]+\.[0-9]+\.[0-9]+$
```

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Scan `docs/v*/` excluding `docs/archive/**`.
3. If any active version directory exists, stop and say: `已有未归档版本目录；MVP 不支持多活跃版本，请先运行 /sdd:archive。`

## Steps

Create:

```text
docs/vX.Y.Z/specs/
docs/vX.Y.Z/plans/
docs/vX.Y.Z/decisions/
```

Do not create:

```text
docs/vX.Y.Z/prd.md
docs/vX.Y.Z/specs/spec.md
docs/vX.Y.Z/plans/*.md
.sdd/state.json
```
```

Create `skills/research/SKILL.md`:

```markdown
---
name: research
description: Create project-level SDD research notes. Use for /sdd:research <topic>.
---

# /sdd:research

Create project-level research material under `docs/requirements/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Ensure `docs/requirements/` exists.

## Dialogue

Ask the user for:

1. Research topic.
2. Why this topic matters.
3. Sources or local files to inspect.
4. Desired decision output for later PRD use.

## Output path

Write:

```text
docs/requirements/<topic-slug>-<yyyy-mm>.md
```

The document has no `- 状态：` line.
```

Create `skills/research/references/research.md.tmpl`:

```markdown
# 研究：<topic>

- 日期：YYYY-MM-DD

## 背景

## 调研方法

## 发现

### 关键事实 1

### 关键事实 2

### 关键事实 3

## 建议

## 可供 PRD 引用的结论
```

Create `skills/prd/SKILL.md`:

```markdown
---
name: prd
description: Create the product requirements document. Use for /sdd:prd.
---

# /sdd:prd

Create `docs/vX.Y.Z/prd.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory under `docs/v*/`.
3. If there is no active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
4. If there are multiple active versions, stop and ask the user to archive old versions.

## Dialogue

1. Scan `docs/requirements/*.md`.
2. Ask the user which requirement documents to reference.
3. Clarify product background, target users, pain points, business goals, scope in/out, success criteria, risks, and assumptions.

## Output

Write `docs/vX.Y.Z/prd.md` using `skills/prd/references/prd.md.tmpl`.

Do not include a `- 状态：` line.
```

Create `skills/prd/references/prd.md.tmpl`:

```markdown
# PRD：<产品/版本名>

- 版本：vX.Y.Z
- 日期：YYYY-MM-DD

## 上游需求资料
| 路径 | 摘要 |
| ---- | ---- |

## 1. 背景

## 2. 目标用户

## 3. 问题与痛点

## 4. 产品目标

## 5. 范围

### 5.1 In Scope

### 5.2 Out of Scope

## 6. 成功标准

## 7. 风险与假设
```

Create `skills/spec/SKILL.md`:

```markdown
---
name: spec
description: Create or revise the functional specification. Use for /sdd:spec.
---

# /sdd:spec

Create or revise `docs/vX.Y.Z/specs/spec.md` from PRD and optional accepted document-class DRs.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Require `docs/vX.Y.Z/prd.md` to exist.
4. If `prd.md` is missing, stop and say: `prd.md 不存在，请先运行 /sdd:prd。`

## Dialogue

Clarify:

1. 功能边界
2. 用户故事
3. 业务规则
4. 输入输出
5. 异常 / 边界场景
6. 验收标准
7. 非目标

If accepted document-class DRs exist with tag `spec`, `doc`, or `typo`, list them and ask whether to associate one or more with this spec revision.

## Steps

1. Read `prd.md`.
2. Use Spec-Kit structure for functional specification writing.
3. Write `docs/vX.Y.Z/specs/spec.md` with `- 状态：draft`.
4. Ask the user to approve or request changes.
5. 用户确认后，将状态切换为 `approved`.
6. If associated document-class DRs were committed by this revision, change each associated DR from `accepted` to `closed`, set `closed_reason: committed`, and set `closed_at` to current UTC timestamp.

## Failure behavior

If the user does not approve, keep `spec.md` at `draft`.
```

Create `skills/spec/references/spec.md.tmpl`:

```markdown
# Functional Specification：<名称>

- 版本：vX.Y.Z
- 状态：draft
- 上游 PRD：docs/vX.Y.Z/prd.md

## 1. 功能概述

## 2. 用户故事

## 3. 功能行为

## 4. 业务规则

## 5. 输入输出

## 6. 边界与异常场景

## 7. 验收场景

### Scenario 1: <场景名>
Given <前置条件>
When <用户动作或系统事件>
Then <可验证结果>

## 8. 非目标

## 9. 关联 DRs
| DR ID | tag | title | status | date |
| ----- | --- | ----- | ------ | ---- |
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected initially still fails because plan/code/dr/status/doctor/archive are not created:

```text
FAIL: expected file to exist: skills/plan/SKILL.md
```

For this task, run this focused verification:

```bash
for f in skills/init/SKILL.md skills/new/SKILL.md skills/research/SKILL.md skills/prd/SKILL.md skills/spec/SKILL.md skills/research/references/research.md.tmpl skills/prd/references/prd.md.tmpl skills/spec/references/spec.md.tmpl; do test -f "$f" || exit 1; done
```

Expected: command exits `0` with no output.

- [ ] **Step 5: Commit**

```bash
git add skills/init/SKILL.md skills/new/SKILL.md skills/research/SKILL.md skills/research/references/research.md.tmpl skills/prd/SKILL.md skills/prd/references/prd.md.tmpl skills/spec/SKILL.md skills/spec/references/spec.md.tmpl tests/test-skill-contracts.sh
git commit -m "feat: add core SDD workflow skills"
```

---

### Task 5: Plan and Code Skills

**Files:**
- Create: `skills/plan/SKILL.md`
- Create: `skills/plan/references/plan.md.tmpl`
- Create: `skills/code/SKILL.md`

**Interfaces:**
- Consumes:
  - `docs/vX.Y.Z/specs/spec.md` with `- 状态：approved`
  - accepted code-class DRs under `docs/vX.Y.Z/decisions/*.md`
  - `sdd_next_plan_number(plans_dir)` from Task 2
- Produces:
  - `/sdd:plan <work-item>` with feature mode and code-class DR mode
  - `/sdd:code <NNN|work-item>` execution orchestration

- [ ] **Step 1: Add focused tests for plan/code Skill contracts**

Append to `tests/test-skill-contracts.sh` before the final `printf` line:

```bash
assert_contains "skills/plan/SKILL.md" "description: Create an implementation plan from approved spec or accepted code-class DR"
assert_contains "skills/plan/SKILL.md" "^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$"
assert_contains "skills/plan/SKILL.md" "文档类 DR 不生成 Implementation Plan"
assert_contains "skills/plan/SKILL.md" "Technical Planning Dialogue"
assert_file_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/plan/references/plan.md.tmpl" "## Technical Design"
assert_contains "skills/plan/references/plan.md.tmpl" "## Implementation Tasks"

assert_contains "skills/code/SKILL.md" "description: Execute an SDD implementation plan"
assert_contains "skills/code/SKILL.md" "高质量模式：`superpowers:subagent-driven-development`"
assert_contains "skills/code/SKILL.md" "快速模式：`superpowers:executing-plans`"
assert_contains "skills/code/SKILL.md" "plan 状态从 `planned` 切换为 `coding`"
assert_contains "skills/code/SKILL.md" "verification 通过后，将 plan 状态切换为 `done`"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected:

```text
FAIL: expected file to exist: skills/plan/SKILL.md
```

- [ ] **Step 3: Create plan/code Skills and plan template**

Create `skills/plan/SKILL.md`:

```markdown
---
name: plan
description: Create an implementation plan from approved spec or accepted code-class DR. Use for /sdd:plan <work-item>.
---

# /sdd:plan

Generate an Implementation Plan under `docs/vX.Y.Z/plans/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Parse `<work-item>` by syntax, not by semantic guessing.

## Mode detection

1. If `<work-item>` matches `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, use code-class DR mode.
2. If `<work-item>` matches `^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$`, refuse: `文档类 DR 不生成 Implementation Plan，不执行 /sdd:code。`
3. Otherwise use feature mode.

## Feature mode

Precondition:

```text
docs/vX.Y.Z/specs/spec.md 状态为 approved
```

Normalize names:

```text
login         → feature-login
feature-login → feature-login
```

Output path:

```text
docs/vX.Y.Z/plans/NNN-feature-<name>.md
```

## Code-class DR mode

Precondition:

```text
docs/vX.Y.Z/decisions/<dr-id>.md 状态为 accepted
```

Output path:

```text
docs/vX.Y.Z/plans/NNN-<dr-id>.md
```

## Technical Planning Dialogue

Before writing Implementation Tasks:

1. Read spec.
2. Read DR when in code-class DR mode.
3. Explore current code structure.
4. Identify affected modules and file areas.
5. Present 2-3 implementation approaches.
6. Recommend one approach with tradeoffs.
7. Confirm architecture boundaries, data/control flow, file impact, testing strategy, risks, and constraints with the user.
8. Only after user confirmation, generate the plan.

## Plan content

Use `skills/plan/references/plan.md.tmpl`.

Initial status:

```markdown
- 状态：draft
```

After user approval, change status to:

```markdown
- 状态：planned
```
```

Create `skills/plan/references/plan.md.tmpl`:

```markdown
# NNN-<work-item> Implementation Plan

- 序号：NNN
- 状态：draft
- 类型：feature | fix | feat | chg | arch
- 上游 spec：docs/vX.Y.Z/specs/spec.md
- 关联 DR：null | <dr-id>

## Technical Design

### 1. 技术方案

### 2. 架构边界

### 3. 模块影响

### 4. 数据流 / 控制流

### 5. 测试策略

### 6. 风险与约束

## Implementation Tasks

本章节是 Technical Design 的执行展开，不是独立设计层。

如果实现过程中需要改变技术方案、架构边界、模块影响、数据流 / 控制流、测试策略或实现范围，不直接改写既有 tasks；应通过代码类 DR 创建新的增量 plan。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** <one sentence>

**Architecture:** <two or three sentences>

**Tech Stack:** <key technologies>

## Global Constraints

- MVP 不创建、不读取、不维护 `.sdd/state.json`。
- 状态行唯一格式为 `- 状态：<value>`。
- plan 是增量实施记录，文件名必须带版本内递增序号 `NNN-`。

### Task 1: <task name>

**Files:**
- Create: `path/to/file`
- Modify: `path/to/file`
- Test: `path/to/test`

**Interfaces:**
- Consumes: <exact signatures from previous tasks>
- Produces: <exact signatures for later tasks>

- [ ] **Step 1: Write the failing test**

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write minimal implementation**

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**
```

Create `skills/code/SKILL.md`:

```markdown
---
name: code
description: Execute an SDD implementation plan. Use for /sdd:code <NNN|work-item>.
---

# /sdd:code

Execute an existing Implementation Plan.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Locate the plan from `<NNN|work-item>`.
4. Require plan status to be `planned` or `coding`.
5. If plan has a code-class DR, require DR status to be `accepted`.

## Plan lookup

1. If input is `NNN`, match `docs/vX.Y.Z/plans/NNN-*.md`.
2. If input is a complete plan basename, match the same `.md` basename.
3. If input is feature name or DR ID, match by suffix.
4. If zero plans match, stop and ask the user to run `/sdd:plan <work-item>`.
5. If multiple plans match, stop and ask the user to use plan number, for example `/sdd:code 002`.

## Execution mode

Ask the user to choose:

1. 高质量模式：`superpowers:subagent-driven-development`
2. 快速模式：`superpowers:executing-plans`

## Steps

1. Change plan 状态从 `planned` 切换为 `coding`; if already `coding`, keep it.
2. Execute the plan with the chosen Superpowers sub-skill.
3. Run `superpowers:verification-before-completion`.
4. When execution succeeds and verification passes, change plan status to `done`.
5. If plan has a code-class DR, change that DR from `accepted` to `closed`.
6. Set DR `closed_reason: committed`.
7. Set DR `closed_at` to current UTC timestamp.
8. If the DR has `supersedes`, update superseded DR files with `superseded_by`.

## Failure behavior

If execution or verification fails:

```text
plan remains coding
associated DR remains accepted
```
```

- [ ] **Step 4: Run focused verification**

Run:

```bash
for f in skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/code/SKILL.md; do test -f "$f" || exit 1; done
```

Expected: command exits `0` with no output.

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md skills/plan/references/plan.md.tmpl skills/code/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: add SDD plan and code skills"
```

---

### Task 6: DR, Status, Doctor, and Archive Skills

**Files:**
- Create: `skills/dr/SKILL.md`
- Create: `skills/dr/references/dr.md.tmpl`
- Create: `skills/status/SKILL.md`
- Create: `skills/doctor/SKILL.md`
- Create: `skills/archive/SKILL.md`

**Interfaces:**
- Consumes:
  - active version directory resolution from Task 2
  - status parsing from Task 2
  - all Skill contracts from Tasks 4-5
- Produces:
  - `/sdd:dr <tag> <title>`
  - `/sdd:dr accept <id>`
  - `/sdd:dr dismiss <id> <reason>`
  - `/sdd:status`
  - `/sdd:doctor`
  - `/sdd:archive`

- [ ] **Step 1: Add focused Skill contract assertions**

Append to `tests/test-skill-contracts.sh` before the final `printf` line:

```bash
assert_contains "skills/dr/SKILL.md" "description: Create, accept, or dismiss SDD decision records"
assert_contains "skills/dr/SKILL.md" "fix | feat | chg | arch | spec | doc | typo"
assert_contains "skills/dr/SKILL.md" "drafting → accepted"
assert_contains "skills/dr/SKILL.md" "accepted 或 closed DR 不允许 dismiss"
assert_file_exists "skills/dr/references/dr.md.tmpl"
assert_contains "skills/dr/references/dr.md.tmpl" "- closed_reason: null"

assert_contains "skills/status/SKILL.md" "description: Show current SDD version status and next-step guidance"
assert_contains "skills/status/SKILL.md" "展示当前版本状态与下一步建议"

assert_contains "skills/doctor/SKILL.md" "description: Diagnose SDD plugin installation and project consistency"
assert_contains "skills/doctor/SKILL.md" ".claude-plugin/plugin.json"
assert_contains "skills/doctor/SKILL.md" "done 的代码类 DR plan 对应 DR 是否仍 accepted"

assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" "所有 `plans/*.md` 状态为 `done`"
assert_contains "skills/archive/SKILL.md" "docs/vX.Y.Z/ → docs/archive/vX.Y.Z/"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected:

```text
FAIL: expected file to exist: skills/dr/SKILL.md
```

- [ ] **Step 3: Create cross-cutting Skills and DR template**

Create `skills/dr/SKILL.md`:

```markdown
---
name: dr
description: Create, accept, or dismiss SDD decision records. Use for /sdd:dr <tag> <title>, /sdd:dr accept <id>, or /sdd:dr dismiss <id> <reason>.
---

# /sdd:dr

Manage Decision Records.

## Tags

```text
fix | feat | chg | arch | spec | doc | typo
```

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.

## Dispatch

1. If first argument is `accept`, run accept mode.
2. If first argument is `dismiss`, run dismiss mode.
3. If first argument is one of the valid tags, run create mode.
4. Otherwise print usage.

## Create mode

Input:

```text
/sdd:dr <tag> <title>
```

Steps:

1. Generate globally increasing DR number from existing `docs/vX.Y.Z/decisions/*.md`.
2. Slugify title.
3. Write `docs/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
4. Initial status is `drafting`.

## Accept mode

Input:

```text
/sdd:dr accept <id>
```

Precondition:

```text
DR 状态为 drafting
```

Steps:

1. Change `drafting → accepted`.
2. Do not write `closed_reason`.
3. Do not write `closed_at`.
4. Do not update supersede chain.
5. Output next step:
   - code-class DR: `/sdd:plan <id>`
   - document-class DR: run `/sdd:spec` or corresponding document Skill

## Dismiss mode

Input:

```text
/sdd:dr dismiss <id> <reason>
```

Precondition:

```text
DR 状态为 drafting
```

Steps:

1. Change `drafting → closed`.
2. Set `closed_reason: dismissed`.
3. Set `dismissed_reason` to the provided reason.
4. Set `closed_at` to current UTC timestamp.

Failure behavior:

```text
accepted 或 closed DR 不允许 dismiss；错误时另起 DR supersede。
```
```

Create `skills/dr/references/dr.md.tmpl`:

```markdown
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- tag：fix | feat | chg | arch | spec | doc | typo
- 日期：YYYY-MM-DD
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |

## 背景

## 决策

## 影响

## 落地方式
```

Create `skills/status/SKILL.md`:

```markdown
---
name: status
description: Show current SDD version status and next-step guidance. Use for /sdd:status.
---

# /sdd:status

展示当前版本状态与下一步建议。

## Steps

1. Read `docs/CONSTITUTION.md`; if missing, report that the project is not initialized and suggest `/sdd:init`.
2. Resolve the unique active version directory.
3. Check whether `prd.md` exists.
4. Check `specs/spec.md` status when present.
5. Scan `plans/*.md` and list each plan status.
6. Scan `decisions/*.md` and list `drafting` DRs.
7. Scan `decisions/*.md` and list `accepted` DRs.
8. Print next-step guidance.

## Output shape

```text
当前活跃版本：v0.1.0

PRD：存在
SPEC：approved

Plans：
- 001-feature-login：done

DRs：
- drafting：arch-0002-split-auth
- accepted：fix-0001-null-login

下一步建议：
- /sdd:code 002
```

Do not inspect git log.
Do not diagnose source-code consistency.
```

Create `skills/doctor/SKILL.md`:

```markdown
---
name: doctor
description: Diagnose SDD plugin installation and project consistency. Use for /sdd:doctor.
---

# /sdd:doctor

Diagnose plugin installation integrity and minimum project consistency.

## Plugin installation checks

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
skills/status/SKILL.md
skills/doctor/SKILL.md
skills/archive/SKILL.md
hooks/hooks.json
scripts/install-deps.sh
scripts/hooks/pre-tool-use.sh
CONSTITUTION.default.md
```

Check dependency reachability:

```text
superpowers
spec-kit
```

## Project consistency checks

1. Whether `docs/CONSTITUTION.md` exists.
2. Whether there is exactly one active version.
3. Whether status lines are parseable.
4. Whether status values are legal.
5. Whether closed DRs have `closed_reason`.
6. Whether accepted code-class DRs have matching plans after removing `NNN-` prefix.
7. Whether done code-class DR plan corresponding DR is still accepted.
8. Report: `done 的代码类 DR plan 对应 DR 是否仍 accepted`.

## Non-goals

Do not inspect git log.
Do not audit source-code changes.
Do not machine-parse `docs/CONSTITUTION.md` must/should rules.
```

Create `skills/archive/SKILL.md`:

```markdown
---
name: archive
description: Archive the current active SDD version. Use for /sdd:archive.
---

# /sdd:archive

Archive the current active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. There is exactly one active version.
3. `prd.md` exists.
4. `spec.md` status is `approved`.
5. 所有 `plans/*.md` 状态为 `done`.
6. No DR status is `drafting`.
7. No DR status is `accepted`.

## Steps

Move:

```text
docs/vX.Y.Z/ → docs/archive/vX.Y.Z/
```

If inside a git repository, prefer:

```bash
git mv docs/vX.Y.Z docs/archive/vX.Y.Z
```

Otherwise use:

```bash
mv docs/vX.Y.Z docs/archive/vX.Y.Z
```

Do not move:

```text
docs/requirements/
docs/CONSTITUTION.md
```

Do not modify archived document states.
```

- [ ] **Step 4: Run full Skill contract test**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected:

```text
PASS: skill contracts
```

- [ ] **Step 5: Commit**

```bash
git add skills/dr/SKILL.md skills/dr/references/dr.md.tmpl skills/status/SKILL.md skills/doctor/SKILL.md skills/archive/SKILL.md tests/test-skill-contracts.sh
git commit -m "feat: add SDD DR status doctor archive skills"
```

---

### Task 7: End-to-End Smoke Test for MVP Acceptance Criteria

**Files:**
- Create: `tests/test-mvp-acceptance.sh`
- Modify: `tests/test-doctor-contract.sh`

**Interfaces:**
- Consumes all files created in Tasks 1-6.
- Produces executable acceptance smoke test `tests/test-mvp-acceptance.sh`.

- [ ] **Step 1: Write acceptance smoke test**

Create `tests/test-mvp-acceptance.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

# Plugin installation surface
assert_file_exists ".claude-plugin/plugin.json"
assert_file_exists "hooks/hooks.json"
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"

for skill in init new research prd spec plan code dr status doctor archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

# No forbidden centralized state implementation
if grep -R "\.sdd/state\.json" . \
  --exclude-dir=.git \
  --exclude='2026-07-12-sdd-plugin-mvp-workflow.md' \
  --exclude='2026-07-11-sdd-plugin-mvp-workflow-spec-design.md' \
  >/tmp/sdd-state-grep.out 2>/tmp/sdd-state-grep.err; then
  fail "implementation must not create or depend on .sdd/state.json"
fi

# Hook behavior from spec §9.6
bash tests/test-pre-tool-use.sh >/tmp/sdd-pretool.out
assert_contains "/tmp/sdd-pretool.out" "PASS: pre-tool-use hook"

# Shared parser behavior
bash tests/test-common-library.sh >/tmp/sdd-common.out
assert_contains "/tmp/sdd-common.out" "PASS: common library"

# Skill documentation contract
bash tests/test-skill-contracts.sh >/tmp/sdd-skills.out
assert_contains "/tmp/sdd-skills.out" "PASS: skill contracts"

printf 'PASS: MVP acceptance\n'
```

Modify `tests/test-doctor-contract.sh` to include hook and skill surface checks:

```bash
assert_file_exists "hooks/hooks.json"
assert_contains "hooks/hooks.json" "PreToolUse"
assert_contains "hooks/hooks.json" "SessionStart"
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"
```

- [ ] **Step 2: Run test to verify it fails if any prior task is incomplete**

Run:

```bash
bash tests/test-mvp-acceptance.sh
```

Expected if all prior tasks are complete:

```text
PASS: MVP acceptance
```

Expected if any prior task is incomplete: a `FAIL:` line naming the missing contract.

- [ ] **Step 3: Make smoke test executable**

Run:

```bash
chmod +x tests/test-mvp-acceptance.sh
```

- [ ] **Step 4: Run complete test suite**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected:

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
PASS: skill contracts
PASS: MVP acceptance
```

- [ ] **Step 5: Commit**

```bash
git add tests/test-mvp-acceptance.sh tests/test-doctor-contract.sh
git commit -m "test: add SDD MVP acceptance smoke test"
```

---

### Task 8: Final Verification and Documentation Consistency Review

**Files:**
- Modify: `README.md`
- Review only: all files created in Tasks 1-7

**Interfaces:**
- Consumes all created plugin files and tests.
- Produces final verified README and clean working tree after commit.

- [ ] **Step 1: Update README with exact install and verification commands**

Modify `README.md` so it contains this complete content:

```markdown
# SDD Plugin

SDD Plugin provides an MVP Specification Driven Development workflow for Claude Code.

## Install

From this repository root:

```bash
scripts/install-deps.sh
```

Then install the plugin with Claude Code's plugin installation flow for a local plugin directory.

## Commands

- `/sdd:init`
- `/sdd:new vX.Y.Z`
- `/sdd:research <topic>`
- `/sdd:prd`
- `/sdd:spec`
- `/sdd:plan <work-item>`
- `/sdd:code <NNN|work-item>`
- `/sdd:dr <tag> <title>`
- `/sdd:dr accept <id>`
- `/sdd:dr dismiss <id> <reason>`
- `/sdd:status`
- `/sdd:doctor`
- `/sdd:archive`

## Main Workflow

```text
/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive
```

## Code Change Workflow

```text
/sdd:dr fix|feat|chg|arch <title> → /sdd:dr accept <id> → /sdd:plan <id> → /sdd:code <NNN|id>
```

## Document Change Workflow

```text
/sdd:dr spec|doc|typo <title> → /sdd:dr accept <id> → /sdd:spec → DR closed
```

## Verification

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected output:

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
PASS: skill contracts
PASS: MVP acceptance
```

## MVP Non-Goals

- No `.sdd/state.json`.
- No multi-active-version support.
- No `src/**` hook gate.
- No machine parsing of `docs/CONSTITUTION.md` must/should rules.
- No git log CONFORMANCE scan.
- No PostToolUse progress accounting.
- No PreCompact state persistence.
- No automatic modification of `CLAUDE.md` or `AGENTS.md`.
```

- [ ] **Step 2: Run final verification commands**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected:

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
PASS: skill contracts
PASS: MVP acceptance
```

- [ ] **Step 3: Check no forbidden implementation paths exist**

Run:

```bash
test ! -e .sdd/state.json && test ! -d commands && test ! -d templates
```

Expected: command exits `0` with no output.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected output only includes the README change before committing:

```text
 M README.md
```

If other files appear, inspect them and commit only intended SDD Plugin files.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document SDD plugin verification workflow"
```

---

## Self-Review

**1. Spec coverage**

- §1 no centralized state and unique active version: covered by Global Constraints, Task 2, Task 7, Task 8.
- §2 document boundaries: covered by Tasks 4-6 templates and Skill instructions.
- §3 status model and parsing failures: covered by Task 2 `sdd_read_status` / `sdd_assert_status`, Task 3 hook behavior, Tasks 4-6 Skill contracts.
- §4 main and DR workflows: covered by Tasks 4-6 and README in Task 8.
- §5 Skill workflows: covered by Tasks 4-6.
- §6 Hook rules: covered by Task 3 and Task 7.
- §7 templates: covered by Tasks 1, 4, 5, 6.
- §8 status/doctor/archive: covered by Task 6.
- §9 acceptance criteria: covered by Task 7.
- §10 explicit non-goals: covered by Global Constraints and Task 8.

**2. Placeholder scan**

The plan avoids deferred implementation markers in execution steps. Template files intentionally contain angle-bracket fields such as `<topic>` and `<work-item>` because they are runtime templates, not omitted plan content.

**3. Type and interface consistency**

- `sdd_read_status`, `sdd_active_version_dir`, `sdd_next_plan_number`, `sdd_next_dr_number`, `sdd_json_target_path`, and `sdd_slug` are introduced in Task 2 and consumed consistently later.
- Hook target matching uses the spec's `NNN-feature-*` and `NNN-{fix,feat,chg,arch}-*` naming.
- Skill command names match the 11 required MVP commands.
