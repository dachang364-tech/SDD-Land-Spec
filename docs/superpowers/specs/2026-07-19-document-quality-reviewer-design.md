# SDD Plugin 设计规格：Document Quality Reviewer and Standards-Driven Templates

- 日期：2026-07-19
- 状态：draft
- 类型：Design Spec
- 目标：为 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 引入项目级模板与标准资产、标准驱动的文档 reviewer 闭环，以及能够减少人工 review 成本的自动修复与候选改写机制，同时保持 SDD 主流程、文档引用契约和现有元数据风格一致。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | SDD 主流程与技能边界 | [2026-07-11-sdd-plugin-mvp-workflow-spec-design.md](./2026-07-11-sdd-plugin-mvp-workflow-spec-design.md) | - | 本规格在现有 SDD 主流程上增加模板、标准和 reviewer 能力，不重写主流程阶段定义 |
| modifies | 文档模板职责与引用契约 | [2026-07-14-document-references-advanced-spec.md](./2026-07-14-document-references-advanced-spec.md) | - | 本规格扩展 PRD、spec、plan 模板内容与流程契约字段，但继续沿用统一 `## 文档引用` 表模型 |
| references | DR / spec / plan 关系边界 | [2026-07-13-dr-advanced-spec.md](./2026-07-13-dr-advanced-spec.md) | - | 用于保持 code-class DR、spec、plan 和 code 阶段的职责边界一致 |
| references | 当前计划模板与执行密度 | [2026-07-17-dr-filename-normalization-spec.md](./2026-07-17-dr-filename-normalization-spec.md) | - | 用于延续当前 specs 的写作风格、实施验证章节和 acceptance criteria 组织方式 |

## 1. Context

当前 SDD Plugin 已经具备以下能力：

- `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 通过各自模板生成文档。
- `CONSTITUTION`、hook、`/sdd:doctor`、文档引用校验和 plan self-review 已经提供结构性门控。
- `plan` 和 `code` 阶段已经能约束实现流程、verification 和状态推进。

当前缺口也很明确：

- 文档模板仍偏静态，无法把不同团队、不同项目的写作标准显式沉淀到项目中。
- 现有质量门控更偏结构和状态契约，还没有真正针对文档语义质量、设计可行性和自动修复闭环的 reviewer。
- 用户需要花较多人工成本检查 PRD、spec、plan 的清晰度、一致性、可落地性和相互对齐关系。
- reviewer 能力如果直接硬编码在 `prd/spec/plan` 技能内部，会让模板演进、标准定制和后续扩展文档类型都变得昂贵。

因此这次升级的目标不是单独增加一个评分器，而是建立一套闭环：

```text
项目级模板 / 标准
-> 文档生成
-> 自动触发 reviewer
-> 自动修复 / 候选改写 / 风险输出
-> 命令层判断是否阻断或等待用户确认
-> 用户可手动复审
```

## 2. Goals

1. 为 `PRD / Spec / Plan` 建立项目级可编辑模板与标准资产。
2. 在 Plugin 中保留多套命名默认模板包与默认标准，并支持 `/sdd:init` 选择其一后完整展开到项目中。
3. 让 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 在生成文档后自动触发 reviewer。
4. 设计一个统一的 `doc Reviewer-Subagent`，对外单入口，对内支持 `quality` 和 `feasibility` 两个 mode。
5. 让 reviewer 在单次 subagent 调用内部完成有限轮次的串行 `review -> update -> review` 闭环。
6. 区分机器输出和用户输出：机器输出服务于命令层和后续 agent，用户输出保持简洁回执。
7. 让 `PRD / Spec / Plan` 的模板结构和标准规则提升文档质量下限，并减少人工 review 与修改成本。
8. 保持与现有 SDD 主流程、文档引用契约、元数据风格和状态推进模型兼容。

## 3. Non-Goals

本规格不要求实现：

- 为所有文档类型一次性接入 reviewer；第一阶段只覆盖 `prd / spec / plan`。
- 在第一阶段支持 `research`、`DR`、`ARCHIVE.md` 或 `INDEX.md` 的同级 reviewer 模型。
- 在第一阶段实现项目模板包来源追踪、内容损坏检测或运行时自动回退。
- 在 reviewer 中内置大量 `PRD / Spec / Plan` 专属处理逻辑。
- 引入新的文档元数据表现形式；继续沿用现有模板元信息风格。
- 把 reviewer 的中间推理过程直接写入文档正文。
- 引入复杂的标准 DSL、外部状态数据库或集中式 reviewer 配置中心。
- 把 reviewer 设计为多 agent 并行优化同一文档；同一文档的闭环保持串行。

## 4. Core Design Principles

### 4.1 标准驱动优先于文档类型硬编码

reviewer 的通用行为由 mode 和标准文件定义；`PRD / Spec / Plan` 的差异主要落在模板内容、检查项和阈值，而不是 reviewer 本体的文档类型分支。

### 4.2 项目级运行时资产优先

一旦 `/sdd:init` 已经把所选模板包展开到项目 `.sdd/templates/` 中，后续文档生成与 review 只读取项目资产。Plugin 内置模板包只承担初始化来源职责，不参与运行时 fallback。

### 4.3 生成与 review 使用同一套有效资产

文档生成与 reviewer 必须消费同一套解析后的模板和标准，避免“按 Plugin 模板生成、按项目标准审核”的错位。

### 4.4 reviewer 是执行器，命令层是编排者

`/sdd:prd`、`/sdd:spec`、`/sdd:plan` 负责识别文档类型、选择 mode、决定阻断策略、解析模板和标准来源。reviewer 负责执行评审闭环，不负责定义业务流程和状态推进。

### 4.5 流程契约字段保留在模板中

`PRD / Spec / Plan` 继续保留现有元信息风格、`## 文档引用` 表和必要流程契约字段。模板升级应改进内容结构与质量标准，而不是删除主流程依赖的契约字段。

## 5. Asset Model and Directory Layout

### 5.1 Plugin 内置模板包资产

Plugin 内置多套命名模板包，每个模板包同时包含 `PRD / Spec / Plan` 的模板与标准资产。第一阶段至少提供 1 套默认模板包，但资产模型应允许后续继续增加更多命名模板包。

建议结构：

```text
assets/
  template-packs/
    default-backend/
      prd/
        template.md
        quality.standard.md
      spec/
        template.md
        quality.standard.md
        feasibility.standard.md
      plan/
        template.md
        quality.standard.md
        feasibility.standard.md
```

规则：

- `template-pack` 是用户在 `/sdd:init` 时可选择的静态资产集合。
- 模板包名称是人类可读标识，用于初始化时选择，不要求写入项目元数据文件。
- 模板包中的模板和标准是静态资产，不需要符合 Skill header 格式。
- 模板包资产必须被打包进 Plugin 产物，并纳入测试覆盖。

### 5.2 项目级运行时资产

`/sdd:init` 必须在初始化项目时要求或确认模板包选择，并将所选模板包完整展开到项目 `.sdd/templates/` 下。展开后的文件是运行时唯一生效资产。

建议结构：

```text
.sdd/
  templates/
    prd/
      template.md
      quality.standard.md
    spec/
      template.md
      quality.standard.md
      feasibility.standard.md
    plan/
      template.md
      quality.standard.md
      feasibility.standard.md
```

规则：

- `.sdd/templates/` 是项目级 SDD 文档资产根目录。
- 按 `prd / spec / plan` 分目录。
- 文档类型体现在目录名，mode 体现在标准文件名。
- 文件采用 Markdown 形式，兼顾人可读与机器可解析。
- 用户可以直接修改项目中的模板与标准文件，修改后立即成为新的运行时行为依据。

### 5.3 运行时读取规则

第一阶段不实现内容损坏检测，也不实现运行时降级或 fallback。

规则：

- `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和独立 review 入口在运行时只读取 `.sdd/templates/`。
- reviewer 不直接回读 Plugin 内置模板包，而只消费命令层传入的项目级有效模板与标准。
- 如果 `.sdd/templates/` 缺失必要文件，命令必须失败并给出明确错误，而不是自动回退到 Plugin 内置资产。
- 生成阶段与 reviewer 必须基于同一套项目级有效资产执行，避免生成与 review 使用不同标准。
- 第一阶段允许用户手工编辑项目资产，但不要求系统记录“当前项目最初来自哪个模板包”。

## 6. Reviewer Architecture

### 6.1 总体形态

采用 `Skill 编排 + reviewer subagent 执行` 模型。

职责分层：

- 命令层：`/sdd:prd`、`/sdd:spec`、`/sdd:plan` 以及独立复审入口。
- 标准层：项目级标准与模板包派生出的运行时标准。
- reviewer 执行层：统一的 `doc Reviewer-Subagent`。

### 6.2 Reviewer 入口形态

对外只暴露一个 reviewer，对内支持两个 mode：

- `quality`
- `feasibility`

默认触发矩阵：

- `prd -> quality`
- `spec -> quality + feasibility`
- `plan -> quality + feasibility`

### 6.3 Reviewer 输入

reviewer 输入应是结构化上下文，而不是模糊的自由文本请求。至少包括：

- 文档路径
- 文档类型
- 当前 mode
- 解析后的模板
- 解析后的标准
- 修复权限策略
- 上游依赖文档路径
- 调用来源（自动触发 / 手动复审）
- 最大循环轮次

### 6.4 Mode 职责

`quality` 关注：

- 结构完整性
- 表达清晰度
- 模板契约满足度
- 术语一致性
- 上下游文档一致性
- 流程契约字段与文档引用完整性

`feasibility` 关注：

- 设计可落地性
- 上游需求覆盖性
- 输入输出 / 规则 / 异常 / 任务 / 验证闭合性
- 计划任务的可执行性与可验证性
- 技术方案与任务拆分的一致性

## 7. Review Loop and Stop Conditions

### 7.1 闭环模型

reviewer 在单次 subagent 调用内部以串行方式执行有限轮次闭环：

```text
评估 -> 修复 / 候选改写 -> 复评 -> 输出
```

该闭环不拆成主流程多次反复调用 subagent，也不对同一文档并行执行多个优化分支。

### 7.2 停止条件

reviewer 必须同时具备以下停止条件：

1. 达到当前 mode 的通过阈值。
2. 达到最大循环轮次。
3. 进入需要用户确认的状态。
4. 无法继续产生有效改进。

规则：

- 最大循环轮次可配置，并允许按文档类型或 mode 区分。
- reviewer 的目标是把文档推进到可交付状态，而不是无限逼近满分。
- `PRD` 循环上限应偏保守；`Spec` 中等；`Plan` 可相对更高。

## 8. Repair Policy and User Confirmation

### 8.1 分文档类型的修复权限

`PRD / Spec`：

- 可自动修复低风险问题：结构、措辞、术语统一、缺失但可从上下文明确补全的小项、引用表、状态字段和一致性问题。
- 遇到需求语义不清、存在多种合理解释时，不直接改写核心意图。
- 生成候选改写，等待用户确认。

`Plan`：

- 可更积极地自动修复任务拆分、执行顺序、测试缺口、实现细节缺失、验收映射缺失和明显重复问题。
- 对架构路线切换、重大技术方向变化等高杠杆决策，只输出建议，不直接改写。

### 8.2 候选改写规则

当 `PRD / Spec` 出现语义不清但 reviewer 能给出更合理写法时：

- 不只提建议不落文。
- 不直接落正文。
- 生成候选改写，等待用户确认。

候选改写进入主流程的方式：

- 低风险自动修复直接写回正文。
- 高风险改写保留在 reviewer 输出中。
- 命令层检测到 `需要用户确认` 后暂停状态推进。
- 用户确认后，再由命令层写回文档，并可选地重新触发 reviewer。

## 9. Trigger Model and Flow Control

### 9.1 自动触发定义

“文档生成后”必须被定义为：

> 命令完成本轮文档写入，并且目标文档通过最小结构校验后，自动触发 reviewer。

### 9.2 双层准入校验

准入分两层：

1. `pre-review gate`：命令层轻量校验。
2. `review admission check`：reviewer 内部防御性校验。

最小结构校验只负责判断文档是否达到“可 review”的最低门槛，例如：

- 文件存在
- 非空
- 核心章节存在
- 必要元信息存在
- 不是纯模板占位稿
- 上游依赖满足最小前置条件

第一阶段不在项目资产缺失或损坏时做运行时自动回退判断；相关命令应直接失败并提示修复项目模板资产。

### 9.3 自动触发与手动复审

接入方式采用混合模式：

- 命令内自动触发 reviewer
- 用户可在手工修改文档后独立复审

手动复审入口应复用同一套模板 / 标准解析逻辑和结果结构。

## 10. Blocking and Pass Rules

### 10.1 分级阻断

阻断策略采用分级模型：

- `quality` 默认偏强阻断。
- `feasibility` 默认偏弱阻断。
- `plan` 的门槛整体高于 `prd`。

### 10.2 通过规则

采用：

```text
有分数，但阻断项优先
```

规则：

- 分数反映整体质量和收敛程度。
- 阻断项决定当前能否通过和能否推进流程。
- 即使分数不低，只要还有阻断项，也不能通过。
- 没有阻断项时，分数仍可提示优化空间。

### 10.3 默认阻断项方向

`quality` 默认阻断项示例：

- 核心章节缺失
- 关键元信息缺失或状态冲突
- 文档引用表缺失、关键关系错误或格式错误
- 与上游文档存在明显冲突
- 大段保留占位语或空泛模板语
- 存在足以影响理解的明显歧义

`feasibility` 默认阻断项示例：

- `spec` 缺关键输入输出、异常或规则闭环，无法支撑实现
- `plan` 缺关键实现路径、验证方式或完成判据
- 上游定义的关键能力在当前文档中没有承接
- 技术方案与任务拆分明显不一致

## 11. Output Model

### 11.1 双层输出

reviewer 输出必须区分：

1. 机器输出
2. 用户输出

### 11.2 机器输出

机器输出供命令层和后续 agent 消费，至少包含：

- 文档类型
- mode
- 是否通过
- 是否阻断
- 当前分数或等级
- 阻断项列表
- 自动修复项
- 剩余问题
- 是否需要用户确认
- 候选改写列表
- 实际迭代轮次
- 是否达到最大轮次
- 是否因无有效改进而停止

一次 review 调用中允许产生多个机器输出快照：

- 轮次级快照
- mode 级最终结果

### 11.3 用户输出

默认只向用户返回 1 份聚合后的简洁回执，不按轮次刷屏。

用户回执默认展示：

- 文档类型
- 执行的 mode
- 总迭代轮次
- 自动修复摘要
- 待确认项 / 剩余问题
- 是否阻断后续流程
- 简要质量摘要

分数展示规则：

- 机器结果保留完整分数。
- 用户默认只看到简要质量摘要或简化等级，不展开详细评分项。

## 12. Standard File Model

标准文件必须是半结构化 Markdown，而不只是自然语言说明。第一阶段至少应包含以下字段类别：

1. 元信息
2. 检查项定义
3. 评分与阈值规则
4. 执行策略
5. 输出契约

### 12.1 Mode 级评分维度

评分维度按 mode 区分，而不是按文档类型各自定义 reviewer 主框架。

`quality` 维度：

- 完整性
- 清晰性
- 规范性
- 一致性

`feasibility` 维度：

- 可落地性
- 覆盖性
- 闭合性
- 验证性

文档类型差异通过检查项、阈值和修复策略表达，而不是通过 reviewer 本体硬编码分支表达。

## 13. Default Template Design

### 13.1 通用规则

默认模板采用“核心块 + 扩展块”分层模型：

- 核心块缺失会影响最小结构校验和 `quality` 通过。
- 扩展块默认提供，但允许项目按需调整。
- 模板提示语尽量短，不写成长篇教程。
- 核心章节不应只有标题骨架；默认模板应提供“提示语 + 小示例”，必要时补充“不要写什么”。
- 小示例采用混合策略：模板整体保持通用写法，但第一阶段默认语义面向大型通用后端文档设计。
- 三类文档继续保留统一风格的流程契约字段与 `## 文档引用` 表。
- 元信息区保持与当前 Plugin 模板元数据写法一致。

第一阶段的默认后端文档语义应偏向：

- 领域能力而非页面或交互流程
- 服务边界、模块职责和集成关系
- 输入输出、状态变化和数据一致性
- 异常处理、回归验证和可执行验收

当前 SDD Plugin 只是这套默认模板的首个落地场景，不应把模板正文写成只适配命令、Hook 或文件路径管理的专用文档风格。

### 13.2 PRD 默认模板

PRD 采用混合视角，但主结构以“需求树”组织：

- 背景与目标
- 目标用户 / 使用场景
- 问题陈述
- 范围（In / Out）
- 需求
  - 需求主题 A
    - 场景 1
    - 场景 2
  - 需求主题 B
    - 场景 1
    - 场景 2
- 成功标准
- 文档引用

规则：

- `需求` 是单一主块，不再拆成“核心需求概览”和“关键场景 / 示例”两个并列块。
- 成功标准采用中等粒度：既有高层结果，也有关键可验证点，但不侵占 spec 的职责。
- `背景与目标`、`需求`、`成功标准` 等核心章节应提供简短提示语和小示例。
- 默认示例应更贴近通用后端需求表达，例如能力边界、数据处理目标、服务行为和非功能约束，而不是仅限于插件命令流程。

### 13.3 Spec 默认模板

Spec 采用面向大型通用后端的混合中心结构：先给简短总览，再按多个领域能力分块展开。

推荐结构：

- 简短总览
- 范围 / 非范围
- 领域能力分块
  - 能力 1
    - 能力目标
    - 接口契约
    - 输入输出
    - 状态变化
    - 规则约束
    - 异常场景
    - 验收标准
    - 来源
  - 能力 2
  - 能力 3
- 依赖与约束
- 数据与一致性要求
- 上下游影响
- 文档引用

规则：

- `来源` 作为每个能力块内部字段，用于标注对应的 PRD 需求主题或场景。
- 不再单独保留一个大块的“与 PRD 的映射”章节。
- `规则约束` 指业务层约束，不指实现逻辑。
- `接口契约`、`输入输出`、`状态变化`、`异常场景` 等核心子节都应附带提示语和小示例。
- 默认组织中心是“领域能力 -> 契约/规则/异常/验收”，而不是把 API 端点列表本身作为唯一主线。

### 13.4 Plan 默认模板

Plan 采用面向大型通用后端的技术方案主导型结构，技术方案深度接近实现级，并以“架构边界 + 数据流 / 一致性 + 模块落地”的混合中心组织。

推荐结构：

- 背景与目标
- 实施范围 / 非范围
- 技术方案总览
- 架构边界
- 关键数据流 / 控制流
- 状态变化与一致性要求
- 模块与文件影响
- 接口 / 契约变化
- 风险与兼容性处理
- 测试策略
- Implementation Tasks
- 验收映射
- 文档引用

`Implementation Tasks` 规则：

- 按技术主题或模块分组。
- 组内按执行顺序展开。
- 每个任务默认高细度，至少包含：
  - 任务目标
  - 涉及文件 / 模块
  - 接口或契约变化
  - 实现步骤
  - 验证与完成判据
  - 与 `spec` / 技术方案的映射
- `技术方案总览`、`架构边界`、`关键数据流 / 控制流`、`状态变化与一致性要求` 等章节应提供提示语和小示例，以帮助 Agent 在编码前读出系统位置、边界和约束。

测试组织规则：

- 采用“集中式测试策略 + 任务级验证闭环 + 验收映射”的混合模型。
- 不是所有任务都强制要求自动化测试。
- 代码、脚本、Hook、配置、文档任务都必须具备与其类型匹配的验证方式。
- 默认验证表达应偏向大型通用后端常见场景，例如单元测试、集成验证、状态检查、契约校验、回归命令和一致性验证。

## 14. Skill Behavior Changes

### 14.1 `/sdd:init`

新增职责：

- 在初始化项目时展示可选模板包列表，并允许用户选择其中一套。
- 将所选模板包中的 `PRD / Spec / Plan` 模板与标准完整展开到 `.sdd/templates/`。
- 如果用户未显式切换，则使用默认模板包。
- 第一阶段不要求把“用户选择了哪个模板包”写入项目元数据文件。

### 14.2 `/sdd:new`

职责调整：

- 保持版本骨架初始化职责。
- 不再负责展开 `PRD / Spec / Plan` 模板与标准资产。
- 不负责模板包选择。

### 14.3 `/sdd:prd`

新增行为：

- 生成阶段只读取 `.sdd/templates/prd/template.md` 和对应标准文件。
- 如果 `.sdd/templates/prd/` 下必要文件缺失，则直接失败并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
- 本轮写入完成并通过最小结构校验后，自动触发 `quality`。
- 低风险问题允许自动修复。
- 需求语义不清时生成候选改写并等待用户确认。
- `quality` 未通过时阻断进入下一稳定状态。

### 14.4 `/sdd:spec`

新增行为：

- 生成阶段只读取 `.sdd/templates/spec/` 下的模板与标准。
- 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
- 自动按顺序触发 `quality -> feasibility`。
- `quality` 强阻断。
- `feasibility` 默认弱阻断，但必须输出风险与建议。
- reviewer 结果与用户确认点共同决定 spec 是否可继续推进审批。

### 14.5 `/sdd:plan`

新增行为：

- 生成阶段只读取 `.sdd/templates/plan/` 下的模板与标准。
- 如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。
- 自动按顺序触发 `quality -> feasibility`。
- `quality` 未通过时阻断。
- `feasibility` 在 `plan` 上比 `spec` 更严格，但仍保留高杠杆技术决策的用户确认边界。
- 自动修复权限高于 `PRD / Spec`，但不擅自切换架构路线。

### 14.6 独立复审入口

需要新增独立 review 入口，用于：

- 对已有文档重新执行 reviewer。
- 选择 mode 或沿用默认 mode。
- 在手工修改后再次收敛文档质量。
- 复用 `.sdd/templates/` 中当前项目实际生效的模板与标准。

## 15. Testing and Verification Strategy

### 15.1 测试分类

后续实现至少需要覆盖：

1. 模板包选择与项目资产展开测试
2. 命令接入测试
3. reviewer 闭环测试
4. 输出契约测试
5. 回归与安全边界测试

### 15.2 关键验证点

应至少验证：

- `/sdd:init` 会展示可选模板包，并把所选模板包完整展开到 `.sdd/templates/`。
- 未显式选择时会使用默认模板包。
- 运行时只读取 `.sdd/templates/`，缺失必要文件时明确失败，不回退到 Plugin 内置资产。
- `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 按矩阵自动触发 reviewer。
- reviewer 在单次 subagent 调用内按串行方式执行有限轮次闭环。
- 达到阈值、达到轮次上限、无有效改进、需要用户确认时，都会正确停止。
- `PRD / Spec` 的语义类问题生成候选改写，而不是直接改写正文。
- 用户默认只看到 1 份简洁回执，命令层只依赖结构化机器结果。
- 项目级标准修改后，reviewer 行为随之变化，而不需要改 reviewer 本体。

## 16. Acceptance Criteria

以下条件全部满足时，本规格视为被正确实现：

1. Plugin 内置多套命名模板包，每套模板包同时包含 `PRD / Spec / Plan` 的模板与标准资产。
2. `/sdd:init` 会展示可选模板包，并把所选模板包完整展开到项目 `.sdd/templates/`。
3. 如果用户未显式切换，`/sdd:init` 会使用默认模板包。
4. 第一阶段不要求在项目中记录“最初选择了哪个模板包”的元数据文件。
5. 运行时的 `/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和独立 review 入口只读取 `.sdd/templates/`，不降级到 Plugin 内置资产。
6. 如果 `.sdd/templates/` 缺失必要文件，相关命令会明确失败，而不是自动回退。
7. 自动 review 的触发点被定义为“命令完成本轮文档写入并通过最小结构校验之后”。
8. 命令层存在 pre-review gate，reviewer 内部存在防御性 admission check。
9. `doc Reviewer-Subagent` 对外保持单入口，对内支持 `quality` 和 `feasibility` 两个 mode。
10. 默认触发矩阵为：`prd -> quality`，`spec -> quality + feasibility`，`plan -> quality + feasibility`。
11. reviewer 在单次 subagent 调用内以串行方式执行有限轮次闭环，不将同一文档的连续优化拆成多个并行 reviewer。
12. reviewer 具备四类停止条件：达到阈值、达到最大轮次、进入用户确认状态、无法继续产生有效改进。
13. `PRD / Spec` 的低风险问题允许自动修复；需求语义不清时生成候选改写而不是直接落正文。
14. `Plan` 的自动修复权限高于 `PRD / Spec`，可主动修复任务拆分、执行顺序、验证缺口和验收映射等低至中风险问题。
15. 通过规则采用“有分数，但阻断项优先”。
16. `quality` 的结构性和流程契约问题默认更容易阻断；`feasibility` 默认只有高风险断层或明显不可执行时才阻断。
17. reviewer 输出被区分为机器输出和用户输出两层。
18. 一次 review 调用允许产生多个轮次 / mode 级机器输出，但默认只向用户返回 1 份聚合后的简洁回执。
19. 用户回执默认展示 mode、总迭代轮次、自动修复摘要、待确认项 / 剩余问题、阻断状态和简要质量摘要，不展开完整评分明细。
20. `quality` 的评分维度为：完整性、清晰性、规范性、一致性。
21. `feasibility` 的评分维度为：可落地性、覆盖性、闭合性、验证性。
22. `PRD` 默认模板采用需求树结构，单一 `需求` 主块下承载多个需求主题和场景。
23. `Spec` 默认模板采用多个功能分块，每个功能块包含行为定义、输入输出、异常场景、规则约束、验收标准和来源。
24. `Plan` 默认模板采用技术方案主导型结构，技术方案深度接近实现级，任务项包含 `验证与完成判据`。
25. `PRD / Spec / Plan` 三类模板继续沿用当前元数据风格，并统一保留 `## 文档引用` 表与流程契约字段。
26. 模板和标准支持用户直接在项目中修改，reviewer 行为与生成行为都会跟随项目运行时资产变化。
27. 第一阶段不扩展到 `research / DR / archive` 的同级 reviewer 体系。

## 17. Recommended Implementation Verification

后续实现完成后，至少应验证：

```bash
bash tests/test-skill-contracts.sh
bash tests/test-reference-validation.sh
bash tests/test-doctor-contract.sh
bash tests/test-mvp-acceptance.sh
bash scripts/package-local.sh
git diff --check
```

并补充覆盖以下新增能力的测试：

- `/sdd:init` 模板包选择与项目资产展开
- 运行时只读取 `.sdd/templates/`
- reviewer 自动触发与手动复审
- 机器输出与用户回执分层
- 候选改写与用户确认路径
- review 最大轮次与停止条件

## 18. Decision Summary

本规格采用以下设计立场：

- 默认模板包存在于 Plugin 中，并在 `/sdd:init` 时被完整展开到项目中。
- 运行时只使用 `.sdd/templates/` 中的项目资产，不做 Plugin fallback。
- reviewer 本体保持通用，不内置大量 `PRD / Spec / Plan` 专属处理逻辑。
- `quality` 与 `feasibility` 在一个 reviewer 内以 mode 分层，而不是混成单套判断标准。
- reviewer 在单次 subagent 调用内部串行完成有限轮次闭环。
- 文档生成、自动 review、自动修复、候选改写、阻断判断和用户确认共同构成质量闭环。
- `PRD / Spec / Plan` 的模板升级目标是交付更可靠的文档，并显著降低用户人工 review 与修改成本。
