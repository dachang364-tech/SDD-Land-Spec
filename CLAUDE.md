# 项目级 Claude 指令

## 语言

所有面向用户的文案、Skill 内容、模板说明、技术方案、Plan 文档说明统一使用中文。

## Skill 设计与修改总原则

本项目后续凡是涉及 Plugin 内 `skills/*/SKILL.md` 的创建、重写、扩展、修订、规范化改造，必须优先使用用户环境中已安装的 `/skill-creator` 作为标准生成工具。

不要把 `/skill-creator` 视为可选参考；它是本项目后续 Skill 方案设计与落地时的默认工作流约束。

## 适用范围

以下工作一律适用本约束：

- 新增任何 Plugin Skill
- 修改现有 `skills/*/SKILL.md`
- 对 Skill 做 Claude Code 规范化重写
- 调整 Skill 的 frontmatter、description、触发条件、步骤结构、输出合同
- 编写与 Skill 改造相关的 spec / design / plan 文档
- 评审某个 Skill 是否符合 Claude Code Skills 设计规范

## 强制要求

### 1. 先用 `/skill-creator`，再写方案或改 Skill

当任务涉及 Skill 创建或修改时，必须显式调用 `/skill-creator`，用它来生成或约束目标 Skill 的技术方案、结构设计或重写结果。

不允许直接跳过 `/skill-creator`，仅凭当前仓库中的旧 Skill 文本手工续写新版本，除非用户明确要求不要使用 `/skill-creator`。

### 2. Plan 文档必须写明 `/skill-creator`

后续任何涉及 Skill 创建、修改、重写、规范化的 Plan 文档，必须把 `/skill-creator` 写入执行步骤或全局约束中，至少覆盖以下信息：

- 该任务需要使用 `/skill-creator`
- `/skill-creator` 是生成符合 Claude Code 规范 Skill 的标准工具
- 旧的 `skills/*/SKILL.md` 只能作为迁移参考，不能直接视为最终规范
- 实施时要校验生成结果是否仍满足本项目现有功能合同

### 3. 目标不是只改文案，而是满足 Claude Code 规范

使用 `/skill-creator` 的目标，不是单纯润色文字，而是确保 Skill 在以下方面满足规范：

- frontmatter 合法且语义清晰
- `name`、`description`、触发条件定义准确
- 内容结构清晰，便于 Claude Code 在正确时机发现并使用
- 步骤、约束、输出合同明确
- 与本项目已有脚本、模板、agent、测试合同一致

### 4. 保留项目既有能力合同

即使通过 `/skill-creator` 重写 Skill，也不能破坏本项目已有的能力边界、目录约定和测试合同。重写后的 Skill 仍需遵守：

- 现有命令名称与用户入口
- 已存在的模板目录、脚本目录、agent 目录约定
- README、TESTING、tests 中已定义的关键行为合同
- 运行时优先读取项目资产而不是退回 skill 内置资产的治理原则（若该 Skill 属于模板治理范围）

## 方案文档编写要求

当 spec / design / plan 文档涉及 Skill 工作时，必须明确区分以下三层：

1. `/skill-creator` 负责生成或规范化 Skill 设计
2. `skills/*/SKILL.md` 是最终落地的 Skill 合同文件
3. 项目脚本、模板、agent、测试负责承接 Skill 的运行时行为与验证

不要把 `/skill-creator` 写成一个模糊建议；要把它写成明确步骤、明确依赖或全局约束。

## 推荐执行方式

当你需要规划或执行某个 Skill 相关任务时，优先采用以下顺序：

1. 识别该任务是否会新增或修改 `skills/*/SKILL.md`
2. 如果会，先调用 `/skill-creator`
3. 基于 `/skill-creator` 输出整理 spec / design / plan
4. 再落地到具体 Skill 文件、脚本、模板、agent 或测试
5. 最后验证生成结果与本项目既有合同是否一致

## 非目标

以下内容不属于本文件当前要解决的范围：

- `DR` 的模板治理与 review 方案
- 某个单独 Skill 的具体实现细节
- 某个 agent 的提示词逐段设计

这些内容应在各自的 spec / design / plan 文档中单独定义。
