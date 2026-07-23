# Claude Code 项目协作说明

本项目使用 SDD（Specification Driven Development）工作流。

## 使用约束

- 开始任何 SDD 工作前，先读取 `docs/CONSTITUTION.md`。
- `docs/CONSTITUTION.md` 是本项目 SDD 流程、门控、状态和 review 规则的正式事实来源。
- 执行 `/sdd:init`、`/sdd:new`、`/sdd:research`、`/sdd:prd`、`/sdd:spec`、`/sdd:plan`、`/sdd:code`、`/sdd:dr`、`/sdd:triage`、`/sdd:archive` 时，应遵守 `docs/CONSTITUTION.md` 的当前内容。

## 协作方式

- 优先读取项目内现有文档、模板和版本资产，再执行修改。
- `.sdd/templates/` 是 research、prd、spec、plan、dr 的项目运行时模板来源。
- 如果项目运行时模板缺失，应先修复模板资产，再继续相关文档生成或 review。
- 不要假设 Plugin 内置模板仍然是当前项目的有效事实来源。

## 初始化说明

- `/sdd:init` 只会在项目根目录缺失 `CLAUDE.md` 时生成本文件。
- 如果项目根目录已经存在 `CLAUDE.md`，必须保留原文件，不覆盖、不合并。
- `AGENTS.md` 不属于 `/sdd:init` 的管理范围。
