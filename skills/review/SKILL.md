---
name: review
description: Review and improve research, PRD, DR, spec, or plan documents. Use for /sdd:review as the manual review entry and user receipt layer for managed SDD documents.
---

# /sdd:review

`/sdd:review` 是手工入口与用户回执层，内部统一调用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。

当前 Skill 只负责手工触发 review、展示结果并承接用户回执。自动 review 不由当前 Skill 兜底触发，而是由运行时的 `PostToolUse Hook` 在文档写入成功后完成；Hook 与 runner 的内部编排不在本入口合同中展开。

## 职责边界

- 保留 `/sdd:review <doc-path>` 作为人工复审入口。
- 读取并传递用户指定的项目文档，不复制或替代项目级模板资产。
- 将 review 请求委托给 `scripts/lib/sdd-review-runner.sh`，再将结构化结果转换为简洁的用户回执。
- 不在 Skill 内实现 Hook 调度、mode 链路、准入检查、review loop 或修复策略；这些行为由共享 review runner 与 `agents/doc-reviewer.md` 承接。
- 不新增命令名，不对 archived version 的文档执行 review，不绕过项目级模板治理。

## Preconditions

1. `docs/CONSTITUTION.md` 与 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 必须存在；缺失时直接失败并提示运行 `/sdd:init`。
2. 目标必须是受支持的项目相对路径：
   - `docs/versions/vX.Y.Z/research/*.md`
   - `docs/versions/vX.Y.Z/prd/prd.md`
   - `docs/versions/vX.Y.Z/dr/*.md`
   - `docs/versions/vX.Y.Z/spec/*.md`
   - `docs/versions/vX.Y.Z/plan/*.md`
3. 目标路径不在矩阵内时，直接失败并提示“不是受支持的 SDD 文档路径”。
4. 目标文档属于 archived version 时，直接失败；`/sdd:review` 不能对 archived version 的文档执行任何操作。
5. 必要模板或标准文件缺失时直接失败，不降级到 Plugin 内置资产。

## 运行时委托

手工入口接收 `doc-path`，由共享 review runner 负责文档类型识别、mode 路由、准入检查、有限 review loop、`doc-reviewer` 调用及结果校验。`doc-reviewer` 必须解析为插件根目录 `agents/doc-reviewer.md` 定义的 Claude Code agent。

runner 仍使用既有结构化输入合同，并把单次请求交给 agent：

```json
{
  "document_path": "<project-relative path>",
  "document_type": "research|prd|dr|spec|plan",
  "mode": "quality|feasibility",
  "template_path": "${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/template.md",
  "standard_path": "${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/<mode>.standard.md",
  "repair_policy": "<resolved policy>",
  "upstream_paths": ["<project-relative path>"],
  "invocation_source": "automatic|manual",
  "max_rounds": 1
}
```

调用方不得以自由文本替代结构化载荷，也不得用普通文本模拟 `doc-reviewer`。runner 返回的结果必须通过 `references/reviewer-result.schema.json` 校验；解析失败或 schema 校验失败时，保留原有稳定状态并作为阻断结果处理。

项目模板与标准只从当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/` 读取。`research`、`prd`、`dr` 使用 `quality`，`spec`、`plan` 使用 `quality -> feasibility`；具体路由与执行细节由 runner 维护。

## 输出合同

机器结果遵循 `references/reviewer-result.schema.json`，至少承载：

- `document_type`
- `mode` 或 `executed_modes`
- `passed`
- `blocked`
- `score_or_grade`
- `blocking_items`
- `auto_repairs`
- `remaining_issues`
- `requires_user_confirmation`
- `candidate_rewrites`
- `iterations`
- `user_receipt`

用户侧默认只返回一份简洁回执，说明文档类型、执行 mode、迭代轮次、自动修复摘要、待确认项或剩余问题、是否阻断后续流程及质量摘要。若 `requires_user_confirmation=true`，由 `/sdd:review` 承接用户确认；确认写回后必须重新复审。
