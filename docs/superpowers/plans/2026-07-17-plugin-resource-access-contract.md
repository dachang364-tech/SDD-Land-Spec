# Plugin Resource Access Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a shared plugin resource access contract so hooks, scripts, skill-adjacent resource lookups, packaging checks, and docs all distinguish `Plugin Root` from `Project Root`, reject `PWD` fallback for plugin resources, and produce consistent diagnostics.

**Architecture:** Add one shared shell helper dedicated to plugin resource boundary handling, then route hook entrypoints and contract tests through it while preserving the existing project-resource flow in `sdd-common.sh`. The runtime contract must use explicit `CLAUDE_PLUGIN_ROOT` and explicit project-root context such as `SDD_PROJECT_ROOT`, rather than inferring project root from `PWD`. After the runtime contract is in place, update doctor/skill docs, packaging, and regression tests so the repository describes and verifies the same `Plugin Root` vs `Project Root` model end-to-end.

**Tech Stack:** Bash, shell helper libraries in `scripts/lib`, Claude plugin hooks in `hooks/hooks.json`, Markdown skill/docs, shell contract tests in `tests/*.sh`, packaged README generation in `scripts/package-local.sh`

## Global Constraints

- Any local resource access must be classified as either `Plugin Resource` or `Project Resource` before path resolution.
- Plugin resource access must use `Plugin Root` as the global boundary.
- Project resource access must use `Project Root` as the global boundary.
- `PWD` is not a valid authority boundary for plugin resource access.
- Resource-local resolution is allowed only after the boundary has already been established.
- `SKILL.md` platform loading remains out of scope; only post-load execution-time resource access is governed here.
- Missing boundary context, boundary mismatch, boundary escape, missing target resource, and ambiguous resource intent must all fail immediately.
- Plugin resource access must not silently fall back to `PWD`, `Project Root`, or any other undeclared base.
- Hooks, scripts, tests, doctor guidance, and packaged artifacts must all describe the same plugin-resource contract.

---

### Task 1: Add shared plugin resource helper and its unit contract tests

**Files:**
- Create: `scripts/lib/sdd-plugin-resources.sh`
- Modify: `tests/test-common-library.sh`
- Test: `tests/test-common-library.sh`

**Interfaces:**
- Consumes: Existing Bash library style from `scripts/lib/sdd-common.sh`; assertion helpers from `tests/test-common.sh`
- Produces:
  - `sdd_plugin_root() -> stdout <absolute-plugin-root>; exit 2 on missing root`
  - `sdd_project_root(project_root_arg?) -> stdout <absolute-project-root>; uses explicit argument or `SDD_PROJECT_ROOT`; exit 2 on missing project root context or non-directory`
  - `sdd_plugin_resource_path(plugin_root, relative_path) -> stdout <absolute-resource-path>; performs classification, relative-path validation, normalization, and boundary checks only`
  - `sdd_plugin_resource_require(plugin_root, relative_path) -> stdout <absolute-resource-path>; same checks as sdd_plugin_resource_path plus target-exists enforcement; exit 4 on missing target`
  - `sdd_project_resource_path(project_root, relative_path) -> stdout <absolute-project-resource-path>; performs classification, relative-path validation, normalization, and boundary checks only`
  - `sdd_project_resource_require(project_root, relative_path) -> stdout <absolute-project-resource-path>; same checks as sdd_project_resource_path plus target-exists enforcement; exit 4 on missing target`
  - `sdd_plugin_resource_local_path(plugin_root, consumer_path, relative_path) -> stdout <absolute-resource-path>; resolves from the consumer file directory, then validates the result remains inside Plugin Root`
  - `sdd_plugin_resource_local_require(plugin_root, consumer_path, relative_path) -> stdout <absolute-resource-path>; same checks as sdd_plugin_resource_local_path plus target-exists enforcement; exit 4 on missing target`

- [ ] **Step 1: Write the failing common-library tests**

Add these assertions near the end of `tests/test-common-library.sh` after the existing `sdd_slug` and `sdd_locator_valid` checks:

```bash
plugin_tmp="$(mktemp -d)"
project_tmp="$(mktemp -d)"
trap 'rm -rf "${tmp:-}" "$plugin_tmp" "$project_tmp"' EXIT
mkdir -p "$plugin_tmp/scripts/lib" "$plugin_tmp/scripts/hooks" "$plugin_tmp/skills/spec/references"
printf 'helper\n' > "$plugin_tmp/scripts/lib/helper.sh"
printf '#!/usr/bin/env bash\n' > "$plugin_tmp/scripts/hooks/session-start.sh"
printf 'tmpl\n' > "$plugin_tmp/skills/spec/references/spec.md.tmpl"
mkdir -p "$project_tmp/docs/versions/v0.1.0/specs"
printf '# spec\n' > "$project_tmp/docs/versions/v0.1.0/specs/spec.md"

export CLAUDE_PLUGIN_ROOT="$plugin_tmp"
plugin_root="$(sdd_plugin_root)"
[[ "$plugin_root" == "$plugin_tmp" ]] || fail "expected plugin root $plugin_tmp, got $plugin_root"

project_root="$(sdd_project_root "$project_tmp")"
[[ "$project_root" == "$project_tmp" ]] || fail "expected project root $project_tmp, got $project_root"

project_root_from_env="$(SDD_PROJECT_ROOT="$project_tmp" sdd_project_root)"
[[ "$project_root_from_env" == "$project_tmp" ]] || fail "expected env project root $project_tmp, got $project_root_from_env"

plugin_file="$(sdd_plugin_resource_path "$plugin_root" "scripts/lib/helper.sh")"
[[ "$plugin_file" == "$plugin_tmp/scripts/lib/helper.sh" ]] || fail "expected helper path, got $plugin_file"

plugin_template="$(sdd_plugin_resource_require "$plugin_root" "skills/spec/references/spec.md.tmpl")"
[[ "$plugin_template" == "$plugin_tmp/skills/spec/references/spec.md.tmpl" ]] || fail "expected template path, got $plugin_template"

plugin_local="$(sdd_plugin_resource_local_require "$plugin_root" "$plugin_tmp/scripts/hooks/session-start.sh" "../lib/helper.sh")"
[[ "$plugin_local" == "$plugin_tmp/scripts/lib/helper.sh" ]] || fail "expected local helper path, got $plugin_local"

project_file="$(sdd_project_resource_path "$project_root" "docs/versions/v0.1.0/specs/spec.md")"
[[ "$project_file" == "$project_tmp/docs/versions/v0.1.0/specs/spec.md" ]] || fail "expected project file path, got $project_file"

plugin_missing_path="$(sdd_plugin_resource_path "$plugin_root" "scripts/lib/missing.sh")"
[[ "$plugin_missing_path" == "$plugin_tmp/scripts/lib/missing.sh" ]] || fail "expected unresolved plugin path, got $plugin_missing_path"

project_missing_path="$(sdd_project_resource_path "$project_root" "docs/missing.md")"
[[ "$project_missing_path" == "$project_tmp/docs/missing.md" ]] || fail "expected unresolved project path, got $project_missing_path"

if CLAUDE_PLUGIN_ROOT= sdd_plugin_root >/tmp/sdd-plugin-root.out 2>/tmp/sdd-plugin-root.err; then
  fail "expected missing CLAUDE_PLUGIN_ROOT to fail"
fi
assert_contains "/tmp/sdd-plugin-root.err" "缺少 CLAUDE_PLUGIN_ROOT"

if sdd_project_root >/tmp/sdd-project-root.out 2>/tmp/sdd-project-root.err; then
  fail "expected missing Project Root to fail"
fi
assert_contains "/tmp/sdd-project-root.err" "缺少 Project Root"

if sdd_plugin_resource_path "$plugin_root" "../outside.sh" >/tmp/sdd-plugin-out.out 2>/tmp/sdd-plugin-out.err; then
  fail "expected boundary escape to fail"
fi
assert_contains "/tmp/sdd-plugin-out.err" "越出 Plugin Root"

if sdd_project_resource_path "$project_root" "../outside.md" >/tmp/sdd-project-out.out 2>/tmp/sdd-project-out.err; then
  fail "expected project boundary escape to fail"
fi
assert_contains "/tmp/sdd-project-out.err" "越出 Project Root"

if sdd_plugin_resource_require "$plugin_root" "scripts/lib/missing.sh" >/tmp/sdd-plugin-missing.out 2>/tmp/sdd-plugin-missing.err; then
  fail "expected missing plugin resource to fail"
fi
assert_contains "/tmp/sdd-plugin-missing.err" "插件资源不存在"

if sdd_project_resource_require "$project_root" "docs/missing.md" >/tmp/sdd-project-missing.out 2>/tmp/sdd-project-missing.err; then
  fail "expected missing project resource to fail"
fi
assert_contains "/tmp/sdd-project-missing.err" "项目资源不存在"

if sdd_plugin_resource_path "$plugin_root" "/tmp/absolute.sh" >/tmp/sdd-plugin-abs.out 2>/tmp/sdd-plugin-abs.err; then
  fail "expected absolute plugin path to fail"
fi
assert_contains "/tmp/sdd-plugin-abs.err" "插件资源路径必须使用相对路径"

if sdd_project_resource_path "$project_root" "/tmp/absolute.md" >/tmp/sdd-project-abs.out 2>/tmp/sdd-project-abs.err; then
  fail "expected absolute project path to fail"
fi
assert_contains "/tmp/sdd-project-abs.err" "项目资源路径必须使用相对路径"

if sdd_plugin_resource_path "$plugin_root" "" >/tmp/sdd-plugin-amb.out 2>/tmp/sdd-plugin-amb.err; then
  fail "expected ambiguous plugin resource intent to fail"
fi
assert_contains "/tmp/sdd-plugin-amb.err" "资源意图不明确"

if sdd_project_resource_path "$project_root" "" >/tmp/sdd-project-amb.out 2>/tmp/sdd-project-amb.err; then
  fail "expected ambiguous project resource intent to fail"
fi
assert_contains "/tmp/sdd-project-amb.err" "资源意图不明确"

if sdd_plugin_resource_path "$plugin_root" "docs/versions/v0.1.0/specs/spec.md" >/tmp/sdd-plugin-mismatch.out 2>/tmp/sdd-plugin-mismatch.err; then
  fail "expected plugin/project boundary mismatch to fail"
fi
assert_contains "/tmp/sdd-plugin-mismatch.err" "Boundary Mismatch"

if sdd_project_resource_path "$project_root" "skills/spec/references/spec.md.tmpl" >/tmp/sdd-project-mismatch.out 2>/tmp/sdd-project-mismatch.err; then
  fail "expected project/plugin boundary mismatch to fail"
fi
assert_contains "/tmp/sdd-project-mismatch.err" "Boundary Mismatch"
```

Also update the library import block near the top of `tests/test-common-library.sh` so it sources the new helper:

```bash
. scripts/lib/sdd-plugin-resources.sh
```

- [ ] **Step 2: Run the focused library test to verify it fails**

Run:

```bash
bash tests/test-common-library.sh
```

Expected: FAIL with `sdd_plugin_root: command not found` or equivalent because the new helper does not exist yet.

- [ ] **Step 3: Add the minimal shared helper implementation**

Create `scripts/lib/sdd-plugin-resources.sh` with exactly this content:

```bash
#!/usr/bin/env bash

sdd_plugin_root() {
  local root="${CLAUDE_PLUGIN_ROOT:-}"
  if [[ -z "$root" ]]; then
    printf '缺少 CLAUDE_PLUGIN_ROOT；无法建立 Plugin Root。\n' >&2
    return 2
  fi
  if [[ ! -d "$root" ]]; then
    printf 'CLAUDE_PLUGIN_ROOT 非目录：%s\n' "$root" >&2
    return 2
  fi
  python3 - "$root" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

sdd_project_root() {
  local root="${1:-${SDD_PROJECT_ROOT:-}}"
  if [[ -z "$root" ]]; then
    printf '缺少 Project Root；无法建立项目边界。\n' >&2
    return 2
  fi
  if [[ ! -d "$root" ]]; then
    printf 'Project Root 非目录：%s\n' "$root" >&2
    return 2
  fi
  python3 - "$root" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

sdd_plugin_resource_path() {
  local plugin_root="${1:-}"
  local relative_path="${2:-}"
  if [[ -z "$plugin_root" ]]; then
    printf '缺少 Plugin Root；无法解析插件资源。\n' >&2
    return 2
  fi
  if [[ -z "$relative_path" ]]; then
    printf '资源意图不明确：缺少插件资源相对路径。\n' >&2
    return 2
  fi
  python3 - "$plugin_root" "$relative_path" <<'PY'
import os
import sys
root = os.path.realpath(sys.argv[1])
raw = sys.argv[2]
if os.path.isabs(raw):
    print(f"插件资源路径必须使用相对路径：{raw}", file=sys.stderr)
    sys.exit(2)
if raw.startswith("docs/") or raw.startswith("src/"):
    print(f"Boundary Mismatch：插件资源请求误用了项目资源路径：{raw}", file=sys.stderr)
    sys.exit(3)
path = os.path.realpath(os.path.join(root, raw))
common = os.path.commonpath([root, path])
if common != root:
    print(f"插件资源越出 Plugin Root：{path}", file=sys.stderr)
    sys.exit(3)
print(path)
PY
}

sdd_plugin_resource_require() {
  local path
  path="$(sdd_plugin_resource_path "$1" "$2")" || return $?
  if [[ ! -e "$path" ]]; then
    printf '插件资源不存在：%s\n' "$path" >&2
    return 4
  fi
  printf '%s\n' "$path"
}

sdd_plugin_resource_local_path() {
  local plugin_root="${1:-}"
  local consumer_path="${2:-}"
  local relative_path="${3:-}"
  if [[ -z "$plugin_root" || -z "$consumer_path" ]]; then
    printf '缺少 Plugin Root 或 consumer 路径；无法执行局部插件资源解析。\n' >&2
    return 2
  fi
  if [[ -z "$relative_path" ]]; then
    printf '资源意图不明确：缺少局部插件资源相对路径。\n' >&2
    return 2
  fi
  python3 - "$plugin_root" "$consumer_path" "$relative_path" <<'PY'
import os
import sys
root = os.path.realpath(sys.argv[1])
consumer = os.path.realpath(sys.argv[2])
raw = sys.argv[3]
if os.path.isabs(raw):
    print(f"插件资源路径必须使用相对路径：{raw}", file=sys.stderr)
    sys.exit(2)
path = os.path.realpath(os.path.join(os.path.dirname(consumer), raw))
common = os.path.commonpath([root, path])
if common != root:
    print(f"插件资源越出 Plugin Root：{path}", file=sys.stderr)
    sys.exit(3)
print(path)
PY
}

sdd_plugin_resource_local_require() {
  local path
  path="$(sdd_plugin_resource_local_path "$1" "$2" "$3")" || return $?
  if [[ ! -e "$path" ]]; then
    printf '插件资源不存在：%s\n' "$path" >&2
    return 4
  fi
  printf '%s\n' "$path"
}

sdd_project_resource_path() {
  local project_root="${1:-}"
  local relative_path="${2:-}"
  if [[ -z "$project_root" ]]; then
    printf '缺少 Project Root；无法解析项目资源。\n' >&2
    return 2
  fi
  if [[ -z "$relative_path" ]]; then
    printf '资源意图不明确：缺少项目资源相对路径。\n' >&2
    return 2
  fi
  python3 - "$project_root" "$relative_path" <<'PY'
import os
import sys
root = os.path.realpath(sys.argv[1])
raw = sys.argv[2]
if os.path.isabs(raw):
    print(f"项目资源路径必须使用相对路径：{raw}", file=sys.stderr)
    sys.exit(2)
if raw.startswith("skills/") or raw.startswith("scripts/") or raw.startswith("hooks/"):
    print(f"Boundary Mismatch：项目资源请求误用了插件资源路径：{raw}", file=sys.stderr)
    sys.exit(3)
path = os.path.realpath(os.path.join(root, raw))
common = os.path.commonpath([root, path])
if common != root:
    print(f"项目资源越出 Project Root：{path}", file=sys.stderr)
    sys.exit(3)
print(path)
PY
}

sdd_project_resource_require() {
  local path
  path="$(sdd_project_resource_path "$1" "$2")" || return $?
  if [[ ! -e "$path" ]]; then
    printf '项目资源不存在：%s\n' "$path" >&2
    return 4
  fi
  printf '%s\n' "$path"
}
```

- [ ] **Step 4: Run the library test to verify it passes**

Run:

```bash
bash tests/test-common-library.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/sdd-plugin-resources.sh tests/test-common-library.sh
git commit -m "feat: add plugin resource helper library"
```

### Task 2: Route hook entrypoints through the shared plugin resource contract

**Files:**
- Modify: `hooks/hooks.json`
- Modify: `scripts/hooks/pre-tool-use.sh`
- Modify: `scripts/hooks/session-start.sh`
- Modify: `tests/test-pre-tool-use.sh`
- Test: `tests/test-pre-tool-use.sh`

**Interfaces:**
- Consumes:
  - `sdd_plugin_root()` from `scripts/lib/sdd-plugin-resources.sh`
  - `sdd_plugin_resource_require(plugin_root, relative_path)` from `scripts/lib/sdd-plugin-resources.sh`
  - Existing project-path gating logic in `scripts/hooks/pre-tool-use.sh`
- Produces:
  - `hooks/hooks.json` that passes explicit project-root context into hook entrypoints
  - `pre-tool-use.sh` that loads shared libraries via `Plugin Root`
  - `session-start.sh` that treats plugin dependencies as plugin resources, preserves existing dependency diagnostics, and treats project initialization as project resources
  - Hook tests proving behavior is independent of `PWD` for plugin resources and uses explicit `SDD_PROJECT_ROOT` for project resources

- [ ] **Step 1: Write the failing hook contract tests**

In `tests/test-pre-tool-use.sh`, replace the current helper invocation lines:

```bash
(cd "$root" && printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$OLDPWD/scripts/hooks/pre-tool-use.sh")
```

with this exact helper block so the test always injects `CLAUDE_PLUGIN_ROOT` explicitly and verifies the same plugin resource resolves identically across different `PWD` values:

```bash
plugin_root="$OLDPWD"
other_pwd="$(mktemp -d)"
trap 'rm -rf "${tmp:-}" "$other_pwd"' EXIT

run_hook() {
  local root="$1"
  local target="$2"
  (
    cd "$root"
    export CLAUDE_PLUGIN_ROOT="$plugin_root"
    export SDD_PROJECT_ROOT="$root"
    printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$plugin_root/scripts/hooks/pre-tool-use.sh"
  )
}

run_hook_abs_raw() {
  local root="$1"
  local target="$2"
  (
    cd "$root"
    export CLAUDE_PLUGIN_ROOT="$plugin_root"
    export SDD_PROJECT_ROOT="$root"
    printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$plugin_root/scripts/hooks/pre-tool-use.sh"
  )
}
```

Then append this missing-root check, the missing-project-root check, and the cross-`PWD` consistency check before the final `PASS` line:

```bash
if (cd "$tmp" && export CLAUDE_PLUGIN_ROOT="" && export SDD_PROJECT_ROOT="$tmp" && printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/prd.md"}}' | "$OLDPWD/scripts/hooks/pre-tool-use.sh") >/tmp/sdd-hook-root.out 2>/tmp/sdd-hook-root.err; then
  fail "expected missing CLAUDE_PLUGIN_ROOT to fail"
fi
assert_contains "/tmp/sdd-hook-root.err" "缺少 CLAUDE_PLUGIN_ROOT"

if (cd "$tmp" && export CLAUDE_PLUGIN_ROOT="$plugin_root" && export SDD_PROJECT_ROOT="" && printf '{"tool_input":{"file_path":"docs/versions/v0.1.0/prd.md"}}' | "$OLDPWD/scripts/hooks/pre-tool-use.sh") >/tmp/sdd-hook-project-root.out 2>/tmp/sdd-hook-project-root.err; then
  fail "expected missing Project Root to fail"
fi
assert_contains "/tmp/sdd-hook-project-root.err" "缺少 Project Root"

(cd "$tmp" && export CLAUDE_PLUGIN_ROOT="$plugin_root" && export SDD_PROJECT_ROOT="$tmp" && "$OLDPWD/scripts/hooks/session-start.sh" >/tmp/sdd-hook-pwd-a.out 2>/tmp/sdd-hook-pwd-a.err || true)
(cd "$other_pwd" && export CLAUDE_PLUGIN_ROOT="$plugin_root" && export SDD_PROJECT_ROOT="$other_pwd" && "$OLDPWD/scripts/hooks/session-start.sh" >/tmp/sdd-hook-pwd-b.out 2>/tmp/sdd-hook-pwd-b.err || true)
assert_contains "/tmp/sdd-hook-pwd-a.err" "当前项目尚未初始化"
assert_contains "/tmp/sdd-hook-pwd-b.err" "当前项目尚未初始化"
```

- [ ] **Step 2: Run the focused hook test to verify it fails**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected: FAIL because the current hook still computes its library path from `BASH_SOURCE[0]`, does not require explicit `CLAUDE_PLUGIN_ROOT`, and does not require explicit `SDD_PROJECT_ROOT` project context.

- [ ] **Step 3: Update both hook scripts to use `Plugin Root` for plugin resources**

Before editing the hook scripts, update `hooks/hooks.json` so each hook command passes explicit project-root context into execution:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SDD_PROJECT_ROOT=\"$PWD\" \"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh\""
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
            "command": "SDD_PROJECT_ROOT=\"$PWD\" \"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/pre-tool-use.sh\""
          }
        ]
      }
    ]
  }
}
```

Then replace the top of `scripts/hooks/pre-tool-use.sh`:

```bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/../.." && pwd)"
. "$root_dir/scripts/lib/sdd-common.sh"
```

with this exact bootstrap-aware block:

```bash
bootstrap_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/sdd-plugin-resources.sh"
. "$bootstrap_lib"
plugin_root="$(sdd_plugin_root)" || exit $?
. "$(sdd_plugin_resource_require "$plugin_root" "scripts/lib/sdd-common.sh")"
```

This bootstrap load is the one allowed initialization exception in the contract: it is used only to establish `Plugin Root` and must not be used as a general plugin resource fallback.

Replace the full contents of `scripts/hooks/session-start.sh` with this exact file:

```bash
#!/usr/bin/env bash
set -euo pipefail

bootstrap_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/sdd-plugin-resources.sh"
. "$bootstrap_lib"
plugin_root="$(sdd_plugin_root)" || exit $?
project_root="$(sdd_project_root)" || exit $?

missing=0
if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])superpowers([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 superpowers；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi

if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])spec-kit([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 spec-kit；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi

if [[ ! -f "$project_root/docs/CONSTITUTION.md" ]]; then
  printf 'SDD Plugin: 当前项目尚未初始化；如需使用 SDD 工作流，请运行 /sdd:init。\n' >&2
fi

exit 0
```

In `scripts/hooks/pre-tool-use.sh`, keep the existing `docs/` gating logic but add this line right before `target_path="$(sdd_json_target_path)"`:

```bash
project_root="$(sdd_project_root)" || exit $?
```

and change the Python invocation inside `normalize_target_path()` from:

```bash
python3 - "$PWD" "$raw" <<'PY'
```

to:

```bash
python3 - "$project_root" "$raw" <<'PY'
```

Do not change the existing `docs/versions/...` case logic after normalization.

- [ ] **Step 4: Run the hook test to verify it passes**

Run:

```bash
bash tests/test-pre-tool-use.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json scripts/hooks/pre-tool-use.sh scripts/hooks/session-start.sh tests/test-pre-tool-use.sh
git commit -m "fix: load hook resources from plugin root"
```

### Task 3: Add explicit plugin-resource contract tests and doctor skeleton checks

**Files:**
- Create: `tests/test-plugin-resource-access.sh`
- Modify: `tests/test-doctor-contract.sh`
- Modify: `tests/test-common.sh`
- Test: `tests/test-plugin-resource-access.sh`
- Test: `tests/test-doctor-contract.sh`

**Interfaces:**
- Consumes:
  - `sdd_plugin_root()` and `sdd_plugin_resource_require()` from `scripts/lib/sdd-plugin-resources.sh`
  - Existing doctor skeleton assertions in `tests/test-doctor-contract.sh`
- Produces:
  - Dedicated regression coverage for missing root, boundary escape, cross-`PWD` stability, boundary mismatch, ambiguous intent, and missing target behavior
  - Doctor contract checks that the plugin-resource helper is part of the installation skeleton
  - `assert_not_contains(path, needle)` helper available in all shell tests

- [ ] **Step 1: Write the failing plugin-resource and doctor tests**

First, append this helper to `tests/test-common.sh` after `assert_contains`:

```bash
assert_not_contains() {
  local path="$1"
  local needle="$2"
  [[ "$(<"$path")" != *"$needle"* ]] || fail "expected $path not to contain: $needle"
}
```

Then create `tests/test-plugin-resource-access.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
. scripts/lib/sdd-plugin-resources.sh

plugin_tmp="$(mktemp -d)"
project_a="$(mktemp -d)"
project_b="$(mktemp -d)"
trap 'rm -rf "$plugin_tmp" "$project_a" "$project_b"' EXIT

mkdir -p "$plugin_tmp/scripts/lib" "$plugin_tmp/scripts/hooks" "$plugin_tmp/skills/spec/references"
printf 'lib\n' > "$plugin_tmp/scripts/lib/helper.sh"
printf 'spec\n' > "$plugin_tmp/skills/spec/references/spec.md.tmpl"
printf '#!/usr/bin/env bash\n' > "$plugin_tmp/scripts/hooks/session-start.sh"
mkdir -p "$project_a/docs/versions/v0.1.0/specs" "$project_b/docs/versions/v0.1.0/specs"
printf '# constitution\n' > "$project_a/docs/CONSTITUTION.md"
printf '# constitution\n' > "$project_b/docs/CONSTITUTION.md"
printf '# spec\n' > "$project_a/docs/versions/v0.1.0/specs/spec.md"
printf '# spec\n' > "$project_b/docs/versions/v0.1.0/specs/spec.md"

plugin_root="$plugin_tmp"
resolved_plugin_root="$(CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_root)"
project_root_a="$(sdd_project_root "$project_a")"
project_root_b="$(sdd_project_root "$project_b")"

helper_path="$(CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "scripts/lib/helper.sh")"
[[ "$helper_path" == "$plugin_tmp/scripts/lib/helper.sh" ]] || fail "expected helper path, got $helper_path"

template_path="$(CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "skills/spec/references/spec.md.tmpl")"
[[ "$template_path" == "$plugin_tmp/skills/spec/references/spec.md.tmpl" ]] || fail "expected template path, got $template_path"

project_path_a="$(sdd_project_resource_require "$project_root_a" "docs/versions/v0.1.0/specs/spec.md")"
project_path_b="$(sdd_project_resource_require "$project_root_b" "docs/versions/v0.1.0/specs/spec.md")"
[[ "$project_path_a" == "$project_a/docs/versions/v0.1.0/specs/spec.md" ]] || fail "expected project A path, got $project_path_a"
[[ "$project_path_b" == "$project_b/docs/versions/v0.1.0/specs/spec.md" ]] || fail "expected project B path, got $project_path_b"

helper_from_a="$(cd "$project_a" && CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "scripts/lib/helper.sh")"
helper_from_b="$(cd "$project_b" && CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "scripts/lib/helper.sh")"
[[ "$helper_from_a" == "$helper_from_b" ]] || fail "expected plugin resource resolution to be stable across PWD"

local_hook="$(CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_local_require "$resolved_plugin_root" "$resolved_plugin_root/scripts/hooks/session-start.sh" "../lib/helper.sh")"
[[ "$local_hook" == "$plugin_tmp/scripts/lib/helper.sh" ]] || fail "expected local resolution path, got $local_hook"

if (cd "$project_a" && CLAUDE_PLUGIN_ROOT= sdd_plugin_root) >/tmp/sdd-plugin-contract-root.out 2>/tmp/sdd-plugin-contract-root.err; then
  fail "expected missing plugin root to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-root.err" "缺少 CLAUDE_PLUGIN_ROOT"

if sdd_project_root >/tmp/sdd-project-contract-root.out 2>/tmp/sdd-project-contract-root.err; then
  fail "expected missing project root to fail"
fi
assert_contains "/tmp/sdd-project-contract-root.err" "缺少 Project Root"

if CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "../outside.sh" >/tmp/sdd-plugin-contract-out.out 2>/tmp/sdd-plugin-contract-out.err; then
  fail "expected plugin boundary escape to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-out.err" "越出 Plugin Root"

if sdd_project_resource_require "$project_root_a" "../outside.md" >/tmp/sdd-project-contract-out.out 2>/tmp/sdd-project-contract-out.err; then
  fail "expected project boundary escape to fail"
fi
assert_contains "/tmp/sdd-project-contract-out.err" "越出 Project Root"

if CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_require "$resolved_plugin_root" "scripts/lib/missing.sh" >/tmp/sdd-plugin-contract-missing.out 2>/tmp/sdd-plugin-contract-missing.err; then
  fail "expected missing plugin file to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-missing.err" "插件资源不存在"

if sdd_project_resource_require "$project_root_a" "docs/missing.md" >/tmp/sdd-project-contract-missing.out 2>/tmp/sdd-project-contract-missing.err; then
  fail "expected missing project file to fail"
fi
assert_contains "/tmp/sdd-project-contract-missing.err" "项目资源不存在"

if CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_path "$resolved_plugin_root" "/tmp/absolute.sh" >/tmp/sdd-plugin-contract-abs.out 2>/tmp/sdd-plugin-contract-abs.err; then
  fail "expected absolute plugin path to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-abs.err" "插件资源路径必须使用相对路径"

if sdd_project_resource_path "$project_root_a" "/tmp/absolute.md" >/tmp/sdd-project-contract-abs.out 2>/tmp/sdd-project-contract-abs.err; then
  fail "expected absolute project path to fail"
fi
assert_contains "/tmp/sdd-project-contract-abs.err" "项目资源路径必须使用相对路径"

if CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_path "$resolved_plugin_root" "" >/tmp/sdd-plugin-contract-amb.out 2>/tmp/sdd-plugin-contract-amb.err; then
  fail "expected ambiguous plugin resource intent to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-amb.err" "资源意图不明确"

if sdd_project_resource_path "$project_root_a" "" >/tmp/sdd-project-contract-amb.out 2>/tmp/sdd-project-contract-amb.err; then
  fail "expected ambiguous project resource intent to fail"
fi
assert_contains "/tmp/sdd-project-contract-amb.err" "资源意图不明确"

if CLAUDE_PLUGIN_ROOT="$plugin_root" sdd_plugin_resource_path "$resolved_plugin_root" "docs/versions/v0.1.0/specs/spec.md" >/tmp/sdd-plugin-contract-mismatch.out 2>/tmp/sdd-plugin-contract-mismatch.err; then
  fail "expected plugin/project boundary mismatch to fail"
fi
assert_contains "/tmp/sdd-plugin-contract-mismatch.err" "Boundary Mismatch"

if sdd_project_resource_path "$project_root_a" "skills/spec/references/spec.md.tmpl" >/tmp/sdd-project-contract-mismatch.out 2>/tmp/sdd-project-contract-mismatch.err; then
  fail "expected project/plugin boundary mismatch to fail"
fi
assert_contains "/tmp/sdd-project-contract-mismatch.err" "Boundary Mismatch"

printf 'PASS: plugin resource access\n'
```

Make it executable with this exact command in a later implementation step:

```bash
chmod +x tests/test-plugin-resource-access.sh
```

Finally, add these assertions to `tests/test-doctor-contract.sh` after the existing hook path checks:

```bash
assert_file_exists "scripts/lib/sdd-plugin-resources.sh"
assert_contains "scripts/lib/sdd-plugin-resources.sh" "sdd_plugin_root()"
assert_contains "scripts/lib/sdd-plugin-resources.sh" "sdd_plugin_resource_require()"
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-plugin-resource-access.sh
```

Expected: FAIL because the helper file is not yet part of the doctor contract and the new test file does not exist yet.

- [ ] **Step 3: Add the new test file and make the doctor contract aware of the helper**

Create `tests/test-plugin-resource-access.sh` with the content from Step 1 and run:

```bash
chmod +x tests/test-plugin-resource-access.sh
```

Keep the `tests/test-common.sh` helper addition and the doctor assertions from Step 1 exactly as written.

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-plugin-resource-access.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test-common.sh tests/test-doctor-contract.sh tests/test-plugin-resource-access.sh
git commit -m "test: cover plugin resource access contract"
```

### Task 4: Update doctor and skill contracts to describe the new resource model

**Files:**
- Modify: `skills/doctor/SKILL.md`
- Modify: `skills/spec/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/prd/SKILL.md`
- Modify: `skills/dr/SKILL.md`
- Modify: `skills/archive/SKILL.md`
- Modify: `tests/test-skill-contracts.sh`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - The approved design spec in `docs/superpowers/specs/2026-07-17-plugin-resource-access-contract-design.md`
  - Existing wording patterns in the skill files above
- Produces:
  - Skill contracts that explicitly separate plugin-resource access from project-resource access
  - Doctor instructions that check plugin installation resources via `Plugin Root` and project consistency via `Project Root`
  - Contract tests that enforce the new wording

- [ ] **Step 1: Write the failing skill contract assertions**

Add these assertions in `tests/test-skill-contracts.sh` near the doctor and spec/plan sections:

```bash
assert_contains "skills/doctor/SKILL.md" "Plugin Root"
assert_contains "skills/doctor/SKILL.md" "Project Root"
assert_contains "skills/doctor/SKILL.md" "不允许对插件资源访问使用 PWD"
assert_contains "skills/spec/SKILL.md" "模板、references、脚本等插件内资源按 Plugin Root 语义访问"
assert_contains "skills/plan/SKILL.md" "读取项目文档时按 Project Root 语义访问"
assert_contains "skills/prd/SKILL.md" "技能被平台加载不等于其后续资源访问可以跳过边界判定"
assert_contains "skills/dr/SKILL.md" "插件资源与项目资源严格分离"
assert_contains "skills/archive/SKILL.md" "不得对插件资源访问使用 PWD 或其他隐式 fallback"
```

- [ ] **Step 2: Run the skill contract test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL because none of the new contract wording exists yet.

- [ ] **Step 3: Update doctor and the affected skill documents with minimal explicit contract wording**

Apply the following exact copy changes:

In `skills/doctor/SKILL.md`, insert this bullet list immediately after `## 1. Plugin installation checks` and before `Check existence of:`:

```md
- Plugin installation resources use `Plugin Root` as their boundary.
- Project consistency resources use `Project Root` as their boundary.
- 不允许对插件资源访问使用 `PWD` 或其他隐式 fallback。
- 如果调用方无法判断资源属于插件资源还是项目资源，必须立即失败并先建立明确边界。
```

In `skills/spec/SKILL.md`, add this bullet under `## Boundaries`:

```md
- 模板、references、脚本等插件内资源按 `Plugin Root` 语义访问；版本目录、PRD、spec 与其他项目文档按 `Project Root` 语义访问。
```

In `skills/plan/SKILL.md`, add this bullet under `## Boundaries`:

```md
- 读取模板、references 或插件脚本时按 `Plugin Root` 语义访问；读取项目文档时按 `Project Root` 语义访问。
```

In `skills/prd/SKILL.md`, add this bullet under `## Boundaries`:

```md
- 技能被平台加载不等于其后续资源访问可以跳过边界判定；插件内资源仍必须按 `Plugin Root` 访问。
```

In `skills/dr/SKILL.md`, add this bullet under `## Boundaries`:

```md
- 插件资源与项目资源严格分离；不得把 `PWD` 作为插件资源边界。
```

In `skills/archive/SKILL.md`, add this bullet under `## Boundaries`:

```md
- 不得对插件资源访问使用 `PWD`、`Project Root` 或其他隐式 fallback；插件内 helpers 与 references 必须按 `Plugin Root` 访问。
```

Do not add new sections; place each sentence in the nearest existing boundaries section only.

- [ ] **Step 4: Run the skill contract test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/doctor/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md skills/prd/SKILL.md skills/dr/SKILL.md skills/archive/SKILL.md tests/test-skill-contracts.sh
git commit -m "docs: codify plugin resource access boundaries"
```

### Task 5: Ensure packaging and user docs carry the same resource-access contract

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `scripts/package-local.sh`
- Modify: `tests/test-package-local.sh`
- Modify: `tests/test-skill-contracts.sh`
- Test: `tests/test-package-local.sh`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes:
  - Shared helper file path `scripts/lib/sdd-plugin-resources.sh`
  - Skill wording from Task 4
  - Packaged README heredoc in `scripts/package-local.sh`
- Produces:
  - README and packaged README language that explains the `Plugin Root` vs `Project Root` split
  - Packaging test coverage ensuring the new helper ships in artifacts
  - TESTING steps that tell reviewers how to validate behavior across different `PWD`

- [ ] **Step 1: Write the failing packaging and docs assertions**

Add these assertions to `tests/test-package-local.sh` after the existing package-root file checks:

```bash
if ! grep -Fxq "${package_root}/scripts/lib/sdd-plugin-resources.sh" "$archive_contents"; then
  fail "package must include plugin resource helper"
fi
```

Add these assertions to the README checks in `tests/test-skill-contracts.sh`:

```bash
assert_contains "README.md" "Plugin Root"
assert_contains "README.md" "Project Root"
assert_contains "README.md" "插件资源按 Plugin Root 访问，项目资源按 Project Root 访问"
assert_contains "TESTING.md" "不同 PWD 下访问插件资源时结果一致"
assert_contains "TESTING.md" "缺少 CLAUDE_PLUGIN_ROOT 时立即失败"
```

- [ ] **Step 2: Run the focused packaging/docs tests to verify they fail**

Run:

```bash
bash tests/test-package-local.sh && bash tests/test-skill-contracts.sh
```

Expected: FAIL because the helper is not yet asserted in packaging and the docs do not mention the new resource model.

- [ ] **Step 3: Update README, TESTING, and packaged README source**

In `README.md`, insert this paragraph immediately after the dependency plugin list:

```md
插件资源按 `Plugin Root` 访问，项目资源按 `Project Root` 访问。`PWD` 不能作为插件资源边界；如果缺少 `CLAUDE_PLUGIN_ROOT`，插件资源访问必须立即失败。
```

In `TESTING.md`, add these bullets to the manual verification section that covers hook/resource behavior:

```md
- 不同 `PWD` 下访问插件资源时结果一致。
- 缺少 `CLAUDE_PLUGIN_ROOT` 时立即失败。
- 插件资源不得回退到 `PWD` 或项目目录继续查找。
- 项目资源必须按 `Project Root` 解析，而不是借用插件路径语义。
- 当资源类型判断不明确时必须立即失败，而不是猜测 fallback。
```

In the heredoc README inside `scripts/package-local.sh`, insert this sentence immediately after the dependency plugin list:

```md
插件资源按 `Plugin Root` 访问，项目资源按 `Project Root` 访问。`PWD` 不能作为插件资源边界；如果缺少 `CLAUDE_PLUGIN_ROOT`，插件资源访问必须立即失败。
```

Do not change the install commands or marketplace steps.

- [ ] **Step 4: Run the packaging/docs tests to verify they pass**

Run:

```bash
bash tests/test-package-local.sh && bash tests/test-skill-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md TESTING.md scripts/package-local.sh tests/test-package-local.sh tests/test-skill-contracts.sh
git commit -m "docs: align packaging with plugin resource contract"
```

### Task 6: Run the full regression suite and tighten any exact-copy mismatches

**Files:**
- Modify: `tests/test-common-library.sh` (only if exact assertions need copy correction)
- Modify: `tests/test-pre-tool-use.sh` (only if exact assertions need copy correction)
- Modify: `tests/test-plugin-resource-access.sh` (only if exact assertions need copy correction)
- Modify: `tests/test-doctor-contract.sh` (only if exact assertions need copy correction)
- Modify: `tests/test-skill-contracts.sh` (only if exact assertions need copy correction)
- Modify: `tests/test-package-local.sh` (only if exact assertions need copy correction)
- Test: `tests/test-common-library.sh`
- Test: `tests/test-pre-tool-use.sh`
- Test: `tests/test-plugin-resource-access.sh`
- Test: `tests/test-doctor-contract.sh`
- Test: `tests/test-package-local.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: All runtime, docs, and packaging changes from Tasks 1-5
- Produces: Final green regression bundle proving the repository implements the approved plugin resource access contract without `PWD` fallback for plugin resources

- [ ] **Step 1: Run the full regression bundle**

Run:

```bash
bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-plugin-resource-access.sh && bash tests/test-doctor-contract.sh && bash tests/test-package-local.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected: PASS for all tests. If one fails because exact wording differs from the approved design, change only the exact copy or exact assertion needed to match the contract.

- [ ] **Step 2: Rebuild packaged artifacts as a final packaging verification**

Run:

```bash
bash scripts/package-local.sh
```

Expected: prints both `dist/sdd-plugin-v<version>.zip` and `dist/sdd-plugin-v<version>.tar.gz` without errors.

- [ ] **Step 3: Self-review plan/spec coverage before handoff**

Check these items manually and keep the plan aligned if any mismatch appears:

```text
- Helper enforces Plugin Root and rejects PWD fallback.
- Hook entrypoints load plugin-side libraries through Plugin Root.
- Project docs under docs/ still resolve as Project Root resources.
- Doctor and skill docs describe Plugin Root vs Project Root explicitly.
- Packaging includes the helper and preserves the same contract wording.
- Tests cover missing root, boundary escape, missing target, and cross-PWD consistency.
```

Expected: no uncovered spec requirement remains.

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/sdd-plugin-resources.sh scripts/hooks/pre-tool-use.sh scripts/hooks/session-start.sh scripts/package-local.sh README.md TESTING.md skills/doctor/SKILL.md skills/spec/SKILL.md skills/plan/SKILL.md skills/prd/SKILL.md skills/dr/SKILL.md skills/archive/SKILL.md tests/test-common.sh tests/test-common-library.sh tests/test-pre-tool-use.sh tests/test-plugin-resource-access.sh tests/test-doctor-contract.sh tests/test-package-local.sh tests/test-skill-contracts.sh
git commit -m "test: verify plugin resource access contract end to end"
```

## Self-Review

- Spec coverage:
  - `Plugin Root` / `Project Root` boundary definition is implemented in Task 1 and exercised through Tasks 2-6.
  - Immediate failure semantics for missing boundary context, boundary mismatch, boundary escape, ambiguous resource intent, and missing target are covered in Tasks 1, 3, and 6.
  - Post-load `SKILL.md` resource contract is documented in Task 4 and verified in Tasks 5-6.
  - Cross-`PWD` consistency, Project Root symmetry, resource-local resolution, and packaging parity are covered in Tasks 2, 3, 5, and 6.
  - The bootstrap exception for loading the first helper before `Plugin Root` is established is documented in Task 2 and must not expand into a general fallback rule.
- Placeholder scan:
  - No `TODO`, `TBD`, “similar to”, or unspecified “add tests” wording remains.
  - Each code-changing step contains the exact file content, exact assertions, or exact commands required.
- Type consistency:
  - Helper functions are introduced once in Task 1 and referenced by the same names/signatures in all later tasks.
  - The same contract vocabulary (`Plugin Root`, `Project Root`, `Execution-time Consumer`, `Boundary Mismatch`, ambiguous intent, no fallback) is reused consistently across docs and tests.

Plan complete and saved to `docs/superpowers/plans/2026-07-17-plugin-resource-access-contract.md`. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
