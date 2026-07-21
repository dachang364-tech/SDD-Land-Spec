# SDD Plugin 设计规格：CONSTITUTION.default.md 对齐收敛

- 日期：2026-07-22
- 状态：draft
- 类型：Design Spec
- 目标：在不引入实现细节的前提下，将 `CONSTITUTION.default.md` 收敛为与当前 SDD 工作流一致的默认项目级流程宪法，补齐模板治理与 review 治理规则，并消除现有 DR 状态表述矛盾。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 现有默认宪法 | [CONSTITUTION.default.md](../../../CONSTITUTION.default.md) | - | 当前默认流程宪法，需在不降级约束强度的前提下统一术语与规则层级 |
| references | DR template 与 review 治理设计 | [2026-07-20-dr-template-and-review-governance-design.md](./2026-07-20-dr-template-and-review-governance-design.md) | - | 只抽取应上升为项目级默认流程约束的部分，不引入模板路径、schema、agent 等实现细节 |
| references | 规范化实现计划 | [2026-07-21-sdd-skills-claude-code-normalization-implementation.md](../plans/2026-07-21-sdd-skills-claude-code-normalization-implementation.md) | - | 对齐当前已落地的 workflow 语义，避免默认宪法与实现后的 skill 合同继续漂移 |

## 1. Context

当前 `CONSTITUTION.default.md` 已覆盖主流程门控、状态行格式、DR 分类、plan 约束、Hook 边界与失败时的状态保持规则，但仍存在三类问题：

1. 缺少模板治理与 review 治理的默认项目级规则，无法反映当前工作流中“运行时模板单一事实来源”与“review 作为正式 gate”的原则。
2. DR 规则存在内在矛盾：文档状态枚举将 DR 限制为 `drafting / accepted / closed`，但后续条款又写成“关闭为 `committed`”，同一份默认宪法内出现两套终态表述。
3. 现有规则主要描述 `plan` 与 `code` 门控，对 `research / prd / dr / spec / plan` 在 review 流程中的关系缺少统一高层约束，导致这些行为只能散落在各个 skill 合同里表达。

因此，这次变更不是把设计规格或实现细节照搬进宪法，而是把已经成为默认工作流前提的高层规则提升到宪法层，并删除与当前工作流不再一致的模糊或冲突表述。

## 2. Goals

1. 为默认宪法补齐“运行时模板单一事实来源”的高层规则。
2. 为默认宪法补齐“review 是正式流程 gate”的高层规则。
3. 明确 `research / prd / dr` 仅进入 `quality review`，`spec / plan` 进入 `quality -> feasibility`。
4. 明确 review 阻断或失败时不得自动推进状态或执行 accept/dismiss/done/close 一类流程动作。
5. 统一 DR 状态终态表述，消除 `closed` 与 `committed` 混用。
6. 保持宪法文件仍只表达项目级流程约束，不下沉为实现手册。

## 3. Non-Goals

本次不纳入：

- 模板包目录、运行时模板目录、具体文件路径。
- `doc-reviewer`、schema、agent、JSON 载荷等实现合同。
- package、README、TESTING、自动化测试的具体更新要求。
- 某个 skill 的 admission check、prompt 结构、字段映射或脚本行为。
- 对 `CONSTITUTION.default.md` 之外的其他默认文档做同步改写。

## 4. Core Design Principles

### 4.1 宪法只描述项目级默认规则

`CONSTITUTION.default.md` 只保留对所有 SDD skill、subagent 和项目执行者都成立的默认流程约束。路径、资产、schema、打包、测试和具体编排实现属于下层合同，不进入宪法正文。

### 4.2 运行时模板规则属于高层原则

受 SDD 管理的文档，其运行时结构与质量规则必须以项目内运行时模板为唯一事实来源。默认宪法可以表达“单一事实来源”原则，但不应写入具体模板目录或文件名。

### 4.3 review 是正式 gate，不是可选附加动作

review 必须成为受管文档工作流中的正式门控环节。不同文档类型进入的 review 链路可以不同，但默认宪法必须明确“先过 review gate，再决定是否推进状态或后续阶段”。

### 4.4 状态推进与 gate 结果解耦

review 通过、verification 通过，是允许后续动作发生的前提，不等于系统自动完成状态推进。状态推进仍由对应 SDD skill 按职责完成。

### 4.5 默认宪法必须自洽

同一个实体的合法状态集合、终态名称、关闭条件和失败回退规则，必须在默认宪法内部保持单一说法，不能再出现 `closed` / `committed` 这种并列且未解释的冲突表达。

## 5. Proposed Constitution Changes

### 5.1 阶段门控保持，但增加 gate 原则

保留主流程：

- `/sdd:init -> /sdd:new -> /sdd:prd -> /sdd:spec -> /sdd:plan -> /sdd:code -> /sdd:archive`

并补充：

- 受管文档的创建、更新、review、实现与归档都必须经过对应 gate，不能绕过。
- 后续阶段只能建立在前置阶段已满足其最小门控条件之上。

### 5.2 新增模板治理规则

新增一组高层规则，表达：

- 受管文档的运行时结构与质量规则必须来自项目内运行时模板。
- skill 内置模板、示例文本或其他静态资源不能作为运行时事实来源。
- 若运行时模板缺失，相关 skill 应视为前置条件不满足，而不是静默回退到其他来源。

### 5.3 新增 review 治理规则

新增一组高层规则，表达：

- `research / prd / dr` 只进入 `quality review`。
- `spec / plan` 进入 `quality review`，通过后才可进入 `feasibility review`。
- `dr` 不进入 `feasibility review`。
- review 失败或阻断时，不得自动推进文档状态、plan 状态或 DR 状态。
- review 通过只表示 gate 已满足，不等于自动 accept、dismiss、done 或 close。

### 5.4 收敛 DR 流程规则

保留现有 DR 分类与主干约束，但统一措辞：

- code-class DR 仍要求 `accepted` 后才能生成对应 plan。
- lightweight fix DR 仍要求通过 `/sdd:code` verification 后才能进入终态。
- 文档类 DR 与代码类 DR 的区别继续保留在“是否需要 plan / code”层，而不是混入 review 链路中。
- DR 新建后进入质量门控，质量门控本身不替代 accept/dismiss 决策。

### 5.5 统一 DR 终态表述

默认宪法必须统一 DR 合法状态与终态语义。建议保留现有状态集合中的 `closed` 作为唯一终态表述，并删除“关闭为 `committed`”这类冲突说法。

理由：

- 当前状态枚举已经定义为 `drafting / accepted / closed`。
- 保留 `closed` 可以避免整份默认宪法再引入额外状态名。
- 若某个实现层仍使用 `committed` 文案，应在下游合同中统一改回默认宪法语义，而不是让宪法迁就历史漂移。

## 6. Recommended Section Structure

建议保留现有章节框架，并做如下调整：

1. `阶段门控`
2. `文档状态`
3. `模板治理`（新增）
4. `review 治理`（新增）
5. `DR 流程`
6. `Plan 约束`
7. `Skill 身份`
8. `Subagent / Code Worker 约束`
9. `Hook 行为`
10. `错误处理`
11. `用户修改`

这样可以避免把新增规则硬塞进旧章节，导致条款继续散乱。

## 7. Draft Rule Intent

建议新增或改写的条款意图如下：

- `模板治理`：声明项目运行时模板是单一事实来源，缺失即前置条件不满足。
- `review 治理`：声明不同文档类型进入的 review 链路，以及 review 与状态推进的关系。
- `DR 流程`：声明 DR 的质量门控属于正式流程前置，但不等于 accept/dismiss。
- `文档状态`：统一 DR 终态，只保留一套状态语言。
- `错误处理`：把 review 失败时的状态保持规则显式写出，与 code/verification 失败规则并列。

## 8. Acceptance Criteria

以下条件全部满足时，本设计视为正确落地：

1. `CONSTITUTION.default.md` 明确包含模板治理高层规则，但不包含模板路径等实现细节。
2. `CONSTITUTION.default.md` 明确包含 review 治理高层规则，并区分 `research / prd / dr` 与 `spec / plan` 的 review 链路。
3. `CONSTITUTION.default.md` 明确 `dr` 不进入 `feasibility review`。
4. `CONSTITUTION.default.md` 明确 review 阻断或失败时不得自动推进状态。
5. `CONSTITUTION.default.md` 内部不再同时出现未解释的 `closed` 与 `committed` 终态冲突。
6. 文件整体仍保持“项目级流程宪法”层级，而不是退化为实现说明书。

## 9. Decision Summary

本次收敛采用以下设计立场：

- 默认宪法需要与当前实际工作流在高层规则上对齐。
- `DR` 的 review gate 与运行时模板治理已经是项目级规则，应进入默认宪法。
- 模板路径、schema、agent、打包、测试仍属于下层实现合同，不进入默认宪法。
- 统一术语和状态语义比局部补丁更重要；既然收敛，就应一次消除宪法内部的显性矛盾。
