# Init Manual Dependency Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `/sdd:init` and `session-start` so dependency installation is reminder-only, while keeping SDD project skeleton initialization unchanged.

**Architecture:** Keep the behavior change narrowly scoped to init skill instructions, session-start hook messaging, and user-facing installation docs. Preserve `scripts/install-deps.sh` as an optional helper, then lock the new contract with focused shell tests that reject any regression back to forced script execution.

**Tech Stack:** Bash, shell contract tests, Markdown skill/docs, packaged README generation in `scripts/package-local.sh`

## Global Constraints

- `/sdd:init` must still create `docs/CONSTITUTION.md`, `docs/requirements/`, `docs/versions/`, and `docs/archive/`.
- `/sdd:init` must not execute `scripts/install-deps.sh`.
- `/sdd:init` must not fail just because `superpowers` or `spec-kit` is missing.
- `session-start` must continue to detect missing `superpowers` and `spec-kit`.
- `session-start` must only remind; it must not tell the user they must run `scripts/install-deps.sh`.
- `scripts/install-deps.sh` remains available as an optional helper script.
- README, TESTING, and packaged README must all describe the same install flow.
- Contract tests must block regressions back to “forced install-deps.sh” wording or behavior.

---

### Task 1: Update init and session-start contracts

**Files:**
- Modify: `skills/init/SKILL.md`
- Modify: `scripts/hooks/session-start.sh`
- Test: `tests/test-skill-contracts.sh`

**Interfaces:**
- Consumes: Current `/sdd:init` contract in `skills/init/SKILL.md`; current dependency warning strings in `scripts/hooks/session-start.sh`
- Produces: New reminder-only `/sdd:init` wording and new `session-start` dependency messages that later doc tasks must match verbatim

- [ ] **Step 1: Write the failing contract tests**

Add these assertions in `tests/test-skill-contracts.sh` near the existing init-skill checks:

```bash
assert_contains "skills/init/SKILL.md" "只提示用户安装依赖插件"
assert_contains "skills/init/SKILL.md" "不执行 `scripts/install-deps.sh`"
assert_contains "skills/init/SKILL.md" "`superpowers`"
assert_contains "skills/init/SKILL.md" "`spec-kit`"
assert_not_contains "skills/init/SKILL.md" "Run `scripts/install-deps.sh`."
assert_not_contains "skills/init/SKILL.md" "If dependency installation fails"
assert_contains "scripts/hooks/session-start.sh" "README 安装说明"
assert_not_contains "scripts/hooks/session-start.sh" "请运行 scripts/install-deps.sh"
```

- [ ] **Step 2: Run the contract test to verify it fails**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: FAIL on the new `skills/init/SKILL.md` or `session-start.sh` assertions because the old wording still requires `scripts/install-deps.sh`.

- [ ] **Step 3: Update `/sdd:init` and `session-start` with minimal wording changes**

Replace the init steps in `skills/init/SKILL.md` so the sequence becomes reminder-only. The updated section should read exactly like this:

```md
## Steps

1. Create project-level directories:
   - `docs/requirements/`
   - `docs/versions/`
   - `docs/archive/`
2. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.
3. Do not create `.sdd/state.json`.
4. 不创建任何版本目录或版本级 state.json。
5. Do not create `prd.md`, `specs/*.md`, `plans/*.md`, or `decisions/*.md`.
6. Do not modify `CLAUDE.md` or `AGENTS.md`.
7. 只提示用户安装依赖插件，不执行 `scripts/install-deps.sh`。
8. 提醒用户本插件依赖 `superpowers` 与 `spec-kit`，请按 README 安装说明手动安装；`scripts/install-deps.sh` 仅作为可选辅助脚本。
```

Then update `scripts/hooks/session-start.sh` to keep the dependency checks but change the messages to:

```bash
if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])superpowers([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 superpowers；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi

if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])spec-kit([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 spec-kit；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi
```

Do not change the `/sdd:init` reminder for uninitialized projects.

- [ ] **Step 4: Run the contract test to verify it passes**

Run:

```bash
bash tests/test-skill-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test-skill-contracts.sh skills/init/SKILL.md scripts/hooks/session-start.sh
git commit -m "fix: make init dependency installation manual"
```

### Task 2: Align README, TESTING, and packaged README copy

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`
- Modify: `scripts/package-local.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-package-local.sh`

**Interfaces:**
- Consumes: Reminder-only dependency contract produced by Task 1
- Produces: User-facing install instructions consistent across repo README, testing guide, and packaged README text generated by `scripts/package-local.sh`

- [ ] **Step 1: Write the failing doc/packaging tests**

Add these assertions in `tests/test-skill-contracts.sh` near the README / TESTING checks:

```bash
assert_contains "README.md" "用户自行安装"
assert_contains "README.md" "可选辅助脚本"
assert_contains "README.md" "`/sdd:init` 不会自动安装依赖插件"
assert_not_contains "README.md" "scripts/install-deps.sh"$'\n```'$'\n\n该脚本会检查并从 GitHub 仓库安装依赖 plugin，不依赖 Claude plugin marketplace：'
assert_contains "TESTING.md" '`/sdd:init` 创建 `docs/CONSTITUTION.md`、`docs/requirements/`、`docs/versions/`、`docs/archive/`。'
assert_contains "TESTING.md" '`/sdd:init` 不自动安装依赖插件'
assert_contains "TESTING.md" '`/sdd:init` 会提示用户手动安装 `superpowers` 与 `spec-kit`'
```

Add these assertions in `tests/test-package-local.sh` after the existing README checks:

```bash
assert_contains "$readme_tmp" "用户自行安装"
assert_contains "$readme_tmp" "可选辅助脚本"
assert_contains "$readme_tmp" "`/sdd:init` 不会自动安装依赖插件"
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-package-local.sh
```

Expected: FAIL on new README / TESTING / packaged README assertions because the old wording still centers `scripts/install-deps.sh`.

- [ ] **Step 3: Update README, TESTING, and packaged README source**

Edit `README.md` so the install section becomes:

```md
### 2. 安装依赖 plugin

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
```
```

Update `TESTING.md` in the “重点确认” section so the first bullet becomes exactly:

```md
- `/sdd:init` 创建 `docs/CONSTITUTION.md`、`docs/requirements/`、`docs/versions/`、`docs/archive/`。
- `/sdd:init` 不自动安装依赖插件。
- `/sdd:init` 会提示用户手动安装 `superpowers` 与 `spec-kit`。
```

Update the heredoc README text inside `scripts/package-local.sh` so its install section matches this wording:

```md
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

然后把本插件目录添加为本地 marketplace，并安装 `sdd`：
```

And add this sentence before the “## 使用” section in the packaged README heredoc:

```md
`/sdd:init` 不会自动安装依赖插件，只会提示用户完成上述安装。
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
bash tests/test-skill-contracts.sh && bash tests/test-package-local.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md TESTING.md scripts/package-local.sh tests/test-skill-contracts.sh tests/test-package-local.sh
git commit -m "docs: align install guidance with manual dependency flow"
```

### Task 3: Final regression verification for manual dependency flow

**Files:**
- Modify: `tests/test-skill-contracts.sh` (only if small assertion fixes are needed after full-suite run)
- Modify: `tests/test-package-local.sh` (only if small assertion fixes are needed after full-suite run)
- Test: `tests/test-doctor-contract.sh`
- Test: `tests/test-package-local.sh`
- Test: `tests/test-skill-contracts.sh`
- Test: `tests/test-mvp-acceptance.sh`

**Interfaces:**
- Consumes: Updated init skill, session-start messages, README/TESTING, packaged README content from Tasks 1-2
- Produces: Final green regression suite proving the repository no longer depends on forced `scripts/install-deps.sh` execution during `/sdd:init`

- [ ] **Step 1: Run the failing-to-passing regression bundle**

Run:

```bash
bash tests/test-doctor-contract.sh && bash tests/test-package-local.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

Expected: PASS for all tests. If any assertion fails because wording is slightly off, adjust only the exact assertion or exact copy needed to match the approved spec.

- [ ] **Step 2: Verify packaged artifacts still build cleanly**

Run:

```bash
rm -rf dist && bash scripts/package-local.sh
```

Expected:

```text
已生成本地包：
.../dist/sdd-plugin-v0.3.0.zip
.../dist/sdd-plugin-v0.3.0.tar.gz
```

- [ ] **Step 3: Run diff formatting check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 4: Commit final polish if needed**

If Step 1 required no further edits, skip this step.

If Step 1 required any last-mile assertion or copy fix, commit them with:

```bash
git add tests/test-skill-contracts.sh tests/test-package-local.sh README.md TESTING.md scripts/package-local.sh skills/init/SKILL.md scripts/hooks/session-start.sh
git commit -m "test: lock manual dependency install guidance"
```

## Spec Coverage Check

- Spec section 1-2 (background, goals): covered by Task 1 changing init and session-start from forced execution to reminder-only behavior.
- Spec section 4.1-4.3 (boundaries and optional helper script): covered by Task 1 init/session-start wording and Task 2 README/packaged README wording.
- Spec section 5.1-5.3 (new init flow and session-start strategy): covered by Task 1.
- Spec section 5.4-5.6 (README, packaged README, TESTING): covered by Task 2.
- Spec section 6-8 (affected files, acceptance, risks): covered by Tasks 1-3 through targeted tests and final regression bundle.

## Placeholder Scan

- No `TBD`, `TODO`, `待定`, `待补充`, or `path/to/file` placeholders remain.
- Every file path, assertion, command, and expected output is concrete.

## Type Consistency Check

- The plan consistently refers to dependency plugins as `superpowers` and `spec-kit`.
- The plan consistently refers to the optional helper script as `scripts/install-deps.sh`.
- The plan consistently uses the same affected file set described in the spec.
