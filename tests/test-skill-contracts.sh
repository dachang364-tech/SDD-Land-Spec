#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_not_matches() {
  local path="$1"
  local pattern="$2"
  ! grep -Eq -- "$pattern" "$path" || fail "expected $path not to match regex: $pattern"
}

for skill in init new research prd spec plan code dr triage archive; do
  assert_file_exists "skills/$skill/SKILL.md"
done

assert_file_exists "skills/review/SKILL.md"
assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_file_exists "agents/doc-reviewer.md"
assert_contains "skills/review/SKILL.md" 'description: 作为受管 SDD 文档的手工 review 入口'
assert_contains "skills/review/SKILL.md" '/sdd:review 是手工入口'
assert_contains "skills/review/SKILL.md" '当前 Skill 只负责手工触发 review、展示结果并承接用户回执'
assert_not_contains "skills/review/SKILL.md" '自动 review 由 `PostToolUse Hook`'
assert_not_contains "skills/review/SKILL.md" 'reviewer 在单次 subagent 调用内部完成有限轮次串行闭环'
assert_not_contains "skills/review/SKILL.md" '## Review admission check'
assert_not_contains "skills/review/SKILL.md" '## Review loop'
assert_not_contains "skills/review/SKILL.md" '## Repair Policy'
assert_not_contains "skills/review/SKILL.md" '有限 review loop'
assert_contains "skills/review/SKILL.md" '共享 review runner'
assert_contains "skills/review/SKILL.md" '手工入口'
assert_contains "skills/review/SKILL.md" '委托与回执'
assert_contains "skills/review/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/review/SKILL.md" '/sdd:review'
assert_contains "skills/review/SKILL.md" 'doc-reviewer'
assert_not_contains "skills/review/SKILL.md" '唯一的输入载荷'
assert_not_contains "skills/review/SKILL.md" '必须只返回一个 JSON 对象'
assert_not_contains "skills/review/SKILL.md" 'Review admission check'
assert_not_contains "skills/review/SKILL.md" '不进入 review loop、不写入目标文档'
assert_not_contains "skills/review/SKILL.md" '系统自动识别 `document_type`'
assert_not_contains "skills/review/SKILL.md" '系统自动决定 mode 或 mode 链路'
assert_contains "skills/review/references/reviewer-result.schema.json" '"document_type"'
assert_contains "skills/prd/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md`'
assert_contains "skills/spec/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/template.md`'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`'
assert_contains "skills/review/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/`'

assert_contains "skills/init/SKILL.md" "description: Initialize SDD project structure"
assert_contains "skills/init/SKILL.md" '`docs/CONSTITUTION.md` 已存在'
assert_contains "skills/init/SKILL.md" "继续初始化"
assert_contains "skills/init/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/` 资产'
assert_contains "skills/init/SKILL.md" '重新执行 `/sdd:init`'
assert_contains "skills/init/SKILL.md" '仅当 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 缺失时，复制 `CONSTITUTION.default.md`'
assert_contains "skills/init/SKILL.md" '如果 `${CLAUDE_PROJECT_DIR}/docs/CONSTITUTION.md` 已存在，则保留现有文件，不覆盖用户内容'
assert_not_contains "skills/init/SKILL.md" '2. Copy `CONSTITUTION.default.md` to `docs/CONSTITUTION.md`.'
assert_not_contains "skills/init/SKILL.md" "stop and say"
assert_contains "skills/init/SKILL.md" "docs/versions/"
assert_contains "skills/init/SKILL.md" '不创建任何版本目录或版本级 `state.json`'
assert_contains "skills/init/SKILL.md" "允许处于 0 active version 状态"
assert_contains "skills/init/SKILL.md" "只提示用户安装依赖插件"
assert_contains "skills/init/SKILL.md" '不执行 `scripts/install-deps.sh`'
assert_contains "skills/init/SKILL.md" '`superpowers`'
assert_contains "skills/init/SKILL.md" '`spec-kit`'
assert_not_contains "skills/init/SKILL.md" 'Run `scripts/install-deps.sh`.'
assert_not_contains "skills/init/SKILL.md" "If dependency installation fails"
assert_contains "skills/init/SKILL.md" "展示可选模板包列表"
assert_contains "skills/init/SKILL.md" '将所选模板包中的 `research / PRD / Spec / Plan / dr` 模板与标准完整展开到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`'
assert_contains "skills/init/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/dr/`'
assert_contains "skills/init/SKILL.md" '若用户选择未实现模板包，直接失败并说明当前不可用'
assert_contains "skills/init/SKILL.md" '如果用户未显式切换，则使用默认模板包'
assert_contains "skills/init/SKILL.md" '不要求把“用户选择了哪个模板包”写入项目元数据文件'
assert_contains "skills/init/SKILL.md" '${CLAUDE_PROJECT_DIR}/.sdd/templates/'
assert_contains "skills/init/SKILL.md" "sdd_list_template_packs"
assert_contains "skills/init/SKILL.md" "sdd_default_template_pack"
assert_contains "skills/init/SKILL.md" "sdd_copy_template_pack"
assert_contains "skills/init/SKILL.md" '调用 `sdd_list_template_packs "$plugin_root"` 获取模板包列表'
assert_contains "skills/init/SKILL.md" '将模板包列表展示给用户并请求选择'
assert_contains "skills/init/SKILL.md" '如果用户未显式切换，则调用 `sdd_default_template_pack` 取得默认值'
assert_contains "skills/init/SKILL.md" '校验所选值属于可用模板包'
assert_contains "skills/init/SKILL.md" '只有在模板包选择完成后才调用 `sdd_copy_template_pack`'
assert_contains "skills/init/SKILL.md" '如果 `sdd_copy_template_pack` 返回非零，停止并报告失败'
assert_not_contains "skills/init/SKILL.md" '初始化成功（即使模板复制失败）'
assert_contains "scripts/lib/sdd-template-assets.sh" "sdd_list_template_packs"
assert_contains "scripts/lib/sdd-template-assets.sh" "sdd_default_template_pack"
assert_contains "scripts/lib/sdd-template-assets.sh" "sdd_copy_template_pack"
assert_not_contains "skills/init/SKILL.md" 'Do not create `.sdd/state.json`.'
assert_contains "scripts/hooks/session-start.sh" "claude plugin list"
assert_contains "scripts/hooks/session-start.sh" "superpowers([[:space:]]|$)"
assert_contains "scripts/hooks/session-start.sh" "spec-kit([[:space:]]|$)"
assert_contains "scripts/hooks/session-start.sh" "README 安装说明"
assert_contains "scripts/hooks/session-start.sh" "手动安装该插件"
assert_not_contains "scripts/hooks/session-start.sh" "scripts/install-deps.sh"

assert_contains "skills/new/SKILL.md" "description: Create the unique active SDD version directory"
assert_contains "skills/new/SKILL.md" "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/state.json"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/research/"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/prd/"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/spec/"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/plan/"
assert_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/dr/"
assert_contains "skills/new/SKILL.md" '"state": "active"'
assert_contains "skills/new/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_not_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/specs/"
assert_not_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/plans/"
assert_not_contains "skills/new/SKILL.md" "docs/versions/vX.Y.Z/decisions/"

assert_contains "skills/research/SKILL.md" 'description: 创建或更新项目级 SDD research 文档。用户执行 `/sdd:research <topic>` 时使用。'
assert_file_not_exists "skills/research/references/research.md.tmpl"
assert_contains "skills/research/SKILL.md" 'docs/versions/vX.Y.Z/research/<type>-<YYYY-MM-DD>-<slug>.md'
assert_contains "skills/research/SKILL.md" 'research 文档没有状态机制'
assert_contains "skills/research/SKILL.md" '同名文档存在时，用户确认后可直接更新'
assert_not_contains "skills/research/SKILL.md" 'docs/requirements/'

assert_contains "skills/prd/SKILL.md" 'description: 创建或更新产品需求文档。用户执行 `/sdd:prd` 时使用。'
assert_file_not_exists "skills/prd/references/prd.md.tmpl"
assert_not_contains "skills/prd/SKILL.md" 'skills/prd/references/prd.md.tmpl'
assert_contains "skills/prd/SKILL.md" 'docs/versions/vX.Y.Z/prd/prd.md'
assert_contains "skills/prd/SKILL.md" '如果 `prd/prd.md` 已存在，默认不直接覆盖；必须先与用户确认，再更新同一文件。'
assert_contains "skills/prd/SKILL.md" '`prd` 不走 `DR` 变更门。'
assert_contains "skills/prd/SKILL.md" '只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md`'
assert_contains "skills/prd/SKILL.md" '如果 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/` 下必要文件缺失，则直接失败'
assert_contains "skills/prd/SKILL.md" '用户确认并完成有效复审前，不得绕过该结果推进流程'

assert_no_legacy_docs_v_paths() {
  local path="$1"
  local matches
  matches="$(grep -Eo 'docs/v[^[:space:]`)"]*' "$path" | grep -Ev '^docs/versions(/|$)' || true)"
  [[ -z "$matches" ]] || fail "expected $path not to contain legacy docs/v paths: $matches"
}

for template in \
  "skills/dr/references/dr.md.tmpl"; do
  assert_not_contains "$template" "path/to/"
done

assert_contains "skills/spec/SKILL.md" 'description: 创建或更新功能规格文档。用户执行 `/sdd:spec` 时使用。'
assert_file_not_exists "skills/spec/references/spec.md.tmpl"
assert_not_contains "skills/spec/SKILL.md" 'skills/spec/references/spec.md.tmpl'
assert_contains "skills/spec/SKILL.md" "docs/versions/vX.Y.Z/spec/<spec-name>.md"
assert_contains "skills/spec/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/spec/SKILL.md" "## 文档引用"
assert_contains "skills/spec/SKILL.md" "[prd.md](../prd/prd.md)"
assert_contains "skills/spec/SKILL.md" "v0.2.0:spec/archive.md"
assert_contains "skills/spec/SKILL.md" '用户确认审批后，将状态切换为 `approved`；reviewer 的候选改写或确认项必须先由用户明确确认、写回并重新复审，普通审批不得绕过。'
assert_contains "skills/spec/SKILL.md" "closed_reason: document-updated"
assert_contains "skills/spec/SKILL.md" 'code-class DR 必须保持 `accepted`'
assert_contains "skills/spec/SKILL.md" "不再使用独立 `## 关联 DRs`"
assert_contains "skills/spec/SKILL.md" '只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 下的模板与标准'
assert_contains "skills/spec/SKILL.md" '自动按顺序触发 `quality -> feasibility`'
assert_contains "skills/spec/SKILL.md" '如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产'
assert_contains "skills/spec/SKILL.md" 'reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/spec/` 中的模板与标准，与生成阶段使用同一套项目级有效资产'
assert_contains "skills/spec/SKILL.md" '停止，不执行 `feasibility`'
assert_contains "skills/spec/SKILL.md" '普通审批不得绕过'
assert_not_contains "skills/spec/SKILL.md" '用户确认后，将状态切换为 `approved`'

assert_contains "skills/plan/SKILL.md" 'description: 基于已批准 spec 或已接受 code-class DR 创建或更新实现计划。用户执行 `/sdd:plan <work-item>` 时使用。'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/quality.standard.md`'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/feasibility.standard.md`'
assert_not_contains "skills/plan/SKILL.md" 'skills/plan/references/plan.md.tmpl'
assert_contains "skills/plan/SKILL.md" '如果 `<work-item>` 匹配 `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`，直接拒绝：`文档类 DR 不生成实现计划，不执行 /sdd:code。`'
assert_contains "skills/plan/SKILL.md" '如果 `<work-item>` 看起来像 DR（以三位数字和连字符开头）'
assert_contains "skills/plan/SKILL.md" '不得落回 spec 模式。'
assert_contains "skills/plan/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/plan/SKILL.md" "## 文档引用"
assert_contains "skills/plan/SKILL.md" 'plan 引用 spec 时，关系应为 `implements`'
assert_contains "skills/plan/SKILL.md" '不得使用 `modifies`、`replaces`、`deprecates`'
assert_contains "skills/plan/SKILL.md" "Self-Review"
assert_file_not_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/plan/SKILL.md" "引用同版本文档时，只写相对 Markdown link，不写版本 locator。"
assert_contains "skills/plan/SKILL.md" '引用跨版本文档时，必须同时写相对 Markdown link 和版本 locator，例如 `v0.2.0:plan/001-archive.md`。'
assert_contains "skills/plan/SKILL.md" '只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/` 下的模板与标准'
assert_contains "skills/plan/SKILL.md" '生成必须使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`'
assert_contains "skills/plan/SKILL.md" '读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/quality.standard.md`'
assert_contains "skills/plan/SKILL.md" '读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/feasibility.standard.md`'
assert_contains "skills/plan/SKILL.md" '`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/template.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/quality.standard.md`、`${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/feasibility.standard.md` 任一缺失，则直接失败'
assert_contains "skills/plan/SKILL.md" '自动按顺序触发 `quality -> feasibility`'
assert_contains "skills/plan/SKILL.md" '如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产'
assert_contains "skills/plan/SKILL.md" 'reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/plan/` 中的模板与标准，与生成阶段使用同一套项目级有效资产'
assert_contains "skills/plan/SKILL.md" '停止，不执行 `feasibility`'
assert_contains "skills/plan/SKILL.md" '确认项写回后必须重新复审'
assert_not_contains "skills/plan/SKILL.md" 'skills/plan/references/plan.md.tmpl'

assert_contains "skills/code/SKILL.md" "description: Execute an SDD implementation plan or eligible lightweight fix DR"
assert_contains "skills/code/SKILL.md" "docs/versions/vX.Y.Z/plan/NNN-*.md"
assert_contains "skills/code/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/code/SKILL.md" '基于 `## 文档引用` 验证 plan'
assert_contains "skills/code/SKILL.md" '高质量模式：`superpowers:subagent-driven-development`'
assert_contains "skills/code/SKILL.md" '快速模式：`superpowers:executing-plans`'
assert_contains "skills/code/SKILL.md" 'plan 状态从 `planned` 切换为 `coding`'
assert_contains "skills/code/SKILL.md" 'verification 通过后，将 plan 状态切换为 `done`'
assert_contains "skills/code/SKILL.md" "verification passes"
assert_contains "skills/code/SKILL.md" 'code_required: yes'
assert_contains "skills/code/SKILL.md" 'associated DR remains accepted'
assert_contains "skills/code/SKILL.md" 'closed_reason: committed'
assert_contains "skills/code/SKILL.md" "If input is a complete plan basename, match the same \`.md\` basename and use plan execution mode. This lookup occurs before DR-like validation"
assert_contains "skills/code/SKILL.md" "If input matches a document-class DR id \`^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$\`, refuse"
assert_contains "skills/code/SKILL.md" "If input is DR-like (starts with three digits and a hyphen) but is not a valid full DR ID, fail explicitly"
assert_contains "skills/code/SKILL.md" "001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>"
assert_contains "skills/code/SKILL.md" "Do not fall through to plan or feature-name lookup."
assert_contains "skills/code/SKILL.md" "If input matches a code-class DR id \`^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$\`"
assert_contains "skills/code/SKILL.md" "first check for a matching plan by exact DR ID suffix"
assert_contains "skills/code/SKILL.md" "If zero plans match and no eligible lightweight fix DR matches"
assert_contains "skills/code/SKILL.md" "plan_required: no"
assert_contains "skills/code/SKILL.md" 'use lightweight fix DR mode only when DR `tag` is `fix` and `plan_required: no`'
assert_contains "skills/code/SKILL.md" "lightweight fix DR"
assert_contains "skills/code/SKILL.md" "no plan status is changed"
assert_contains "skills/code/SKILL.md" "DR remains accepted"

assert_contains "skills/triage/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/triage/SKILL.md" "reference issue"
assert_contains "skills/triage/SKILL.md" "关联 DRs"

assert_contains "skills/dr/SKILL.md" 'description: 创建、接受或驳回 SDD Decision Record。用户执行 `/sdd:dr <tag> <title>`、`/sdd:dr accept <id>` 或 `/sdd:dr dismiss <id> <reason>` 时使用。'
assert_contains "skills/dr/SKILL.md" "fix | feat | chg | arch | spec | doc | typo"
assert_contains "skills/dr/SKILL.md" "drafting → accepted"
assert_contains "skills/dr/SKILL.md" "class"
assert_contains "skills/dr/SKILL.md" "spec_change"
assert_contains "skills/dr/SKILL.md" "plan_required"
assert_contains "skills/dr/SKILL.md" "code_required"
assert_contains "skills/dr/SKILL.md" "fix | code | no | yes | yes"
assert_contains "skills/dr/SKILL.md" "简单实现 bug 可以由用户选择轻量 fix 流程"
assert_contains "skills/dr/SKILL.md" "plan_required: no\`：运行 \`/sdd:code <id>\`"
assert_contains "skills/dr/SKILL.md" "之后根据 \`plan_required\` 进入 \`/sdd:plan <id>\` 或 \`/sdd:code <id>\`"
assert_contains "skills/dr/SKILL.md" "feat | code | yes | yes | yes"
assert_contains "skills/dr/SKILL.md" "chg | code | yes | yes | yes"
assert_contains "skills/dr/SKILL.md" "arch | code | maybe | yes | yes"
assert_contains "skills/dr/SKILL.md" "spec | document | yes | no | no"
assert_contains "skills/dr/SKILL.md" "doc | document | maybe | no | no"
assert_contains "skills/dr/SKILL.md" "typo | document | no | no | no"
assert_contains "skills/dr/SKILL.md" "spec_change: no\`、\`plan_required: no\`：运行 \`/sdd:code <id>\`"
assert_contains "skills/dr/SKILL.md" "class: document\`：运行 \`/sdd:spec\` 或对应文档 Skill，不进入 \`/sdd:plan\`"
assert_contains "skills/dr/SKILL.md" "docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md"
assert_contains "skills/dr/SKILL.md" "生成版本内递增 DR 编号 \`NNN\`；如果还没有 DR，则使用 \`001\`。"
assert_contains "skills/dr/SKILL.md" "若下一个编号会超过 \`999\`，则直接失败。"
assert_contains "skills/dr/SKILL.md" "将标题 slugify 为非空 lowercase kebab-case"
assert_contains "skills/dr/SKILL.md" "\`DR ID\` 指去掉 \`.md\` 后的完整 DR basename"
assert_contains "skills/dr/SKILL.md" "标题标识格式固定为 \`DR-NNN-<tag>\`"
assert_contains "skills/dr/SKILL.md" "\`/sdd:dr accept 001-fix-login-null\`"
assert_contains "skills/dr/SKILL.md" "\`/sdd:dr dismiss 001-fix-login-null <reason>\`"
assert_contains "skills/dr/SKILL.md" "不兼容 \`<tag>-NNNN-<slug>\` 旧格式"
assert_contains "skills/dr/references/dr.md.tmpl" "# DR-NNN-<tag>：<标题>"
assert_not_contains "skills/dr/references/dr.md.tmpl" "# DR-<tag>-NNNN：<标题>"
assert_contains "skills/dr/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/dr/SKILL.md" "## 文档引用"
assert_contains "skills/dr/SKILL.md" "## 影响资产\` 只做摘要"
assert_contains "skills/dr/SKILL.md" "project:requirements/<file>.md"
assert_contains "skills/dr/SKILL.md" "closed_reason: dismissed"
assert_contains "skills/dr/SKILL.md" "只按完整 \`DR ID\` 精确查找"
assert_contains "skills/dr/SKILL.md" "无效 DR ID、缺失 DR 或旧格式 \`<tag>-NNNN-<slug>\` 均必须显式失败"
assert_file_exists "skills/dr/references/dr.md.tmpl"
assert_contains "skills/dr/references/dr.md.tmpl" "- closed_reason: null"
assert_contains "skills/dr/references/dr.md.tmpl" "- class：code | document"
assert_contains "skills/dr/references/dr.md.tmpl" "- spec_change：yes | no | maybe"
assert_contains "skills/dr/references/dr.md.tmpl" "- plan_required：yes | no"
assert_contains "skills/dr/references/dr.md.tmpl" "- code_required：yes | no"
assert_contains "skills/dr/references/dr.md.tmpl" "## 文档引用"
assert_contains "skills/dr/references/dr.md.tmpl" "| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |"
assert_contains "skills/dr/references/dr.md.tmpl" "| 未声明。 | - | - | - | - |"
assert_contains "skills/dr/references/dr.md.tmpl" "## 7. 影响资产"
assert_contains "skills/dr/references/dr.md.tmpl" "### 4.1 契约影响"
assert_contains "skills/dr/references/dr.md.tmpl" "### 4.2 实现影响"
assert_contains "skills/dr/references/dr.md.tmpl" "### 4.3 文档影响"
assert_contains "skills/dr/references/dr.md.tmpl" "## 6. 验证方式"
assert_contains "skills/dr/references/dr.md.tmpl" "| 资产 | 章节 / ID |"

assert_contains "skills/triage/SKILL.md" "description: Triage user questions after implementation, review, or testing"
assert_contains "skills/triage/SKILL.md" "does not execute the chosen path"
assert_contains "skills/triage/SKILL.md" "扫描 docs/versions/v*/state.json"
assert_contains "skills/triage/SKILL.md" "prd existence"
assert_contains "skills/triage/SKILL.md" "spec/*.md"
assert_contains "skills/triage/SKILL.md" "plan/*.md"
assert_contains "skills/triage/SKILL.md" "dr/*.md"
assert_contains "skills/triage/SKILL.md" "reference issue"
assert_contains "skills/triage/SKILL.md" "unclear, needs user choice"
assert_contains "skills/triage/SKILL.md" "/sdd:triage --deep"
assert_contains "skills/triage/SKILL.md" "explain only，不创建 DR"
assert_contains "skills/triage/SKILL.md" "/sdd:dr fix <title>"
assert_contains "skills/triage/SKILL.md" "/sdd:plan <id>"
assert_contains "skills/triage/SKILL.md" "/sdd:dr feat|chg <title>"

assert_contains "README.md" "/sdd:triage"
assert_contains "README.md" "用户疑问分诊"
assert_contains "README.md" "轻量 fix DR"
assert_contains "README.md" "Markdown 链接"
assert_contains "README.md" "最终由用户选择"
assert_contains "README.md" "用户自行安装"
assert_contains "README.md" "可选辅助脚本"
assert_contains "README.md" '`/sdd:init` 不会自动安装依赖插件'
assert_contains "README.md" 'scripts/install-deps.sh'
assert_contains "README.md" '生成版本内调研资料：`docs/versions/vX.Y.Z/research/*.md`'
assert_contains "README.md" '生成无状态 PRD：`docs/versions/vX.Y.Z/prd/prd.md`'
assert_contains "README.md" '生成 Functional Specification：`docs/versions/vX.Y.Z/spec/*.md`'
assert_contains "README.md" '生成 Implementation Plan：`docs/versions/vX.Y.Z/plan/NNN-*.md`'
assert_contains "README.md" 'docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md'
assert_contains "README.md" '`plan/002-001-fix-login-null.md`'
assert_not_contains "README.md" '/sdd:status'
assert_not_contains "README.md" '/sdd:doctor'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/prd.md'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/specs/spec.md'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/plans/NNN-*.md'

assert_file_not_exists "skills/status/SKILL.md"
assert_file_not_exists "skills/doctor/SKILL.md"

assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" 'active version 的 `spec/*.md` 至少一份。'
assert_contains "skills/archive/SKILL.md" '所有 `spec/*.md` 的 Markdown 头部状态必须为 `approved`'
assert_contains "skills/archive/SKILL.md" '所有 `plan/*.md` 的 Markdown 头部状态必须为 `done`'
assert_contains "skills/archive/SKILL.md" '所有 `dr/*.md` 的 Markdown 头部状态必须为 `closed`'
assert_contains "skills/archive/SKILL.md" '`prd/prd.md` 缺失不阻止归档'
assert_contains "skills/archive/SKILL.md" '枚举 active version 内现有的 `prd/prd.md`、`spec/*.md`、`plan/*.md`、`dr/*.md`'

assert_contains "README.md" "class / spec_change / plan_required / code_required"
assert_contains "README.md" "spec-changing code-class DR"
assert_contains "README.md" 'fix DR 通常使用 `spec_change: no`'
assert_contains "README.md" '创建唯一活跃版本目录 `docs/versions/vX.Y.Z/`'
assert_contains "README.md" '生成无状态 PRD：`docs/versions/vX.Y.Z/prd/prd.md`'
assert_contains "README.md" '生成 Functional Specification：`docs/versions/vX.Y.Z/spec/*.md`'
assert_contains "README.md" '生成 Implementation Plan：`docs/versions/vX.Y.Z/plan/NNN-*.md`'
assert_contains "README.md" 'docs/versions/vX.Y.Z/state.json'
assert_contains "README.md" 'docs/versions/v0.2.0/research/'
assert_contains "README.md" 'docs/versions/vX.Y.Z/ARCHIVE.md'
assert_contains "README.md" 'docs/archive/INDEX.md'
assert_contains "README.md" '.sdd/templates/'
assert_contains "README.md" '/sdd:review'
assert_contains "README.md" 'agents/doc-reviewer.md'
assert_not_contains "README.md" 'doc Reviewer-Subagent'
assert_not_contains "README.md" '创建唯一活跃版本目录 `docs/vX.Y.Z/`'
assert_not_contains "README.md" '生成无状态 PRD：`docs/vX.Y.Z/prd.md`'
assert_not_contains "README.md" 'docs/vX.Y.Z/specs/spec.md'
assert_not_contains "README.md" 'docs/vX.Y.Z/plans/NNN-feature-*.md'
assert_not_contains "README.md" 'docs/versions/vX.Y.Z/plans/NNN-feature-*.md'
assert_not_contains "README.md" 'sdd-plugin-mvp-workflow'
assert_no_legacy_docs_v_paths "README.md"
assert_contains "TESTING.md" 'mkdir -p "$tmp/docs/versions/v0.1.0/spec" "$tmp/docs/versions/v0.1.0/plan" "$tmp/docs/versions/v0.1.0/dr" "$tmp/docs/versions/v0.1.0/prd"'
assert_contains "TESTING.md" 'docs/versions/v0.1.0/spec/spec.md'
assert_contains "TESTING.md" 'docs/versions/v0.1.0/prd/prd.md'
assert_contains "TESTING.md" 'docs/versions/v0.1.0/plan/001-login.md'
assert_contains "TESTING.md" 'research / prd / dr / spec / plan'
assert_contains "TESTING.md" 'archived version 下的文档不能执行 `/sdd:review`'
assert_contains "TESTING.md" '`/sdd:review <doc-path>` 会按路径自动识别 `research / prd / dr / spec / plan` 类型'
assert_contains "TESTING.md" '`/sdd:code <plan>` 依赖 plan 的 `## 文档引用` 闭包仍然完整'
assert_not_contains "TESTING.md" '/sdd:status'
assert_not_contains "TESTING.md" '/sdd:doctor'
assert_not_contains "TESTING.md" 'docs/versions/v0.1.0/specs/spec.md'
assert_not_contains "TESTING.md" 'docs/versions/v0.1.0/plans/001-login.md'
assert_contains "CONSTITUTION.default.md" '代码类 DR 默认使用 `plan_required: yes`'
assert_contains "CONSTITUTION.default.md" '文档类 DR 必须使用 `plan_required: no` 和 `code_required: no`'
assert_contains "CONSTITUTION.default.md" "代码类 DR 在 spec 修订完成后不得关闭"
assert_contains "CONSTITUTION.default.md" '轻量 fix DR 通过 `/sdd:code` verification'
assert_contains "CONSTITUTION.default.md" '/sdd:code` 可以执行状态为 `planned` 或 `coding` 的 plan，也可以执行符合条件的 lightweight fix DR'
assert_contains "CONSTITUTION.default.md" '并只能在 `/sdd:code` verification 通过后关闭'
assert_not_contains "CONSTITUTION.default.md" '才能关闭为 `committed`'

assert_contains "hooks/hooks.json" '"PostToolUse"'
assert_contains "hooks/hooks.json" '"matcher": "Write|Edit"'
assert_contains "hooks/hooks.json" 'scripts/hooks/post-tool-use.sh'
assert_contains "skills/review/SKILL.md" '共享 review runner'
assert_contains "skills/review/SKILL.md" '手工入口'
assert_contains "skills/review/SKILL.md" 'requires_user_confirmation'
assert_not_contains "skills/review/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'

# Task 4: /sdd:review 是共享 runner 的薄手工入口。
assert_contains "skills/review/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/review/SKILL.md" '手工触发 review'
assert_contains "skills/review/SKILL.md" 'runner 返回 requires_user_confirmation 时，由 /sdd:review 承接用户确认'
assert_not_contains "skills/review/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'
assert_not_contains "skills/review/SKILL.md" '成功写入后由当前 Skill 自己继续执行 review'

for skill in research prd spec plan; do
  assert_contains "skills/$skill/SKILL.md" '目标文件不存在：视为 create；存在：视为 update'
  assert_contains "skills/$skill/SKILL.md" '成功写入后由 `PostToolUse Hook` 触发'
  assert_contains "skills/$skill/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
  assert_contains "skills/$skill/SKILL.md" '修改已有文档时，不自动执行 review'
  assert_contains "skills/$skill/SKILL.md" '文档已更新；如需复审，请执行 `/sdd:review <doc-path>`'
  assert_contains "skills/$skill/SKILL.md" 'PostToolUse Hook'
  assert_contains "skills/$skill/SKILL.md" '共享 review runner'
  assert_contains "skills/$skill/SKILL.md" '/sdd:review'
  assert_not_contains "skills/$skill/SKILL.md" '写入后必须显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程'
  assert_not_contains "skills/$skill/SKILL.md" '当前 Skill 直接调用 `doc-reviewer`'
  assert_not_contains "skills/$skill/SKILL.md" '修改已有文档时也默认立即进入自动 review'
done

assert_contains "skills/dr/SKILL.md" 'create mode 只创建新 DR 文件，因此本次写入结果恒为 create，不存在 update 分支'
assert_contains "skills/dr/SKILL.md" '成功写入后由 `PostToolUse Hook` 触发'
assert_contains "skills/dr/SKILL.md" 'scripts/lib/sdd-review-runner.sh'
assert_contains "skills/dr/SKILL.md" '这属于 update：修改已有 DR 时，不自动执行 review'
assert_contains "skills/dr/SKILL.md" '文档已更新；如需复审，请执行 `/sdd:review <doc-path>`'
assert_contains "skills/dr/SKILL.md" 'PostToolUse Hook'
assert_contains "skills/dr/SKILL.md" '共享 review runner'
assert_contains "skills/dr/SKILL.md" '/sdd:review'
assert_not_contains "skills/dr/SKILL.md" '目标文件不存在：视为 create；存在：视为 update'
assert_not_contains "skills/dr/SKILL.md" '写入后必须显式触发 `/sdd:review <doc-path>` 或等价共享 runner 流程'
assert_not_contains "skills/dr/SKILL.md" '修改已有文档时也默认立即进入自动 review'

assert_contains "skills/spec/SKILL.md" '新建文档拿不到有效 review 结果时保持 `draft`'
assert_contains "skills/plan/SKILL.md" '新建文档拿不到有效 review 结果时保持 `draft`'
assert_contains "skills/spec/SKILL.md" '修改已有文档时，不自动执行 review'
assert_contains "skills/plan/SKILL.md" '修改已有文档时，不自动执行 review'

assert_contains "skills/research/SKILL.md" 'quality'
assert_contains "skills/prd/SKILL.md" 'quality'
assert_contains "skills/dr/SKILL.md" 'quality'
assert_contains "skills/spec/SKILL.md" 'quality -> feasibility'
assert_contains "skills/plan/SKILL.md" 'quality -> feasibility'

assert_not_contains "skills/research/SKILL.md" 'feasibility'
assert_not_contains "skills/prd/SKILL.md" 'feasibility'
assert_not_contains "skills/dr/SKILL.md" 'quality -> feasibility'
assert_not_contains "skills/dr/SKILL.md" 'feasibility'
assert_not_contains "skills/research/SKILL.md" '仅允许手动 /sdd:review'
assert_not_contains "skills/spec/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'
assert_not_contains "skills/plan/SKILL.md" '当前 Skill 直接顺序触发 quality -> feasibility'

printf 'PASS: skill contracts\n'
