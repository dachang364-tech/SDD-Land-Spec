# SDD Skills Claude Code 规范化改造设计

- 日期：2026-07-21
- 状态：draft
- 类型：Design Spec
- 目标：在不破坏现有核心能力合同的前提下，重构 `skills/` 下保留 Skill 的 Claude Code 技能合同、模板治理、路径结构与 review 编排，使其符合 `/skill-creator` 的规范化要求，同时落地新的版本内文档信息架构，并移除 `doctor` / `status` 两个不再保留的命令。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 文档生成模板治理基线 | [2026-07-20-document-generation-skills-template-governance-design.md](./2026-07-20-document-generation-skills-template-governance-design.md) | - | 复用 `.sdd/templates/` 作为运行时唯一模板来源，并扩展到 `dr` 与新的版本目录结构 |
| references | DR 模板治理与 review 接入 | [2026-07-20-dr-template-and-review-governance-design.md](./2026-07-20-dr-template-and-review-governance-design.md) | - | 复用 DR 模板治理与 review 接入原则，但以当前会话确认的新目录 `dr/` 替换历史 `decisions/` |
| references | SDD 主流程与命令边界 | [2026-07-11-sdd-plugin-mvp-workflow-spec-design.md](./2026-07-11-sdd-plugin-mvp-workflow-spec-design.md) | - | 继承整体 SDD 生命周期，但修正 archive、review、version 内目录与命令集合 |
| references | `/sdd:init` 与模板物化边界 | [2026-07-15-init-manual-dependency-install-design.md](./2026-07-15-init-manual-dependency-install-design.md) | - | 保持 `/sdd:init` 不安装依赖、不创建版本，仅初始化项目级骨架与模板资产 |
| references | 项目级 Skill 改造约束 | [CLAUDE.md](/Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/CLAUDE.md) | - | 本次涉及 `skills/*/SKILL.md` 的改造必须经过 `/skill-creator` 约束，并保留现有能力合同 |

## 1. Context

当前仓库中的 Skill 体系已形成一套以 `/sdd:*` 命令为入口的 SDD 工作流，但仍存在以下结构性问题：

1. 多个 Skill 的 `SKILL.md` 仍偏向旧的命令说明风格，尚未系统满足 Claude Code Skills 的 frontmatter、description、触发边界、输出合同和 agent 编排规范。
2. 文档生成与 review 的模板治理虽然已在 `research / prd / spec / plan` 上形成雏形，但 `dr` 尚未完全纳入统一模板矩阵。
3. 版本内文档目录结构与当前产品意图不一致，尤其是：
   - `docs/requirements/` 仍承载 research 语义
   - `prd` 仍被视为平铺文件
   - `specs / plans / decisions` 使用历史复数目录
4. `doctor` 与 `status` 两个命令的价值已被弱化：
   - 它们重复承载了部分原本应由运行时模板、state、review admission 和命令前置条件承担的约束
   - 在新结构下会进一步增加维护漂移
5. `review` 仍内含部分不应由其硬编码承担的结构准入逻辑，需要进一步把规则下沉到模板与标准文件。
6. 现有 `archive`、`new`、`review`、`dr` 等 Skill 仍引用旧的 `decisions/`、`specs/`、`plans/`、`docs/requirements/` 等历史路径，需要与新的版本内目录矩阵统一。

同时，项目级 `CLAUDE.md` 已明确要求：凡是新增或改造 `skills/*/SKILL.md`，必须先以 `/skill-creator` 作为标准生成工具，旧 Skill 文本只能作为迁移参考，不能直接视为最终规范。本次设计正是该要求在全量 Skill 改造上的落地说明。

## 2. Goals

1. 对 `skills/` 下保留的全部 Skill 完成一轮 Claude Code 规范化改写，统一其 frontmatter、description、触发条件、章节结构、流程合同与输出边界。
2. 在不改变核心能力意图的前提下，落实新的版本内文档信息架构：`research / prd / spec / plan / dr`。
3. 统一模板治理模型：运行时只读取项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/<type>/`，Skill 与 reviewer 只负责编排流程，不硬编码结构规则。
4. 保持单 active version 模型，并将 archived version 明确定义为“只读、可引用、不可修改/不可 review/不可 code”的历史资产。
5. 延续当前 `archive` 的索引式归档模型，不引入物理迁移。
6. 删除 `/sdd:doctor` 与 `/sdd:status`，同步清理 README、TESTING、测试合同与 Skill 列表中的相关描述。
7. 保证 `/skill-creator` 被写入本次设计与后续实现计划，作为全量 Skill 改造的标准生成与规范化工具。
8. 先完成全量规范化改写，再对高风险 Skill 做完整 eval loop，而不是在第一轮对所有 Skill 全量跑评估。

## 3. Non-Goals

本次设计不要求实现：

- 为尚未实现的模板包（例如 `frontend`）提供实际模板内容。
- 重写 `archive` 的业务语义为物理迁移模型。
- 改造 `new` 以承载“从某个历史版本演进而来”的显式来源声明。
- 改写 `code` 为扫描整个 version 的开放式实现器；它仍然以 `plan` 为直接输入。
- 扩展 `dr` 的 tag 枚举或变更其文件命名规则。
- 让 `review` 保留硬编码的文档结构判断矩阵；结构规则必须下沉到模板与标准资产中。
- 在本次设计中直接定义所有 eval 用例、断言和 viewer 细节；这些属于后续高风险 Skill 的评估计划。

## 4. Global Constraints

### 4.1 `/skill-creator` 是 Skill 改造的标准工具

任何 `skills/*/SKILL.md` 的新增、重写、扩展、规范化改造，都必须先经过 `/skill-creator` 约束。实施时应遵守：

1. 先用 `/skill-creator` 提炼或生成新的 Skill 合同结构。
2. 旧 `SKILL.md` 仅作为迁移参考，不直接当作最终规范。
3. 所有规范化结果必须继续满足本项目 README、TESTING、脚本、模板和测试中既有的关键能力合同。

### 4.2 保留能力优先，结构重排例外

除本设计明确重构的领域外，其余 Skill 默认遵循：

- 功能意图保持现状
- 只做 Claude Code Skills 规范化
- 只做与新路径、新模板矩阵、新 review 规则相关的必要适配

本次明确的结构重排例外包括：

- `research` 从项目级迁为 version-scoped
- `prd` 改为 `prd/` 目录中的单正式文件
- `spec / plan / dr` 目录命名和路径矩阵重排
- 删除 `doctor` / `status`
- `dr` 从 `decisions/` 迁为 `dr/`

### 4.3 所有保留 Skill 同时支持两类触发

每个保留 Skill 都应同时支持：

1. 用户显式 slash command 触发
2. 明确语义触发

但语义触发必须收窄到该 Skill 的明确业务语义，不得宽泛泛化。

### 4.4 保留 Skill 内容统一中文

所有保留 Skill 的 `SKILL.md` 实现内容必须统一使用中文，包括：

- 正文章节标题
- 步骤说明
- 前置条件
- 失败提示
- 输出合同
- 触发语义说明
- 内部编排说明

允许保留英文的范围仅包括：

- slash command 名称
- 文件路径
- 环境变量
- JSON key
- 状态值
- 文件名
- 必要技术标识

对应的模板资产正文与标准说明也应统一使用中文，避免出现 Skill 是中文、模板或标准是英文的混杂状态。

### 4.5 archived version 只读

一旦某版本被 `/sdd:archive` 归档：

- 仍保留在 `docs/versions/vX.Y.Z/`
- 其文档可被新版本读取和引用
- 但不能再被 `research / prd / spec / plan / dr / review / code` 修改或执行

## 5. Skill Set After Migration

### 5.1 保留并规范化的 Skill

- `init`
- `new`
- `research`
- `prd`
- `spec`
- `plan`
- `review`
- `archive`
- `triage`
- `code`
- `dr`

### 5.2 删除的 Skill

- `doctor`
- `status`

删除要求：

1. 删除对应 `skills/<name>/SKILL.md`
2. 清理 README、TESTING 与测试脚本中的命令入口、合同与示例
3. 不保留兼容入口

## 6. Information Architecture

### 6.1 项目级资产

项目级只保留：

- `docs/CONSTITUTION.md`
- `docs/versions/`
- `docs/archive/`
- `${CLAUDE_PROJECT_DIR}/.sdd/templates/`

`docs/requirements/` 完全废弃，不再作为 research 输出位置。

### 6.2 版本目录结构

`/sdd:new vX.Y.Z` 创建唯一 active version 时，应创建空目录：

```text
docs/versions/vX.Y.Z/
├── state.json
├── research/
├── prd/
├── spec/
├── plan/
└── dr/
```

规则：

- 这些目录都是空目录
- 不预建任何正文文件
- 旧的 `specs / plans / decisions` 目录命名改为 `spec / plan / dr`
- `prd/prd.md` 不由 `/sdd:new` 创建，而由 `/sdd:prd` 首次生成

### 6.3 文档输出路径矩阵

```text
research -> docs/versions/vX.Y.Z/research/<type>-<YYYY-MM-DD>-<slug>.md
prd      -> docs/versions/vX.Y.Z/prd/prd.md
spec     -> docs/versions/vX.Y.Z/spec/<slug>.md
plan     -> docs/versions/vX.Y.Z/plan/<slug>.md
dr       -> docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md
```

补充规则：

- `research` 的 `<type>` 允许自由但受控的 kebab-case 类型词，不使用固定枚举。
- `research` 的 `<date>` 固定为 `YYYY-MM-DD`。
- `spec / plan` 文件名规则沿用现有规则，不在本次改造中重写。
- `dr` 的文件命名、tag 枚举、slug 规则、`DR ID` 规则保持现状不变，仅目录从 `decisions/` 改为 `dr/`。
- 所有正式引用路径中，原 `../decisions/...` 统一改为 `../dr/...`。

## 7. Lifecycle Model

### 7.1 `/sdd:init`

职责：

- 初始化项目级骨架
- 物化运行时模板资产到 `${CLAUDE_PROJECT_DIR}/.sdd/templates/`
- 不创建任何 version 内目录
- 不安装依赖
- 不创建文档正文

模板包选择合同：

- 机制上支持多模板包选择，例如 `backend`、`frontend`
- 当前实际只提供 `backend`
- 若用户选择未实现模板包，直接失败并提示不可用
- 若用户未显式切换，则使用默认模板包
- 重复执行只补齐缺失文件，不覆盖用户已定制模板

### 7.2 `/sdd:new`

职责：

- 创建唯一 active version
- 创建版本内空目录骨架
- 写入 `state.json`

创建结果：

```text
docs/versions/vX.Y.Z/
├── state.json
├── research/
├── prd/
├── spec/
├── plan/
└── dr/
```

这些目录都应创建为空目录，不预建正文文件。

边界：

- 若已存在 active version，直接失败并要求先 archive
- 不修改已有版本的 `state.json`
- 不更新 `docs/archive/` 索引
- 不预建 `prd/prd.md`
- 不声明“从某个历史版本演进而来”的来源语义

### 7.3 `/sdd:archive`

职责：

- 对整个 active version 执行归档
- 生成或更新版本内 `ARCHIVE.md`
- 更新 `docs/archive/INDEX.md`
- 将版本 state 置为 `archived`

边界：

- 不物理迁移版本目录
- archive 后版本进入只读
- archive 后只能查询和引用，不能再修改或 review

### 7.4 active / archived 写入规则

以下 Skill 在写入前都必须要求目标 version 处于 active 且非 archived：

- `research`
- `prd`
- `spec`
- `plan`
- `dr`
- `review`
- `code`

对 archived version：

- 不允许写入
- 不允许 review
- 不允许 code
- 允许被后续版本引用

## 8. Runtime Template Governance

### 8.1 运行时唯一事实来源

文档结构与质量规则的唯一事实来源是项目运行时模板目录：

```text
${CLAUDE_PROJECT_DIR}/.sdd/templates/
├── research/
│   ├── template.md
│   └── quality.standard.md
├── prd/
│   ├── template.md
│   └── quality.standard.md
├── spec/
│   ├── template.md
│   ├── quality.standard.md
│   └── feasibility.standard.md
├── plan/
│   ├── template.md
│   ├── quality.standard.md
│   └── feasibility.standard.md
└── dr/
    ├── template.md
    └── quality.standard.md
```

### 8.2 规则下沉

- `template.md` 定义文档骨架、必要元信息与正式结构要求
- `quality.standard.md` 定义 quality review 标准
- `feasibility.standard.md` 仅用于 `spec / plan`

Skill 与 reviewer 不应硬编码：

- 某类文档必须有哪些章节
- 是否强制 `## 文档引用` 表
- 质量项、阈值与判定逻辑

这些都必须由模板与标准文件定义。

### 8.3 plugin 资产职责

Plugin 内置模板包只用于 `/sdd:init` 物化，不能在运行时作为 fallback。任何必要模板缺失时，相关命令必须显式失败。

## 9. Document Behavior Matrix

### 9.1 research

- version-scoped
- 无状态机制
- 不自动触发 review
- 允许后续手动 `/sdd:review`
- 同名文档存在时，用户确认后可直接更新
- 不强制 `## 文档引用` 表

### 9.2 prd

- version-scoped
- 一个版本只有一个正式 PRD：`prd/prd.md`
- 自动触发 `quality` review
- 若 `prd.md` 已存在，不直接覆盖，需先与用户讨论并确认后更新
- 不走 `DR` 变更门
- 不强制 `## 文档引用` 表

### 9.3 spec

- version-scoped
- 一个版本允许多份 spec
- 自动触发 `quality -> feasibility`
- 文档有状态
- 同名文档若已终态，禁止直接修改，必须转 `DR`
- 同名文档若未终态，也需用户确认后更新
- 新 slug 文档不受旧同名文档状态影响
- 强制 `## 文档引用` 表（由模板和标准定义）

### 9.4 plan

- version-scoped
- 一个版本允许多份 plan
- 自动触发 `quality -> feasibility`
- 文档有状态
- 同名文档若已终态，禁止直接修改，必须转 `DR`
- 同名文档若未终态，也需用户确认后更新
- 新 slug 文档不受旧同名文档状态影响
- 强制 `## 文档引用` 表（由模板和标准定义）

### 9.5 dr

- version-scoped
- 自动触发 `quality`
- 文档有状态
- 若同名 `DR` 已终态，不能回写，必须新建新的 `DR`
- `DR` 的正式文档引用只允许：`dr / plan / spec`
- 不允许 `prd / research`
- 强制 `## 文档引用` 表（由模板和标准定义）

## 10. Review Orchestration

### 10.1 `/sdd:review` 的双角色定位

`review` 同时承担：

1. 用户可直接调用的文档 review 命令
2. 其他 Skill 的内部 review 编排单元

### 10.2 外部调用入口

对外主入口采用：

- 用户提供 `doc-path`
- 系统自动识别 `document_type`
- 系统自动决定 mode 或 mode 链路

支持路径矩阵：

- `docs/versions/vX.Y.Z/research/*.md`
- `docs/versions/vX.Y.Z/prd/prd.md`
- `docs/versions/vX.Y.Z/spec/*.md`
- `docs/versions/vX.Y.Z/plan/*.md`
- `docs/versions/vX.Y.Z/dr/*.md`

不在矩阵内则直接失败，并提示“不是受支持的 SDD 文档路径”。

### 10.3 默认 review 链路

```text
research -> quality
prd      -> quality
dr       -> quality
spec     -> quality -> feasibility
plan     -> quality -> feasibility
```

串行阻断规则：

- `spec / plan` 的 `quality` 未通过时，不进入 `feasibility`

archived version 规则：

- `/sdd:review` 不能对 archived version 的文档执行任何操作

### 10.4 reviewer 与 subagent

自动 review 与手动 review 都必须进入 reviewer 及其 subagent 执行链路，而不是只在 Skill 文本中口头说明“建议 review”。

reviewer 只负责：

- 流程编排
- 调用对应模板与标准
- 聚合结果
- 生成用户回执

reviewer 不负责硬编码结构规则。

这意味着：

- `review` 只负责识别路径、识别类型、决定 mode 与编排 reviewer 链路
- 文档必须具备哪些章节、是否强制 `## 文档引用` 表、quality / feasibility 的通过依据，都由对应 `template.md`、`quality.standard.md`、`feasibility.standard.md` 定义
- 实现时不得把这些规则重新写回 `review` 的硬编码判断矩阵

## 11. Trigger Contracts

所有保留 Skill 都同时支持：

1. 显式 slash command 触发
2. 明确语义触发

语义边界如下：

- `init`：初始化项目 SDD 结构、补齐模板资产
- `new`：创建新版本、开启新的版本骨架
- `research`：生成版本内需求调研或技术调研文档
- `prd`：为当前版本生成或更新正式 PRD
- `spec`：为功能或工作项生成规格文档
- `plan`：为 spec 或工作项生成实施计划
- `review`：对某份受管文档执行 review
- `archive`：归档整个版本
- `triage`：判断下一步应走哪个 SDD 文档路径
- `code`：依据某份 plan 进入实现
- `dr`：记录或处理正式决策

语义触发必须保持收敛，不得因为任意模糊关键词误触发。

## 12. Skill-Specific Notes

### 12.1 triage

- 保持现状，主要输出“下一步该走哪个 SDD 文档路径”
- 可读取 archived version 的文档作为参考
- 不修改文档、不运行 archive、不替用户创建 DR

### 12.2 code

- 直接输入必须是某份 `plan`
- 只读取该 `plan` 的 `## 文档引用` 闭包
- 不默认扫描整个 version
- 不默认读取未被该 `plan` 正式引用的文档
- archived version 中的 `plan` 不可执行

### 12.3 archive

- 保持当前实现模型：`ARCHIVE.md + docs/archive/INDEX.md`
- `docs/archive/` 是全局归档索引，不是物理归档目录

## 13. README / TESTING / Contract Test Alignment

本次设计要求同步修改：

1. README
   - 文档目录树更新为 `research / prd / spec / plan / dr`
   - 删除 `doctor / status`
   - 更新 `archive`、`review` 与 `code` 的输入边界说明
   - 把 `decisions/` 的说明统一改成 `dr/`

2. TESTING
   - 删除 `doctor / status` 相关验证
   - 更新模板矩阵、目录树、review mode 与 archive 规则
   - 增加对 archived version 禁止写入 / review / code 的验证说明

3. 自动化测试
   - 更新路径矩阵、Skill 合同断言、模板资产矩阵
   - 删除 `doctor / status` 相关测试
   - 更新 `archive`、`review`、`new`、`dr`、`code` 的合同断言

## 14. Migration Plan Outline

### 14.1 第一步：结构与合同规范化

按以下顺序做全量 Skill 规范化：

1. `init`
2. `new`
3. `research`
4. `prd`
5. `spec`
6. `plan`
7. `review`
8. `archive`
9. `triage`
10. `code`
11. `dr`
12. 删除 `doctor`
13. 删除 `status`

每个 Skill 的改造都必须以 `/skill-creator` 为规范约束来源。

### 14.2 第二步：模板与路径治理落地

- 调整 `.sdd/templates/` 矩阵，纳入 `dr`
- 调整所有文档路径与正式引用路径
- 把 `decisions/` 全部迁为 `dr/`
- 调整 `spec / plan / dr` 的状态门与更新规则表达

### 14.3 第三步：测试与文档对齐

- 更新 README / TESTING
- 更新测试合同
- 删除 `doctor / status` 相关断言

### 14.4 第四步：高风险 Skill 评估

完成全量规范化改写后，再选择高风险 Skill 做完整 `/skill-creator` eval loop。高风险优先考虑：

- `review`
- `archive`
- `code`
- `dr`
- `spec`
- `plan`

## 15. Acceptance Criteria

以下条件全部满足时，本设计视为正确实现：

1. 所有保留 Skill 的 `SKILL.md` 已按 Claude Code 规范重写，并显式受 `/skill-creator` 约束。
2. `doctor` 与 `status` 已被完整删除，且 README / TESTING / 测试合同中不再保留命令入口。
3. 项目运行时模板矩阵包含 `research / prd / spec / plan / dr`，且 `dr` 使用 `template.md + quality.standard.md`。
4. `docs/requirements/` 不再作为 research 输出位置。
5. 版本内目录树更新为 `research / prd / spec / plan / dr`。
6. `prd` 固定输出到 `docs/versions/vX.Y.Z/prd/prd.md`。
7. `dr` 固定输出到 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。
8. 所有正式引用中的历史 `../decisions/...` 已统一替换为 `../dr/...`。
9. `/sdd:init` 只创建项目级骨架与模板资产，不创建 version 内目录。
10. `/sdd:new` 创建空的 version 内目录，并保持单 active version 模型。
11. archived version 保持在 `docs/versions/vX.Y.Z/` 原位置，且通过 `ARCHIVE.md + docs/archive/INDEX.md` 建立归档入口。
12. archived version 对 `research / prd / spec / plan / dr / review / code` 都是只读禁写。
13. `review` 对外以 `doc-path` 为主入口，自动识别类型与 mode 链路。
14. `review` 不再硬编码文档结构规则，而是依赖运行时模板与标准文件。
15. `code` 的直接输入是 `plan`，只读取该 `plan` 的正式引用闭包。
16. `research`、`prd`、`spec`、`plan`、`dr` 的更新规则与状态门符合本设计定义。
17. 完成全量规范化改写后，至少有一批高风险 Skill 被纳入完整 eval loop。

## 16. Decision Summary

本设计确立以下最终立场：

- Skill 改造以 `/skill-creator` 为标准工具，而不是手工续写旧 Skill。
- 模板与标准文件定义结构和质量规则；Skill 与 reviewer 只编排流程。
- 文档体系统一迁为 version-scoped 的 `research / prd / spec / plan / dr`。
- `doctor / status` 被视为当前版本不再保留的命令。
- `archive` 延续当前“原位归档 + 全局索引”的实现模型。
- archived version 是只读可引用资产。
- `code` 是 plan-driven 的实现 Skill，而不是版本扫描器。
- `review` 是自动识别路径、自动决定 mode 的统一评审入口。
- 先做全量规范化改写，再对高风险 Skill 进行完整评估，是本次最合适的落地顺序。
