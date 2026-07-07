# SDD CodeAgent Plugin — 设计文档

- **日期**：2026-07-07
- **状态**：已批准（brainstorming 阶段完成）
- **作者**：Dachang (@dachang364-tech)
- **仓库**：`SDD-Land-Spec`（本仓库根目录）
- **实现语言**：简体中文（zh-CN）—— 所有面向用户的文案、模板、命令输出、状态信息、文档示例、错误提示、commit 模板均使用中文。命令名、文件路径、glob 模式、配置键、技术术语保留英文。

## 1. 目的与背景

构建一个 CodeAgent Plugin（manifest 形式），把作者本人「规范驱动开发」（Spec-Driven Development，SDD）的工作流封装成 Skills、Commands、Hooks 和运行时状态。该 Plugin 是一个**流程编排器**，不是方法论的重新实现 —— 它从现有框架（Superpowers、Spec-Kit、OpenSpec）中取其精华，与项目本地约定做胶水整合。

### 1.1 目标

- 通过一组明确的斜杠命令与自然语言触发器，把项目从**需求 → 上线 → 归档**完整跑下来。
- 把文档（`spec.md`、`trd.md`、feature plan、ADR）作为一等资产，存放在 `docs/vX.Y.Z/` 之下。
- 实施 **TRD 边界护栏**：在不违反当前版本 `trd.md` 覆盖范围的代码改动允许自由进行（由 Superpowers 的 TDD 接管）；一旦越出范围，在写入 Hook 处**硬拦截**。
- 优先在 **Claude Code** 上跑通，对 OpenCode、CodeX 等其他 CodeAgent 通过显式的适配层接入。

### 1.2 非目标

- 不重新实现 brainstorming、TDD、verification —— 这些直接消费 Superpowers。
- 不从零写 spec / plan / tasks 模板 —— 借自 Spec-Kit（只做最小化定制）。
- 不构建跨平台运行时抽象层。每个平台单独一份薄薄的 adapter 目录。

### 1.3 实现语言约束

Plugin 内部所有面向用户的字符串 —— Skill 正文、命令输出、状态报告、模板（`spec.md`、`trd.md`、`feature-*.md`、ADR、bugfix 记录）、错误消息、commit-message 建议 —— 一律使用**简体中文**。以下内容保留英文：

- 斜杠命令名（`/sdd.*`）—— 是用户输入的标识符。
- 文件路径、glob 模式、manifest 键。
- 代码标识符、配置键、约定俗成的英文技术术语（如 `ADR`、`JSON`、`glob` 等）。
- 外部框架文档中的原文引用（如 Superpowers Skill 的标题）。

## 2. 架构总览

```
┌────────────────────────────────────────────────────────────┐
│            SDD CodeAgent Plugin（manifest 形式）            │
├────────────────────────────────────────────────────────────┤
│  Commands（指向 Skills 的薄别名）                            │
│   /sdd.init /sdd.new /sdd.spec /sdd.trd                    │
│   /sdd.prd /sdd.feature /sdd.code /sdd.bugfix /sdd.adr     │
│   /sdd.status /sdd.archive                                 │
├────────────────────────────────────────────────────────────┤
│  Skills（承载实际方法论）                                    │
│   sdd-init / sdd-new-version                               │
│   sdd-prd-writer / sdd-spec-writer / sdd-trd-writer         │
│   sdd-feature-planner / sdd-code-orchestrator              │
│   sdd-bugfix-triage / sdd-adr-writer                       │
│   sdd-status-reader / sdd-archiver                         │
├────────────────────────────────────────────────────────────┤
│  Hooks（路径 / 状态守卫）                                    │
│   SessionStart         — 向 context 注入项目状态             │
│   PreToolUse Write/Edit — 强制 TRD 覆盖范围                  │
│   PostToolUse Write/Edit — 更新 state.json 时间戳             │
│   PreCompact           — 快照当前阶段产物路径                 │
├────────────────────────────────────────────────────────────┤
│  状态（.sdd/state.json）                                     │
│   version, phase, branch, artifacts, guards, adr_pending    │
└────────────────────────────────────────────────────────────┘
           ↓ 调用 ↓
┌────────────────────────────────────────────────────────────┐
│  外部框架（不重新实现）                                       │
│   Superpowers: brainstorming / writing-plans / TDD /        │
│                verification-before-completion /             │
│                subagent-driven-development                  │
│   Spec-Kit:    specify / plan / tasks / converge 模板        │
│   OpenSpec:    archive / 变更管理模型                        │
└────────────────────────────────────────────────────────────┘
```

## 3. 状态机

```
NONE ──/sdd.init──▶ INITED ──/sdd.new vX.Y.Z──▶ PRD ──/sdd.spec──▶ SPEC
                                              ▲                    │
                                              │                    ▼
                                              │                  TRD
                                       (默认已存在)                  │
                                       或 /sdd.prd 生成              ▼
                                                                （逐个 feature）
                                                                FEATURE_PLAN ──/sdd.code──▶ CODE
                                                                                            │
                                                                                            │ /sdd.bugfix
                                                                                            ▼
                                                                                        BUGFIX ──▶ CODE
                                                                                            │
                                                                                            ▼
                                                                                        RELEASE
                                                                                            │ /sdd.archive
                                                                                            ▼
                                                                                        ARCHIVED
```

阶段可以重复进入（例如在 `TRD` 阶段回头编辑 `spec.md` 会写一个新版本，不会重置下游产物）。`state.json.phase` 记录达到的最高阶段；各产物的具体状态存放在 `state.json.artifacts.<name>.status`。

**关于 PRD 阶段**：默认假设 `docs/vX.Y.Z/prd.md` 在 `/sdd.new` 之前就已存在（由产品方提供、从前一版本继承，或由 `/sdd.prd` 在 `/sdd.new` 之后生成）。`/sdd.spec` 必须先看到 PRD 才能产出 User Story —— 这是 SDD 流程的输入契约。若 PRD 缺失，`/sdd.spec` 拒绝运行并提示「运行 `/sdd.prd` 生成或手动导入 PRD」。

### 3.1 `.sdd/state.json` schema

```json
{
  "version": "1.0.1",
  "phase": "TRD",
  "branch": "feat/v1.0.1-payment",
  "artifacts": {
    "prd":   { "path": "docs/v1.0.1/prd.md",      "status": "approved", "updated_at": "2026-07-07T09:00:00Z" },
    "spec":  { "path": "docs/v1.0.1/specs/spec.md",  "status": "approved", "updated_at": "2026-07-07T10:00:00Z" },
    "trd":   { "path": "docs/v1.0.1/plans/trd.md",   "status": "draft",    "updated_at": "2026-07-07T11:00:00Z" },
    "features": [
      { "name": "feature-login",   "path": "docs/v1.0.1/plans/feature-login.md",   "status": "planned" },
      { "name": "feature-payment", "path": "docs/v1.0.1/plans/feature-payment.md", "status": "coding" }
    ],
    "adrs": [
      { "id": "0001-use-postgresql", "path": "docs/v1.0.1/decisions/0001-use-postgresql.md", "status": "accepted" }
    ]
  },
  "guards": {
    "trd_covered_modules": ["src/payment/**", "src/checkout/**"],
    "code_writes_outside_covered": "block"
  },
  "compaction_snapshot": null
}
```

## 4. 目录结构

```
<project root>/
├── .sdd/
│   └── state.json
├── docs/
│   ├── vX.Y.Z/                         # 当前进行中的版本
│   │   ├── prd.md                      # 产品需求文档（input）
│   │   ├── specs/
│   │   │   └── spec.md                 # 功能规范（output，Spec-Kit 风格）
│   │   ├── plans/
│   │   │   ├── trd.md                  # 版本级技术设计
│   │   │   ├── feature-login.md        # 单 feature 实现计划
│   │   │   └── feature-payment.md
│   │   └── decisions/
│   │       ├── 0001-use-postgresql.md  # ADR
│   │       └── bugfix-0002-fix-null.md # bugfix 记录（轻量 ADR）
│   └── archive/
│       └── v1.0.0/                     # 已归档版本（迁移过来，不双份并存）
│           ├── prd.md
│           ├── specs/spec.md
│           ├── plans/
│           └── decisions/
└── （源代码目录，不动）
```

### 4.1 文档层级与三层递进

`docs/vX.Y.Z/` 下的文档**不是同层并列**，而是**三层递进**：

```
prd.md                  ← 产品层：业务目标 / 用户 / 范围 / 指标（1 份）
  └─ 拆成 feature
spec.md                 ← 功能层：每个 feature 的 User Story（P1/P2/P3）与验收标准（Spec-Kit Given-When-Then）（1 份）
  └─ 决定技术选型与覆盖范围
trd.md                  ← 版本级技术层：vX.Y.Z 整体技术方案（1 份；含 Coverage Scope）
  └─ 按 feature 拆实现
feature-login.md        ← 单 feature 实现层：user story → task，含 TDD 步骤 + commit 粒度（N 份）
feature-payment.md
  └─ 派给 subagent
源码 + 提交
```

**层级关系**：`feature > user story > task`。
- 一个 PRD 通常拆成 N 个 feature（如「登录」「支付」）。
- 一个 feature 含 N 个 user story（spec.md 里 P1/P2/P3 切片）。
- 一个 user story 拆成 N 个 task（feature-*.md 里的 `[ID] [P?] [Story]`）。

| 维度               | `trd.md`                                                | `feature-<name>.md`                                    |
| ------------------ | ------------------------------------------------------- | ------------------------------------------------------ |
| 数量               | 1 份                                                    | 按需 N 份                                              |
| 粒度               | 粗：架构、模块、契约、`## Coverage Scope`               | 细：具体文件、具体任务、TDD 步骤、commit 粒度          |
| 回答的问题         | "vX.Y.Z 整体怎么做？"                                   | "feature-X 这个模块具体怎么落地？"                     |
| 类比外部框架       | Spec-Kit `/speckit.plan`                                | Superpowers `writing-plans`                            |
| 覆盖范围归属       | `## Coverage Scope` 在此定义，写入 `state.json.guards`  | 必须落在 `trd.md` 覆盖范围之内                         |
| 任务列表           | 只列 feature 名，不展开任务                             | 详细任务列表（`[ID] [P?] [Story] <描述>`）              |
| 谁执行             | `/sdd.trd`                                              | `/sdd.feature <name>`                                  |

**撰写约定**：
- `trd.md` 在「模块拆分」一节列出本版本包含的所有 feature，作为 `feature-*.md` 列表的来源。
- 每个 `feature-*.md` 顶部显式引用 `> 上游：docs/vX.Y.Z/plans/trd.md 第 N 节`，确保可追溯。
- 护栏（PreToolUse Hook）的依据是 `trd.md` 的 `## Coverage Scope`，但**任务粒度的执行细节**在 `feature-*.md` 里。
- 不允许跨 feature 互相改动对方的文件 —— 必须在 `trd.md` 里先扩大覆盖范围，再写新 feature 计划。

## 5. 命令与 Skill 对应

| 命令              | 内部 Skill                  | 写入路径                                              | 前置条件                |
| ----------------- | --------------------------- | ----------------------------------------------------- | ----------------------- |
| `/sdd.init`       | `sdd-init`                  | `.sdd/`、`docs/`                                      | —                       |
| `/sdd.new vX.Y.Z` | `sdd-new-version`           | `docs/vX.Y.Z/{prd.md,specs,plans,decisions}/`、`state.json` | 项目已初始化         |
| `/sdd.prd`        | `sdd-prd-writer`            | `docs/vX.Y.Z/prd.md`                                  | phase ≥ INITED          |
| `/sdd.spec`       | `sdd-spec-writer`           | `docs/vX.Y.Z/specs/spec.md`                           | prd 存在（approved）    |
| `/sdd.trd`        | `sdd-trd-writer`            | `docs/vX.Y.Z/plans/trd.md` + `state.json.guards`      | spec 已批准             |
| `/sdd.feature X`  | `sdd-feature-planner`       | `docs/vX.Y.Z/plans/feature-X.md`                      | trd 已批准              |
| `/sdd.code X`     | `sdd-code-orchestrator`     | 源文件（通过 subagent + TDD）                         | `feature-X.md` 存在     |
| `/sdd.bugfix`     | `sdd-bugfix-triage`         | `decisions/bugfix-*.md` + 代码                        | phase = CODE            |
| `/sdd.adr`        | `sdd-adr-writer`            | `docs/vX.Y.Z/decisions/NNNN-*.md`                     | —                       |
| `/sdd.status`     | `sdd-status-reader`         | （无）                                                | —                       |
| `/sdd.archive`    | `sdd-archiver`              | `docs/archive/vX.Y.Z/`                                | phase = RELEASE         |

每个 Skill 同时支持自然语言触发：Skill 的 `description` 字段按用户可能的说法撰写，所以用户即使说「帮我写一下支付功能的 spec」，也能命中 `sdd-spec-writer`，不必输入斜杠命令。

## 6. 各阶段外部框架组合

| 阶段        | Plugin Skill              | 外部框架层                                                              |
| ----------- | ------------------------- | ----------------------------------------------------------------------- |
| PRD（产品需求） | `sdd-prd-writer`          | Superpowers `brainstorming` 流程 + Plugin 原生 PRD 模板                |
| 需求        | `sdd-spec-writer`         | 读取 PRD 作为输入；调用 Superpowers `brainstorming` 流程；用 Spec-Kit `spec.md` 模板（User Story、Given-When-Then） |
| 技术设计（TRD） | `sdd-trd-writer`          | Spec-Kit `plan.md` 模板（Technical Context、Constitution Check、Coverage Scope） |
| Feature 计划 | `sdd-feature-planner`     | Superpowers `writing-plans` 流程（文件级任务、TDD 步骤、commit 粒度）   |
| 编码        | `sdd-code-orchestrator`   | Superpowers `subagent-driven-development` + `test-driven-development` + `verification-before-completion` |
| Bug 修复    | `sdd-bugfix-triage`       | Plugin 内部决策树（见 §7.6）                                            |
| ADR         | `sdd-adr-writer`          | Plugin 原生（MADR 风格模板）                                            |
| 状态        | `sdd-status-reader`       | Plugin 原生                                                              |
| 归档        | `sdd-archiver`            | Spec-Kit `/speckit.converge` 查漏 + OpenSpec 归档模型                    |

## 7. 关键 Skill — 内部行为

### 7.1 `sdd-prd-writer`

1. 读取 `state.json`。若 `phase < INITED`，直接拒绝。
2. 调用 **Superpowers `brainstorming`** 流程：一次问一个澄清问题，最多 5 个，围绕「要解决什么问题、为谁、成功的标准、范围边界」。
3. 用 Plugin 原生 PRD 模板填充：项目背景 / 目标用户 / 核心问题 / 业务目标 / 范围（in/out）/ 关键指标 / 时间盒。
4. 写入 `docs/vX.Y.Z/prd.md`。
5. 更新 `state.json.artifacts.prd.status = draft`。
6. **硬门**：用户未明确批准 PRD 前，不推进 `phase`。批准后 `status = approved` 且 `phase = PRD`。
7. PRD 既可由本命令生成，也可由人工提前放置（状态为 `approved`）。`/sdd.spec` 不区分 PRD 来源。

### 7.2 `sdd-spec-writer`

1. 读取 `state.json` 与 `docs/vX.Y.Z/prd.md`；若 PRD 未批准则拒绝，并提示「先 `/sdd.prd` 或人工放置 PRD」。
2. 调用 **Superpowers `brainstorming`** 流程：基于 PRD 抽取 User Story，一次问一个澄清问题，最多 5 个。
3. 用 Spec-Kit `spec-template.md` 骨架填充：User Story（P1/P2/P3）、Acceptance Scenarios（Given-When-Then）。
4. **保留引用**：在 `spec.md` 头部写明「输入 PRD：`docs/vX.Y.Z/prd.md`」，确保可追溯。
5. 写入 `docs/vX.Y.Z/specs/spec.md`。
6. 更新 `state.json.artifacts.spec.status = draft`。
7. **硬门**：用户未明确批准 spec 前，不推进 `phase`。批准后 `status = approved` 并 `phase = SPEC`。

### 7.3 `sdd-trd-writer`

1. 读取 spec.md；若 spec 未批准则拒绝。
2. 调用 **Superpowers `writing-plans`** 流程，逐个收集技术决策（一次一个问题）。
3. 用 Spec-Kit `plan-template.md` 骨架填充（Technical Context、Constitution Check、Project Structure、Coverage Scope）。
4. **强制章节**：`## Coverage Scope`，列出本版本允许改动的文件清单（使用 gitignore 风格 glob，粗细自定，例如 `src/payment/**`、`src/auth/login.controller.ts`）。
5. 解析得到的 glob 持久化到 `state.json.guards.trd_covered_modules`。
6. 用户批准后，当至少存在一个 feature plan 时，`phase = FEATURE_PLAN`。

### 7.4 `sdd-feature-planner`

1. 读取 trd.md；若 trd 未批准则拒绝。
2. 针对命名的 feature 调用 **Superpowers `writing-plans`** 全流程。
3. 产出 `docs/vX.Y.Z/plans/feature-<name>.md`，包含以下章节：
   - 文件结构（具体到要改的文件清单）
   - 任务列表 `[ID] [P?] [Story] <带文件路径的描述>`
   - 每个任务的 TDD 步骤（写测试 → 看红 → 写实现 → 看绿 → 提交）
   - Commit 粒度建议
4. **不另起 `tasks.md`** —— 任务内嵌在 plan 文档里，与 Superpowers 约定一致。
5. 用户批准后，把 `artifacts.features[name].status` 标记为 `planned`。

### 7.5 `sdd-code-orchestrator`

1. 确认 `feature-<name>.md` 存在且已批准。
2. 调用 **Superpowers `subagent-driven-development`**，把 plan 派发给 subagent。
3. Subagent 循环：
   - 对每个任务：写失败测试 → 实现 → 通过测试 → 提交。
   - 每次提交前调用 `verification-before-completion`。
4. **PreToolUse Hook** 检查每一次 `Write/Edit` 是否在 `state.json.guards.trd_covered_modules` 之内。越界即以退出码 2 拒绝。
5. 任务完成后，把 `artifacts.features[name].status` 从 `coding` 改为 `done`。

### 7.6 `sdd-bugfix-triage`

决策树（由 Skill 内部执行，不是用户驱动）：

```
Q1：本次修复是否改变 spec 定义的行为或验收标准？
    是 → 规范 bug → 提议写 ADR
    否 → 代码 bug → 写轻量 bugfix 记录

Q2（若是规范 bug）：本次修复是否改变 TRD 覆盖范围？
    是 → 先更新 trd.md
    否 → 仅更新 spec.md（diff 段）
```

处置路径：

- **代码 bug（轻量）**
  - 写 `docs/vX.Y.Z/decisions/bugfix-NNNN-<title>.md`（MADR 风格，但使用「现象 / 根因 / 修复 / 影响」布局）。
  - 通过 TDD 循环修复代码；把对应任务追加到相关 feature plan 的任务列表中。
- **规范 bug（完整）**
  - 写 ADR `000N-<title>.md`。
  - 用显式的 `[CHANGED]` diff 块更新 `spec.md`。
  - 若覆盖范围变化，更新 `trd.md` 并重新解析 `state.json.guards.trd_covered_modules`。
  - 对受影响的 feature 继续走 `/sdd.code` 流程。

### 7.7 `sdd-adr-writer`

Plugin 原生。模板如下：

```md
# ADR NNNN：<标题>

- 状态：proposed | accepted | deprecated
- 日期：YYYY-MM-DD
- 背景：<当前的约束与驱动力>
- 决策：<我们选择了什么>
- 后果：<正面、负面、后续行动>
```

### 7.8 `sdd-archiver`

1. 要求 `phase = RELEASE`（由用户手动设置或通过发布 hook 触发）。
2. 调用 Spec-Kit `/speckit.converge` 检测各 feature plan 中未完成的工作；若有未完成任务，在用户未明确「强制归档」前拒绝。
3. **迁移**（非快照）：用 `git mv` 把 `docs/vX.Y.Z/` 整个目录搬到 `docs/archive/vX.Y.Z/`。文档不双份并存。
4. 把 `state.json.phase` 标记为 `ARCHIVED`，清空 `guards`，版本字段保留 `vX.Y.Z` 作为只读历史。
5. 归档后 `docs/` 下不再有 `vX.Y.Z/` 同名目录；要查阅历史文档只能从 `docs/archive/vX.Y.Z/` 走。

### 7.9 `sdd-status-reader`

报告：当前 `version`、`phase`、缺失的产物、`proposed` 状态的 ADR、下一步推荐的斜杠命令。

## 8. Hooks

| Hook                    | 触发时机                  | 动作                                                                       |
| ----------------------- | ------------------------- | -------------------------------------------------------------------------- |
| `SessionStart`          | Agent 启动 / 恢复会话     | 读取 `state.json`，把摘要 `<plugin>active version=...phase=...missing=[...] next=/sdd.<x>` 注入 context（Claude Code 的 `hookSpecificOutput.additionalContext`）。 |
| `PreToolUse Write/Edit` | 即将写入源码              | 把目标文件路径与 `state.json.guards.trd_covered_modules` 比对。在范围内 → 放行；越界 → 退出码 2 + 提示 `"<path> 不在 vX.Y.Z 覆盖范围内。请更新 trd.md 或运行 /sdd.spec 扩展范围。"`。 |
| `PostToolUse Write/Edit`| 源码写入完成              | 更新 `state.json.last_modified`；若新增了顶层模块，提示「建议补一条 ADR」。 |
| `PreCompact`            | 会话压缩                  | 把当前阶段产物路径快照写入 `state.json.compaction_snapshot`。下次 `SessionStart` 会重新注入，使被压缩过的 context 能找回这些文件路径。 |

Hooks **不**对方法论本身做二次判断（不审 spec 文字、不做 TDD 强制 —— 这些都在 Skill 里）。Hooks 只守护路径合法性与状态机一致性。

## 9. 错误处理

| 失败场景                            | 用户可见的表现                                                | 恢复方式                                                   |
| ----------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------- |
| `state.json` 缺失 / 损坏            | 「项目未初始化。请运行 `/sdd.init`。」                        | 运行 `/sdd.init`                                           |
| PRD 缺失                            | `/sdd.spec` 拒绝并提示「请先运行 `/sdd.prd` 或手动导入 PRD。」 | 运行 `/sdd.prd` 或把已写好的 `prd.md` 放进 `docs/vX.Y.Z/`   |
| 阶段跳跃（例如无 PRD 直接 `/sdd.spec`） | 命令拒绝并说明原因                                            | 运行前置命令                                               |
| `trd.md` 缺少 `## Coverage Scope`   | `/sdd.trd` 拒绝完成                                            | 编辑 `trd.md` 补全该章节                                   |
| 写入超出覆盖范围                    | PreToolUse 退出码 2 并提示                                     | 更新 `trd.md` 或运行 `/sdd.spec` 扩展范围                  |
| 归档时仍有未完成任务                | `/sdd.archive` 拒绝并列出未完成项                              | 完成对应任务，或明确确认「仍然归档」                       |
| 脚本 IO / 网络失败                  | 抛出错误，**不破坏** `state.json`                             | 重跑；必要时从 `compaction_snapshot` 恢复                  |

## 10. 测试策略

| 层                              | 测试目标                                                       | 工具                                                       |
| ------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------- |
| 模板                            | 检查必要章节存在（如 `## Coverage Scope`）                     | `bash` / `node` 快照对比脚本                                |
| Hook 与归档脚本                 | 单元级行为                                                     | `bats` / `shunit2`                                         |
| Skill 行为（端到端）            | 准备 mock `state.json`，注入用户输入，断言输出                 | Claude Code headless 调用；将产物与 golden snapshot 对比   |
| Hook 行为（集成）               | 准备临时仓库，驱动 Write 工具，断言被拒绝                      | `bats` 驱动真实的 agent 子进程                             |
| 跨平台 adapter smoke            | 为每个 adapter 生成产物，跑对应宿主加载器                       | v0.1 阶段人工验收；后续补 CI 脚本                          |

**YAGNI**：不做平台 mock 抽象层；不额外设置超出上表的覆盖率指标。

## 11. 平台适配策略

真源内容放在 `sources/` 下，每个平台拿到一份薄薄的 adapter，把同一份内容重塑为该平台期望的目录布局。

```
sources/
├── skills/        （11 个 Skill，每个 Skill 一个目录）
├── templates/     （prd / spec / trd / feature-plan / adr / bugfix）
├── hooks/         （session-start、pre-write-guard、post-write-track）
└── scripts/       （init、archive、status）

adapters/
├── claude-code/
│   ├── .claude-plugin/plugin.json
│   ├── commands/                   # /sdd.* 的薄别名
│   └── hooks/hooks.json
├── opencode/
│   └── loadout.json                # OpenCode loadout 定义
└── codex/
    └── （CodeX 专属布局）
```

Plugin 根目录下的 `build.sh`：

1. 把 `sources/skills/` 复制到各 adapter 的目标位置。
2. 生成各平台的 manifest / 配置文件。
3. 在 Skill 实际运行时，把 `sources/templates/` 渲染到 `docs/vX.Y.Z/`。
4. 跑 smoke 测试。

### 11.1 适配器版本节奏

- **v0.1**：仅 Claude Code。
- **v0.2**：OpenCode adapter（验证 loadout 模型是否支持所需 Skills / Hooks；若不支持，缩减该平台暴露的功能面）。
- **v0.3+**：按需求追加 CodeX、Cursor、Copilot CLI。

## 12. 开放问题 / 后续工作

- **Hook 脚本语言**：Claude Code 同时支持 bash 与 node hook，OpenCode 可能不同。逐 adapter 决定而非一刀切。
- **Bugfix 自动分类**：当前由 Skill 内部走决策树。若用户觉得过于严格，后续可加启发式规则（文件数量、变更行数、是否触及 spec 表面）做预分类。
- **多版本并行**：当前设计假定同一时间只有一个活跃版本。若出现并行维护分支，`guards` 需要按 `version` 区分。
- **Plugin 分发**：v0.1 稳定后，对接公开 plugin 市场（Claude Code 的 `claude-plugins-official`、OpenCode 的 loadout registry）。

## 13. 验收标准

v0.1 视为完成，当且仅当：

1. Plugin 能从本仓库安装进 Claude Code。
2. 用户能在一个空白仓库里依次运行 `/sdd.init` → `/sdd.new v0.0.1` → `/sdd.prd`（或手动放置 `prd.md`） → `/sdd.spec` → `/sdd.trd` → `/sdd.feature demo` → `/sdd.code demo`，全程无需人工介入。
3. 写入超出声明覆盖范围的文件会被硬拦截，并给出明确错误消息。
4. `/sdd.status` 在每个阶段都准确反映当前状态（包括 PRD 状态）。
5. `/sdd.archive` 能把 `docs/v0.0.1/` 通过 `git mv` 迁移到 `docs/archive/v0.0.1/`（包括 `prd.md`），原位置不再保留，并清空 `state.json.guards`。
6. 所有对外部框架（Superpowers / Spec-Kit / OpenSpec）的调用都通过 Skill 编排，不在 Plugin 内部复制实现。