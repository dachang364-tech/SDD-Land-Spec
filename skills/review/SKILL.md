---
name: review
description: 作为受管 SDD 文档的唯一 review 编排入口，负责识别文档类型、编排 `doc-reviewer`、校验结果并向用户交付结构化 review 回执。用户请求复审 research、PRD、DR、spec 或 plan 文档时使用。
---

# /sdd:review

/sdd:review 是唯一 review 编排入口。它负责从受管文档路径确定 review 所需上下文、调用 `doc-reviewer` subagent、校验结果并交付用户回执。

## 入口约束

1. 接收 `/sdd:review <doc-path>`，校验 `<doc-path>` 是活动版本中受支持的 SDD 文档路径；不支持时提示“不是受支持的 SDD 文档路径”。
2. archived version 的文档不得执行 `/sdd:review`。
3. 项目必须已初始化，且 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 可用；缺失时提示运行 `/sdd:init`，不得使用 Plugin 内置资产替代。
4. 由当前 Skill 负责识别 `document_type` 与 mode 链路。支持 `research`、`prd`、`dr`、`spec`、`plan`；路径无法唯一识别时停止并说明原因。

## 编排

1. 根据已识别的 `document_type` 使用项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<document_type>/` 下的模板和标准，并收集 `doc-reviewer` 所需的 `upstream_paths`。
2. 确定 mode 链路：`research / prd / dr -> quality`；`spec / plan -> quality -> feasibility`。
3. 当前 Skill 直接调用 `doc-reviewer` subagent。对每个 mode 提供 agent 输入合同要求的 `document_path`、`document_type`、`mode`、`template_path`、`standard_path`、`repair_policy`、`upstream_paths`、`invocation_source` 和正整数 `max_rounds`。
4. 对每个 mode 的结构化结果执行 schema 校验，使用 `skills/review/references/reviewer-result.schema.json`；结果不是恰好一个符合 schema 的 JSON 对象时，停止后续 mode，并向用户报告无效 reviewer 结果。
5. 依次执行 mode。任一结果 `blocked: true`、`requires_user_confirmation: true` 或 `passed: false` 时，停止后续 mode；只有前一 mode `passed: true`、`blocked: false` 且不需要确认时才继续下一个 mode。

## 用户回执与确认

聚合已校验的结果并输出一份用户回执，至少包含 `document_path`、`document_type`、`executed_modes`、`blocked`、`requires_user_confirmation`、`remaining_items`。同时概述 `auto_repairs`、`blocking_items`、`remaining_issues`、`candidate_rewrites` 和各 mode 的结论。

当 reviewer 返回 `requires_user_confirmation` 时，由当前 Skill 承接用户确认：展示 `candidate_rewrites` 与待确认项，不将候选改写当作已接受修改。用户确认后写回目标文档；写回后重新执行 `/sdd:review <doc-path>`。用户拒绝或暂不确认时，保留未解决项并在回执中说明 review 未完成。
