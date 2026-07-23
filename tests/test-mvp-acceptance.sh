#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

# Plugin installation surface
assert_file_exists ".claude-plugin/plugin.json"
assert_file_exists ".claude-plugin/marketplace.json"
assert_file_exists "hooks/hooks.json"
assert_file_exists "scripts/hooks/pre-tool-use.sh"
assert_file_exists "scripts/hooks/session-start.sh"

for skill in init new research prd spec plan code dr archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

assert_file_exists "assets/project/CLAUDE.md"
assert_file_exists "assets/template-packs/backend/research/template.md"
assert_file_exists "assets/template-packs/backend/research/quality.standard.md"
assert_file_exists "assets/template-packs/backend/prd/template.md"
assert_file_exists "assets/template-packs/backend/spec/feasibility.standard.md"
assert_file_exists "assets/template-packs/backend/plan/quality.standard.md"
assert_file_exists "assets/template-packs/backend/dr/template.md"
assert_file_exists "assets/template-packs/backend/dr/quality.standard.md"

# No forbidden centralized state implementation.
# Scan implementation and generated contract files only, so documentation that
# describes the prohibition is not treated as a violation.
if grep -R "\.sdd/state\.json" \
  .claude-plugin hooks scripts \
  --include='*.json' \
  --include='*.sh' \
  >/tmp/sdd-state-grep.out 2>/tmp/sdd-state-grep.err; then
  fail "implementation must not create or depend on centralized SDD state file"
fi

# Hook behavior from spec section 9.6
bash tests/test-pre-tool-use.sh >/tmp/sdd-pretool.out
assert_contains "/tmp/sdd-pretool.out" "PASS: pre-tool-use hook"

# Shared parser behavior
bash tests/test-common-library.sh >/tmp/sdd-common.out
assert_contains "/tmp/sdd-common.out" "PASS: common library"

# Skill documentation contract
bash tests/test-skill-contracts.sh >/tmp/sdd-skills.out
assert_contains "/tmp/sdd-skills.out" "PASS: skill contracts"

# Init project context contract
bash tests/test-init-project-context.sh >/tmp/sdd-init-context.out
assert_contains "/tmp/sdd-init-context.out" "PASS: init project context"

# DR filename 合同独立验证，并由 MVP 验收保留覆盖。
bash tests/test-dr-filename-contract.sh >/tmp/sdd-dr-filename.out
assert_contains "/tmp/sdd-dr-filename.out" "PASS: DR filename contract"

assert_file_not_exists "skills/doctor/SKILL.md"
assert_file_not_exists "skills/status/SKILL.md"

assert_not_contains "hooks/hooks.json" '"PostToolUse"'
assert_file_not_exists "scripts/hooks/post-tool-use.sh"
assert_file_not_exists "scripts/lib/sdd-review-runner.sh"
assert_contains "skills/review/SKILL.md" '/sdd:review'
assert_contains "skills/review/SKILL.md" 'doc-reviewer'
assert_contains "skills/spec/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/plan/SKILL.md" 'create：成功写入后必须显式调用 `/sdd:review <doc-path>`'
assert_contains "skills/review/SKILL.md" '当前 Skill 直接调用 `doc-reviewer` subagent'
assert_contains "skills/review/SKILL.md" '当 reviewer 返回 `requires_user_confirmation` 时，由当前 Skill 承接用户确认'
assert_contains "README.md" '`/sdd:review <doc-path>` 是统一 review 入口'
assert_contains "README.md" '新建 `research / prd / dr / spec / plan` 文档后，所属 Skill 会显式进入 `/sdd:review <doc-path>`'
assert_contains "README.md" '修改已有文档时，不自动 review；如需复审，请手工执行 `/sdd:review <doc-path>`。'
assert_contains "README.md" '系统不再依赖 `PostToolUse Hook` 或 shell runner 触发 review。'
assert_contains "README.md" '项目根目录缺失 `CLAUDE.md` 时生成默认 Claude Code 项目协作说明；已有时严格保留'
assert_contains "README.md" '`/sdd:init` 不处理 `AGENTS.md`。'
assert_contains "TESTING.md" '生成新 `research`、`prd`、`dr`、`spec`、`plan` 文档后，确认所属 Skill 显式进入 `/sdd:review <doc-path>`'
assert_contains "TESTING.md" '确认 `research`、`prd`、`dr` create 只触发 `quality`；`spec` 与 `plan` create 按顺序触发 `quality -> feasibility`。'
assert_contains "TESTING.md" '更新已有文档时，确认不会自动 review，只输出手工复审提示。'

printf 'PASS: MVP acceptance\n'
