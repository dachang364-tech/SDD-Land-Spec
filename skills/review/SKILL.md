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

## Structured Input

reviewer 输入应是结构化上下文，而不是模糊的自由文本请求。至少包括：

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

## Review Loop

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
