# Research 质量标准

## 元信息

- mode: quality
- doc_type: research
- pass_threshold: 80
- blocker_priority: strict
- max_rounds: 2

## 检查项定义

- 背景、研究问题、信息来源、关键发现、结论与建议、对后续文档的影响齐全
- 研究问题明确
- 证据来源可信且可回溯
- 结论与建议可复用
- 不越界写成 PRD / spec / plan / DR

## 评分与阈值规则

- 完整性: 20
- 证据性: 20
- 清晰性: 20
- 可复用性: 20
- 非越界性: 20

## 执行策略

- 允许自动修复结构、标题、措辞和轻量引用问题
- 不允许将 research 改写为其他文档类型

## 输出契约

- output_format: machine+user
