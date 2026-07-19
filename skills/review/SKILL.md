---
name: review
description: Review and improve PRD, spec, or plan documents. Use for /sdd:review and for post-write review orchestration in /sdd:prd, /sdd:spec, /sdd:plan.
---

# /sdd:review

Review a target document using the project runtime template assets in `.sdd/templates/`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `.sdd/templates/` to exist; if missing, stop and ask the user to run `/sdd:init`.
3. Require the target document to exist and pass the minimum pre-review structure gate.
4. 如果必要模板或标准文件缺失，直接失败，不降级到 Plugin 内置资产。

## Invocation and structured handoff

命令层或手动 `/sdd:review` 必须启动一个 `doc Reviewer-Subagent`，每次调用只评审一个 `mode`，并将以下 JSON 对象作为 subagent 唯一的输入载荷。不得以自由文本替代或省略字段：

```json
{
  "document_path": "<project-relative path>",
  "document_type": "prd|spec|plan",
  "mode": "quality|feasibility",
  "template_path": ".sdd/templates/<type>/template.md",
  "standard_path": ".sdd/templates/<type>/<mode>.standard.md",
  "repair_policy": "<resolved policy>",
  "upstream_paths": ["<project-relative path>"],
  "invocation_source": "automatic|manual",
  "max_rounds": 1
}
```

subagent 必须只返回一个 JSON 对象，且该对象必须通过 `references/reviewer-result.schema.json` 校验；禁止在机器输出前后附加 Markdown、解释或多个 JSON 对象。命令层在读取任何字段、生成用户回执或改变文档状态前必须校验该 JSON：解析失败、schema 校验失败、`document_type` / `mode` 与输入不匹配时，将本次 review 视为 `blocked: true` 的执行失败，保留 `draft` 或原有稳定状态，不得继续审批或状态推进。

`user_receipt` 是最终聚合回执字段。单 mode 调用也必须填入其已执行的 mode；`spec` 和 `plan` 的命令层在全部已执行 mode 的有效结果基础上聚合为唯一回执。

## Structured input

上述 JSON 载荷至少包括：

- 文档路径：`document_path`
- 文档类型：`document_type`，第一阶段仅支持 `prd`、`spec`、`plan`
- 当前 mode：`mode`，支持 `quality` 或 `feasibility`
- 模板路径：`template_path`
- 标准路径：`standard_path`
- 修复权限策略：`repair_policy`
- 上游依赖文档路径：`upstream_paths`
- 调用来源：`invocation_source`（自动触发 / 手动复审）
- 最大循环轮次：`max_rounds`

`template_path` 和 `standard_path` 必须来自当前项目 `.sdd/templates/`，由 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 传入运行时模板资产。

## Modes

reviewer 对外保持单入口，对内支持：

- `quality`
- `feasibility`

默认触发矩阵：

- `prd -> quality`
- `spec -> quality + feasibility`
- `plan -> quality + feasibility`

## Review admission check

在执行任何评审或自动修复前，reviewer 必须独立重复以下防御性准入检查，不能只信任调用者的 pre-review gate：

1. `document_path` 存在、是可读的常规文件且非空。
2. `document_type` 和 `mode` 属于支持枚举，且 `template_path`、`standard_path` 都位于当前项目 `.sdd/templates/<document_type>/` 下、存在且可读。
3. 文档包含该类型模板定义的核心章节、必要元信息和 `## 文档引用` 表；文档不得只是未替换的模板占位稿。
4. `upstream_paths` 中声明的依赖存在且满足调用该文档类型的最小前置条件。
5. `repair_policy`、`invocation_source` 和正整数 `max_rounds` 均存在且可用。

任一项失败时，不进入 review loop、不写入目标文档；返回符合 schema 的最终结果，其中 `passed: false`、`blocked: true`、`iterations: 0`，并在 `blocking_items` 中说明准入失败原因。调用者必须将其作为阻断结果处理。

## Review loop

reviewer 在单次 subagent 调用内部完成有限轮次串行闭环，不将同一文档的连续优化拆成多个并行 reviewer：

```text
review -> update -> review -> output
```

每轮先依据对应标准评估，再按 `repair_policy` 执行自动修复或生成候选改写，随后复评。通过采用“有分数，但阻断项优先”：达到分数阈值但仍存在阻断项时，不得报告为通过。

停止条件：

1. 达到当前 mode 的通过阈值且没有阻断项。
2. 达到最大循环轮次。
3. 进入需要用户确认的状态。
4. 无法继续产生有效改进。

## Repair Policy

- `PRD / Spec` 的低风险问题允许自动修复。
- `PRD / Spec` 的语义歧义生成候选改写，不直接落正文，等待用户确认。
- `Plan` 可自动修复任务拆分、执行顺序、测试缺口、验收映射和重复问题。
- 架构路线切换或其他高风险语义变更只输出建议，不直接改写。
- 自动修复不得删除用户意图；存在不确定性时必须设置 `requires_user_confirmation`。

## Output

reviewer 输出必须区分：

1. 机器输出：遵循 `references/reviewer-result.schema.json`，供命令层和后续 agent 消费。
2. 用户输出：默认只向用户返回 1 份聚合后的简洁回执。

机器输出至少包含：

- `document_type`
- `mode`
- `passed`
- `blocked`
- `score_or_grade`
- `blocking_items`
- `auto_repairs`
- `remaining_issues`
- `requires_user_confirmation`
- `candidate_rewrites`
- `iterations`
- `reached_max_iterations`
- `stopped_for_no_improvement`
- `user_receipt`

用户输出默认只返回 1 份聚合后的简洁回执，包含：

- 文档类型
- 执行的 mode
- 总迭代轮次
- 自动修复摘要
- 待确认项 / 剩余问题
- 是否阻断后续流程
- 简要质量摘要

`user_receipt` 必须以 schema 中的 `document_type`、`executed_modes`、`iterations`、`auto_repairs_summary`、`remaining_or_confirmation_items`、`blocked` 和 `quality_summary` 承载这些内容。