# Plan Feasibility Standard

## 元信息

- mode: feasibility
- doc_type: plan
- pass_threshold: 80
- blocker_priority: high
- max_rounds: 3

## 检查项定义

- 实现路径闭合
- 任务顺序可执行
- 验证策略可落地
- 验收映射完整

## 评分与阈值规则

- 可落地性: 25
- 覆盖性: 25
- 闭合性: 25
- 验证性: 25

## 执行策略

- 允许自动修复任务拆分、顺序和验证缺口
- 架构路线变化只输出建议

## 输出契约

- output_format: machine+user
