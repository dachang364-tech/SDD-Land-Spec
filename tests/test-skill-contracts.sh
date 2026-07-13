#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

for skill in init new research prd spec plan code dr triage status doctor archive; do
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
assert_contains "skills/spec/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/spec/SKILL.md" '如果来自 `/sdd:triage` 的用户选择'
assert_file_exists "skills/spec/references/spec.md.tmpl"
assert_contains "skills/spec/references/spec.md.tmpl" "- 状态：draft"
assert_contains "skills/spec/SKILL.md" '用户确认后，将状态切换为 `approved`'
assert_contains "skills/spec/SKILL.md" 'accepted code-class DR'
assert_contains "skills/spec/SKILL.md" 'spec_change'
assert_contains "skills/spec/SKILL.md" 'code-class DR 保持 `accepted`'
assert_contains "skills/spec/SKILL.md" '下一步 `/sdd:plan <id>`'
assert_contains "skills/spec/SKILL.md" 'document-class DRs may close after document revision'
assert_contains "skills/spec/SKILL.md" 'document-class DR 不输出 `/sdd:plan` 或 `/sdd:code`'
assert_contains "skills/spec/SKILL.md" "closed_reason: document-updated"
assert_contains "skills/spec/SKILL.md" '写入 `关联 DR` 表格时，应使用 Markdown 链接格式'
assert_contains "skills/spec/references/spec.md.tmpl" "| DR | tag | class | spec_change | 状态 | 关联小节 |"
assert_contains "skills/spec/references/spec.md.tmpl" "| --- | --- | --- | --- | --- | --- |"
assert_contains "skills/spec/SKILL.md" "[<dr-id>](../decisions/<dr-id>.md)"

assert_contains "skills/plan/SKILL.md" "description: Create an implementation plan from approved spec or accepted code-class DR"
assert_contains "skills/plan/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/plan/SKILL.md" '如果来自 `/sdd:triage` 的用户选择'
assert_contains "skills/plan/SKILL.md" "^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$"
assert_contains "skills/plan/SKILL.md" "文档类 DR 不生成 Implementation Plan"
assert_contains "skills/plan/SKILL.md" "Technical Planning Dialogue"
assert_contains "skills/plan/SKILL.md" 'plan_required: yes'
assert_contains "skills/plan/SKILL.md" 'DR `class` is `code`'
assert_file_exists "skills/plan/references/plan.md.tmpl"
assert_contains "skills/plan/references/plan.md.tmpl" "## Technical Design"
assert_contains "skills/plan/references/plan.md.tmpl" "## Implementation Tasks"
assert_contains "skills/plan/SKILL.md" '写入 `关联 DR` 时，使用 Markdown 链接格式'
assert_contains "skills/plan/references/plan.md.tmpl" "- 关联 DR：null"
assert_contains "skills/plan/SKILL.md" "[<dr-id>](../decisions/<dr-id>.md)"

assert_contains "skills/code/SKILL.md" "description: Execute an SDD implementation plan or eligible lightweight fix DR"
assert_contains "skills/code/SKILL.md" "DR Advanced 增量约束"
assert_contains "skills/code/SKILL.md" '如果来自 `/sdd:triage` 的用户选择'
assert_contains "skills/code/SKILL.md" '高质量模式：`superpowers:subagent-driven-development`'
assert_contains "skills/code/SKILL.md" '快速模式：`superpowers:executing-plans`'
assert_contains "skills/code/SKILL.md" 'plan 状态从 `planned` 切换为 `coding`'
assert_contains "skills/code/SKILL.md" 'verification 通过后，将 plan 状态切换为 `done`'
assert_contains "skills/code/SKILL.md" 'code_required: yes'
assert_contains "skills/code/SKILL.md" 'associated DR remains accepted'
assert_contains "skills/code/SKILL.md" 'closed_reason: committed'
assert_contains "skills/code/SKILL.md" "plan execution mode for a matched Implementation Plan"
assert_contains "skills/code/SKILL.md" "lightweight fix DR mode for an eligible accepted fix DR without a matching plan"
assert_contains "skills/code/SKILL.md" "do not require locating a plan and do not require or change plan status"
assert_contains "skills/code/SKILL.md" "If input matches a code-class DR id"
assert_contains "skills/code/SKILL.md" "plan_required: no"
assert_contains "skills/code/SKILL.md" "lightweight fix DR"
assert_contains "skills/code/SKILL.md" "no plan status is changed"
assert_contains "skills/code/SKILL.md" "DR remains accepted"

assert_contains "skills/dr/SKILL.md" "description: Create, accept, or dismiss SDD decision records"
assert_contains "skills/dr/SKILL.md" "fix | feat | chg | arch | spec | doc | typo"
assert_contains "skills/dr/SKILL.md" "drafting → accepted"
assert_contains "skills/dr/SKILL.md" "accepted 或 closed DR 不允许 dismiss"
assert_contains "skills/dr/SKILL.md" "class"
assert_contains "skills/dr/SKILL.md" "spec_change"
assert_contains "skills/dr/SKILL.md" "plan_required"
assert_contains "skills/dr/SKILL.md" "code_required"
assert_contains "skills/dr/SKILL.md" "fix | code | no | yes | yes"
assert_contains "skills/dr/SKILL.md" "简单实现 bug 可以由用户选择轻量 fix 流程"
assert_contains "skills/dr/SKILL.md" 'plan_required: no`：运行 `/sdd:code <id>`'
assert_contains "skills/dr/SKILL.md" "feat | code | yes | yes | yes"
assert_contains "skills/dr/SKILL.md" "chg | code | yes | yes | yes"
assert_contains "skills/dr/SKILL.md" "arch | code | maybe | yes | yes"
assert_contains "skills/dr/SKILL.md" "spec | document | yes | no | no"
assert_contains "skills/dr/SKILL.md" "doc | document | maybe | no | no"
assert_contains "skills/dr/SKILL.md" "typo | document | no | no | no"
assert_contains "skills/dr/SKILL.md" 'spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 决定 `/sdd:plan <id>` 或 `/sdd:code <id>`'
assert_contains "skills/dr/SKILL.md" 'class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan`'
assert_contains "skills/dr/SKILL.md" "影响资产"
assert_contains "skills/dr/SKILL.md" "使用 Markdown 链接格式"
assert_contains "skills/dr/SKILL.md" "[spec.md](../specs/spec.md)"
assert_contains "skills/dr/SKILL.md" "[<plan-file>.md](../plans/<plan-file>.md)"
assert_contains "skills/dr/SKILL.md" "[<dr-id>](./<dr-id>.md)"
assert_file_exists "skills/dr/references/dr.md.tmpl"
assert_contains "skills/dr/references/dr.md.tmpl" "- closed_reason: null"
assert_contains "skills/dr/references/dr.md.tmpl" "- class：code | document"
assert_contains "skills/dr/references/dr.md.tmpl" "- spec_change：yes | no | maybe"
assert_contains "skills/dr/references/dr.md.tmpl" "- plan_required：yes | no"
assert_contains "skills/dr/references/dr.md.tmpl" "- code_required：yes | no"
assert_contains "skills/dr/references/dr.md.tmpl" "## 契约影响"
assert_contains "skills/dr/references/dr.md.tmpl" "## 实现影响"
assert_contains "skills/dr/references/dr.md.tmpl" "## 文档影响"
assert_contains "skills/dr/references/dr.md.tmpl" "## 验证方式"
assert_contains "skills/dr/references/dr.md.tmpl" "| 资产 | 章节 / ID |"

assert_contains "skills/triage/SKILL.md" "description: Triage user questions after implementation, review, or testing"
assert_contains "skills/triage/SKILL.md" "不创建 DR"
assert_contains "skills/triage/SKILL.md" "不修改 spec"
assert_contains "skills/triage/SKILL.md" "不修改 plan"
assert_contains "skills/triage/SKILL.md" "不修改 code"
assert_contains "skills/triage/SKILL.md" "不改变 plan 状态"
assert_contains "skills/triage/SKILL.md" "不替用户选择后续路径"
assert_contains "skills/triage/SKILL.md" "必须等待用户确认后"
assert_contains "skills/triage/SKILL.md" "不得一次性读取整个 active version 目录"
assert_contains "skills/triage/SKILL.md" '不得默认读取所有 `plans/*.md`'
assert_contains "skills/triage/SKILL.md" '不得默认读取所有 `decisions/*.md`'
assert_contains "skills/triage/SKILL.md" "不得默认读取代码"
assert_contains "skills/triage/SKILL.md" "/sdd:triage --deep"
assert_contains "skills/triage/SKILL.md" "code implementation issue"
assert_contains "skills/triage/SKILL.md" "spec 和 plan 基本正确，但当前代码实现偏离预期"
assert_contains "skills/triage/SKILL.md" "plan issue"
assert_contains "skills/triage/SKILL.md" "spec issue"
assert_contains "skills/triage/SKILL.md" "new requirement / change request"
assert_contains "skills/triage/SKILL.md" "unclear, needs user choice"
assert_contains "skills/triage/SKILL.md" "置信度：low | medium | high"
assert_contains "skills/triage/SKILL.md" "已读取依据"
assert_contains "skills/triage/SKILL.md" "请确认你要走哪条路径。"

assert_contains "skills/status/SKILL.md" "description: Show current SDD version status and next-step guidance"
assert_contains "skills/status/SKILL.md" "展示当前版本状态与下一步建议"

assert_contains "skills/doctor/SKILL.md" "description: Diagnose SDD plugin installation and project consistency"
assert_contains "skills/doctor/SKILL.md" 'At execution start, read `docs/CONSTITUTION.md`.'
assert_contains "skills/doctor/SKILL.md" 'suggest running `/sdd:init`'
assert_contains "skills/doctor/SKILL.md" ".claude-plugin/plugin.json"
assert_contains "skills/doctor/SKILL.md" "done 的代码类 DR plan 对应 DR 是否仍 accepted"

assert_contains "skills/archive/SKILL.md" "description: Archive the current active SDD version"
assert_contains "skills/archive/SKILL.md" '所有 `plans/*.md` 状态为 `done`'
assert_contains "skills/archive/SKILL.md" "docs/vX.Y.Z/ → docs/archive/vX.Y.Z/"

assert_contains "README.md" "class / spec_change / plan_required / code_required"
assert_contains "README.md" "spec-changing code-class DR"
assert_contains "README.md" 'fix DR 通常使用 `spec_change: no`'
assert_contains "CONSTITUTION.default.md" '代码类 DR 默认使用 `plan_required: yes`'
assert_contains "CONSTITUTION.default.md" '文档类 DR 必须使用 `plan_required: no` 和 `code_required: no`'
assert_contains "CONSTITUTION.default.md" "代码类 DR 在 spec 修订完成后不得关闭"
assert_contains "CONSTITUTION.default.md" '轻量 fix DR 通过 `/sdd:code` verification'
assert_contains "CONSTITUTION.default.md" '/sdd:code` 可以执行状态为 `planned` 或 `coding` 的 plan，也可以执行符合条件的 lightweight fix DR'
assert_contains "CONSTITUTION.default.md" '才能关闭为 `committed`'

printf 'PASS: skill contracts\n'
