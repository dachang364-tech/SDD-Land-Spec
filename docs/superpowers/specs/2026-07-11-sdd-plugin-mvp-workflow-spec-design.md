# SDD Plugin MVP 工作流规格（开发执行版）

- 日期：2026-07-11
- 状态：draft
- 类型：MVP Spec
- 目标：作为 SDD Plugin MVP 后续代码生成与实施计划的上游规格

## 0. 设计目标

本文档定义 SDD Plugin MVP 的开发执行规格，重点描述工作流、文档边界、状态模型、Skill 行为、Hook 门控、模板结构和验收标准。

### 0.1 适用性声明

本文档是 SDD Plugin MVP 实现的唯一权威规格。

早期文档 `2026-07-07-sdd-codeagent-plugin-design.md` 与 `2026-07-10-sdd-plugin-v0.1-implementation-spec.md` 仅作为历史背景，不作为后续代码生成依据。

> 当早期文档与本文档冲突时，以本文档为准！！！

MVP 的目标不是实现完整 SDD 平台，而是跑通一个可开发、可验收、可迭代的最小闭环：

```text
PRD → Functional Specification → Implementation Plan → Code → Archive
```

以及横切的变更闭环：

```text
Decision Record → Implementation Plan → Code → DR Closed
```

## 1. 核心裁剪决策

### 1.1 不使用集中状态仓库

MVP 不创建、不读取、不维护：

```text
.sdd/state.json
```

状态只保存在需要状态管理的文档头部。

### 1.2 活跃版本规则

MVP 不引入 current-version 文件。活跃版本由目录推导：

```text
活跃版本 = docs/ 下唯一一个未归档的 vX.Y.Z 目录
```

解析规则：

1. 扫描 `docs/v*/`。
2. 排除 `docs/archive/**`。
3. 找到 0 个版本目录：拒绝主流程 Skill，提示先运行 `/sdd:new vX.Y.Z`。
4. 找到 1 个版本目录：作为活跃版本。
5. 找到多个版本目录：拒绝主流程 Skill，提示先归档旧版本；MVP 不支持多活跃版本。

### 1.3 Hook 范围

MVP Hook 的定位是最低限度机械门控，不是流程编排器、状态机或文档质量评审器。

Hook 只在 `PreToolUse: Write/Edit` 时检查目标路径与前置文档状态，防止 CodeAgent 明显越过 PRD / spec / DR / plan 阶段写入 SDD 文档。

Hook 负责：

- 阻止缺少 PRD 时写 `docs/vX.Y.Z/specs/spec.md`。
- 阻止 spec 未 `approved` 时写 `docs/vX.Y.Z/plans/NNN-feature-*.md`。
- 阻止代码类 DR 未 `accepted` 时写 `docs/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md`。
- 对不满足条件的写入返回 `exit 2` 和中文错误说明。

MVP 只实现 PreToolUse L1 文档门控。

不实现：

- `src/**` 源码路径门控
- L2 / L3 CONSTITUTION must / should 机器解析
- PostToolUse 进度记账
- PreCompact 状态持久化
- git log CONFORMANCE 回溯
- 字段级 status 防篡改
- 自动修改 `CLAUDE.md` / `AGENTS.md`

### 1.4 CONSTITUTION 约束定位

`docs/CONSTITUTION.md` 是项目内 SDD Plugin 工作流的规范性约束源。

MVP 中：

- `/sdd:init` 从 `CONSTITUTION.default.md` 生成默认宪法。
- 默认宪法使用 `must` / `should` / `may` 描述 CodeAgent 工作流约束。
- 用户可以修改 `docs/CONSTITUTION.md`；修改后，该文件就是当前项目新的流程宪法。
- SDD Skills 不重复内置完整宪法条款，但必须在执行前读取 `docs/CONSTITUTION.md`，并把它作为本次 Skill 的流程约束上下文。
- 如果用户请求与 `docs/CONSTITUTION.md` 冲突，Skill 必须先指出冲突；除非用户先修改宪法文件，否则不直接执行冲突操作。
- MVP 不机器解析 `must` / `should`，不把宪法条款接入 Hook L2 / L3。

`CLAUDE.md` / `AGENTS.md` 处理策略：

- `docs/CONSTITUTION.md` 的权威性不依赖 `CLAUDE.md` / `AGENTS.md`。
- `/sdd:init` 不自动修改用户已有的 `CLAUDE.md` / `AGENTS.md`。
- 如果项目存在 `CLAUDE.md` / `AGENTS.md`，它们只能作为读取 `docs/CONSTITUTION.md` 的增强入口，不能替代宪法文件本身。
- 即使用户未配置 `CLAUDE.md` / `AGENTS.md`，SDD Skills 仍必须通过读取 `docs/CONSTITUTION.md` 保证 Plugin 独立可用。

## 2. 文档分层与边界

### 2.1 `prd.md` — PRD / 产品需求文档

路径：

```text
docs/vX.Y.Z/prd.md
```

职责：

```text
描述为什么做、为谁做、业务目标、产品范围。
```

主导角色：产品经理 / 需求方。

包含：

- 用户 / 使用场景
- 问题与痛点
- 业务目标
- 功能范围 in / out
- 成功标准
- 上游 `docs/requirements/*.md` 引用

不包含：

- 技术方案
- 文件路径
- 任务拆分
- TDD 步骤
- 具体代码实现

状态：

```text
无 SDD 状态字段
```

`/sdd:spec` 的前置条件只要求 `prd.md` 存在。

### 2.2 `specs/spec.md` — Functional Specification / 功能行为规格

路径：

```text
docs/vX.Y.Z/specs/spec.md
```

职责：

```text
把 PRD 转化为明确的功能行为契约。
```

主导角色：程序员 / 技术产品化。

包含：

- 功能边界
- 用户故事
- 业务规则
- 输入 / 输出
- 状态变化
- 边界条件
- Given-When-Then 验收场景
- 非目标

不包含：

- 技术架构
- 具体文件改动
- commit 粒度
- 任务执行步骤

状态：

```text
- 状态：draft | approved
```

`/sdd:plan` 的 feature 模式前置条件：

```text
spec.md 状态必须是 approved
```

### 2.3 `plans/*.md` — Implementation Plan / 技术实现计划

路径：

```text
docs/vX.Y.Z/plans/NNN-feature-*.md
docs/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md
```

`NNN` 是版本内递增序号，例如 `001`、`002`、`003`。MVP 中 plan 是增量实施记录，不是某个 feature 的唯一长期文档。

职责：

```text
把已批准的 Functional Specification 或 accepted DR 转化为可执行代码计划。
```

主导角色：程序员 / 实现者。

包含两部分：

1. Technical Design
   - 技术方案
   - 架构边界
   - 模块影响
   - 数据流 / 控制流
   - 测试策略
   - 风险与约束
2. Superpowers-compatible Implementation Tasks
   - 文件清单
   - 接口契约
   - Task 拆分
   - TDD 步骤
   - verification 命令
   - commit 粒度
   - checkbox 执行项

状态：

```text
- 状态：draft | planned | coding | done
```

`/sdd:code` 前置条件：

```text
plan 状态是 planned 或 coding
```

如果 plan 由代码类 DR 驱动，还要求：

```text
关联 DR 状态是 accepted
```

### 2.4 `decisions/*.md` — DR / Decision Record

路径：

```text
docs/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md
```

职责：

```text
记录对已批准 spec 或已生成 plan 的变更决策。
```

状态：

```text
- 状态：drafting | accepted | closed
```

关闭原因：

```text
- closed_reason: null | committed | superseded | dismissed
```

语义：

- `drafting`：决策草稿，可修改，可 dismiss。
- `accepted`：用户接受决策，允许落地。
- `closed`：决策落地完成、被驳回或被取代。

### 2.5 `docs/requirements/` — 项目级需求资料库

路径：

```text
docs/requirements/*.md
```

职责：

```text
保存跨版本复用的原始需求、调研、访谈、竞品分析、技术预研资料。
```

它与 PRD 的关系：

```text
requirements = 原始/半结构化输入资料
prd.md       = 某个版本选择并提炼后的产品需求文档
```

MVP 中：

- 无状态字段
- 不参与 Hook 门控
- 不随版本 archive
- 可被 `/sdd:prd` 扫描并引用

## 3. 状态模型

### 3.1 唯一合法状态行格式

所有由 SDD Plugin 管理状态的文档，状态行唯一格式：

```md
- 状态：<value>
```

MVP 不支持：

```md
> 状态：<value>
status: <value>
```

### 3.2 状态表

| 文档 | 状态 |
| --- | --- |
| `specs/spec.md` | `draft` / `approved` |
| `plans/NNN-feature-*.md` | `draft` / `planned` / `coding` / `done` |
| `plans/NNN-{fix,feat,chg,arch}-*.md` | `draft` / `planned` / `coding` / `done` |
| `decisions/*.md` | `drafting` / `accepted` / `closed` |

无状态文档：

```text
prd.md
docs/requirements/*.md
```

### 3.3 解析失败规则

如果需要读取状态但目标文档缺少状态行：

```text
视为 invalid，拒绝继续，提示文档缺少 - 状态：<value>
```

如果状态值不在枚举内：

```text
视为 invalid，拒绝继续，提示状态非法
```

## 4. MVP 总体工作流

### 4.1 主流程

```text
/sdd:init
  → 初始化 Plugin 所需项目结构

/sdd:new vX.Y.Z
  → 创建唯一活跃版本目录

/sdd:research <topic>   可选
  → 生成项目级调研资料，不参与状态门控

/sdd:prd
  → 生成 PRD，描述产品需求，无状态

/sdd:spec
  → 基于 PRD 与用户对话，生成 Functional Specification
  → spec: draft → approved

/sdd:plan <work-item>
  → 基于 spec 或 accepted DR，与用户对话生成 Technical Design
  → 再生成 Superpowers-compatible Implementation Plan
  → plan: draft → planned

/sdd:code <NNN|work-item>
  → 按 plan 执行代码实现
  → plan: planned → coding → done

/sdd:archive
  → 当前版本所有核心工作完成后迁移到 docs/archive/
```

### 4.2 DR 变更流程

DR 按 tag 分为两类落地路径。

#### 4.2.1 代码类 DR 落地路径

适用于会影响代码实现的变更：

```text
fix | feat | chg | arch
```

流程：

```text
/sdd:dr <fix|feat|chg|arch> <title>
  → 生成 DR
  → DR: drafting

/sdd:dr accept <id>
  → 用户接受决策
  → DR: drafting → accepted

如需变更 Functional Specification：
/sdd:spec
  → 关联该 accepted 代码类 DR 更新 spec
  → spec: draft → approved
  → DR 保持 accepted

/sdd:plan <id>
  → 基于 accepted DR 生成 fix/feat/chg/arch plan
  → plan: draft → planned

/sdd:code <NNN|id>
  → 执行 plan
  → plan: coding → done
  → DR: accepted → closed
  → closed_reason: committed
```

#### 4.2.2 文档类 DR 落地路径

适用于不影响代码，只修正文档表达、澄清规格、调整描述的变更：

```text
spec | doc | typo
```

流程：

```text
/sdd:dr <spec|doc|typo> <title>
  → 生成 DR
  → DR: drafting

/sdd:dr accept <id>
  → 用户接受决策
  → DR: drafting → accepted

/sdd:spec 或 /sdd:plan <work-item> 文档修订模式
  → 关联该 accepted 文档类 DR 完成文档修订
  → 用户确认修订
  → DR: accepted → closed
  → closed_reason: committed
```

文档类 DR 不生成 Implementation Plan，不执行 `/sdd:code`。

如果 plan 修订会改变技术方案、模块边界、文件改动、任务拆分、测试策略或实现范围，则不能使用文档类 DR；应创建代码类 `fix` / `chg` / `arch` DR，并重新进入代码类 DR 落地路径。

#### 4.2.3 功能需求 CRUD 与 DR tag 映射

MVP 不引入 `create` / `update` / `delete` / `read` 命令或 tag。功能需求 CRUD 统一映射到现有 DR tag：

| 功能需求变化 | DR tag | 是否改 spec | 是否生成 plan | 说明 |
| --- | --- | --- | --- | --- |
| 新增功能 | `feat` | 是 | 是 | 新增用户可见能力、API、流程、页面、命令 |
| 修改已有功能行为 | `chg` | 是 | 是 | 改规则、改交互、改输出、改验收标准 |
| 删除 / 下线功能 | `chg` | 是 | 是 | 删除也是行为变更，MVP 用 `chg` 承载 |
| 拆分 / 合并功能 | `chg` 或 `arch` | 是 | 是 | 行为边界变用 `chg`；主要是模块边界变用 `arch` |
| 修复实现偏离 spec | `fix` | 通常否 | 是 | spec 不变，代码回到既有契约 |
| 澄清 spec 表述，行为不变 | `spec` | 是 | 否 | 只改表达，不改系统行为 |
| 调整文档结构 / plan 描述，行为不变 | `doc` | 否或轻微 | 否 | 不改变实现语义 |
| typo / 标点 / 错字 | `typo` | 否 | 否 | 纯文字修正 |
| 调整架构 / 模块边界 | `arch` | 可能是 | 是 | 技术结构变化，可能不改变用户行为 |

新增功能必须使用 `feat` DR，不使用 `spec` DR。修改已有功能行为、删除功能、下线功能默认使用 `chg` DR。`Read` 类能力如果是新增查询能力，使用 `feat`；如果是修改查询规则，使用 `chg`。

#### 4.2.4 coding 中出现功能 CRUD 变更

如果当前存在 `coding` 状态的 plan，MVP 默认不打断当前 coding，不把新功能或行为变更直接塞进正在 coding 的原 plan。

默认流程：

```text
当前 plan: coding
  → 继续按原 plan 完成
  → verification 通过
  → 当前 plan: done

然后处理功能 CRUD 变更：
  → /sdd:dr feat|chg <title>
  → /sdd:dr accept <id>
  → /sdd:spec 关联 DR 更新 Functional Specification
  → /sdd:plan <id>
  → /sdd:code <NNN|id>
  → DR closed
```

MVP 不处理“暂停当前 coding、先插入新功能”的自动调度。若用户确实需要改变正在 coding 的实现语义，应先完成或人工中止当前工作，再通过独立 DR 和独立 plan 表达新变更。

## 5. Skill 工作流

### 5.0 通用 Skill 前置约束

除 `/sdd:init` 外，所有 SDD Skill 执行前都必须：

1. 检查 `docs/CONSTITUTION.md` 是否存在。
2. 读取 `docs/CONSTITUTION.md`。
3. 将其作为本次 Skill 的项目流程约束上下文。
4. 如果用户请求与宪法冲突，先指出冲突并拒绝直接执行；除非用户先修改 `docs/CONSTITUTION.md`。

MVP 不要求 Skill 对 `must` / `should` 做结构化解析；但 Skill 的自然语言执行必须遵守已读取的宪法内容。

### 5.1 `/sdd:init`

职责：

```text
初始化当前项目的 SDD 目录和 Plugin 运行前置条件。
```

前置条件：

```text
docs/CONSTITUTION.md 不存在
```

动作：

1. 检查 Plugin 依赖：Superpowers、Spec-Kit。
2. 依赖缺失时提示运行 `scripts/install-deps.sh`，不隐式降级。
3. 创建 `docs/requirements/`。
4. 创建 `docs/archive/`。
5. 从 `CONSTITUTION.default.md` 复制生成 `docs/CONSTITUTION.md`。
6. 不自动修改用户已有的 `CLAUDE.md` / `AGENTS.md`；这些文件不是 SDD Plugin MVP 的运行前置条件。
7. 不创建 `state.json`。
8. 不创建版本目录。

输出：

```text
docs/CONSTITUTION.md
docs/requirements/
docs/archive/
```

失败处理：

```text
如果 docs/CONSTITUTION.md 已存在，拒绝重复初始化，并提示运行 /sdd:status。
```

### 5.2 `/sdd:new vX.Y.Z`

职责：

```text
创建新的唯一活跃版本目录。
```

前置条件：

```text
docs/CONSTITUTION.md 存在
docs/ 下不存在其他未归档 vX.Y.Z 目录
```

动作：

1. 校验版本号格式。
2. 创建 `docs/vX.Y.Z/specs/`。
3. 创建 `docs/vX.Y.Z/plans/`。
4. 创建 `docs/vX.Y.Z/decisions/`。
5. 不创建 `prd.md`。
6. 不创建 `spec.md`。
7. 不创建任何 plan。

失败处理：

```text
如果已有未归档版本目录，拒绝创建并提示先 /sdd:archive。
```

### 5.3 `/sdd:research <topic>`

职责：

```text
生成项目级调研资料，供 PRD 引用。
```

前置条件：

```text
docs/requirements/ 存在
```

动作：

1. 与用户澄清调研主题。
2. 生成 research 文档。
3. 写入 `docs/requirements/<topic-slug>-<yyyy-mm>.md`。
4. 不参与版本状态。
5. 不参与 Hook 门控。
6. 不随版本 archive。

状态：

```text
无状态字段
```

### 5.4 `/sdd:prd`

职责：

```text
生成产品需求文档。
```

前置条件：

```text
存在唯一活跃版本目录
```

动作：

1. 扫描 `docs/requirements/*.md`。
2. 让用户选择是否引用上游 requirements。
3. 与用户澄清产品需求。
4. 生成 `docs/vX.Y.Z/prd.md`。
5. 不写状态字段。

内容必须包含：

- 产品背景
- 目标用户
- 问题与痛点
- 业务目标
- 范围 in / out
- 成功标准
- 上游 requirements 引用

失败处理：

```text
没有活跃版本时，提示先运行 /sdd:new vX.Y.Z。
```

### 5.5 `/sdd:spec`

职责：

```text
生成 Functional Specification / 功能行为规格。
```

前置条件：

```text
docs/vX.Y.Z/prd.md 存在
```

动作：

1. 读取 `prd.md`。
2. 检查是否存在 `accepted` 的文档类 DR（`spec` / `doc` / `typo`）。如存在，列出并让用户选择是否作为本次 spec 修订的关联 DR。
3. 与用户澄清功能行为。
4. 借鉴 Spec-Kit spec 结构生成 `spec.md`。
5. 写入 `docs/vX.Y.Z/specs/spec.md`，状态 `draft`。
6. 用户确认后，将状态切换为 `approved`。
7. 如果本次修订关联文档类 DR，则将该 DR `accepted → closed`，写入 `closed_reason: committed` 与 `closed_at`。

必须澄清：

- 功能边界
- 用户故事
- 业务规则
- 输入输出
- 异常 / 边界场景
- 验收标准
- 非目标

失败处理：

```text
prd.md 不存在时拒绝。
用户未批准时保持 draft。
```

### 5.6 `/sdd:plan <work-item>`

职责：

```text
生成 Implementation Plan / 技术实现计划。
```

`<work-item>` 是实现单元标识，可以是：

1. feature name，例如 `login`、`payment`、`user-profile`
2. normalized feature name，例如 `feature-login`
3. 代码类 DR ID，例如 `fix-0001-login-null-error`、`chg-0002-payment-policy`、`arch-0003-module-split`

plan 文件名由 Skill 自动分配版本内递增序号：

```text
NNN = 当前 docs/vX.Y.Z/plans/ 下已有最大 NNN + 1
```

示例：

```text
login                         → 001-feature-login.md
chg-0003-login-retry-policy   → 002-chg-0003-login-retry-policy.md
feat-0004-sso-login           → 003-feat-0004-sso-login.md
```

#### 5.6.0 模式判定规则

`/sdd:plan <work-item>` 必须按语法优先级判定模式，不通过扫描 DR 标题、plan 标题或自然语言语义猜测模式。

判定顺序：

1. 如果 `<work-item>` 精确匹配代码类 DR ID：

```text
^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$
```

进入代码类 DR 模式。

2. 如果 `<work-item>` 精确匹配文档类 DR ID：

```text
^(spec|doc|typo)-[0-9]{4}-[a-z0-9-]+$
```

拒绝执行。文档类 DR 不生成 Implementation Plan，不执行 `/sdd:code`。

3. 其他输入一律进入 feature 模式。

示例：

| 输入 | 判定 |
| --- | --- |
| `login` | feature 模式 |
| `feature-login` | feature 模式 |
| `fix-login` | feature 模式 |
| `fix-0001-login-null-error` | 代码类 DR 模式 |
| `chg-0002-payment-policy` | 代码类 DR 模式 |
| `spec-0003-wording` | 拒绝：文档类 DR 不生成 plan |

如果用户本意是代码类 DR plan，必须传入完整合法 DR ID。

#### 5.6.1 feature 模式

输入示例：

```text
/sdd:plan login
/sdd:plan feature-login
```

名称规范化：

```text
login         → feature-login
feature-login → feature-login
```

输出：

```text
docs/vX.Y.Z/plans/NNN-feature-login.md
```

前置条件：

```text
docs/vX.Y.Z/specs/spec.md 状态为 approved
```

动作：

1. 读取 `spec.md`。
2. 进入 Technical Planning Dialogue。
3. Technical Planning Dialogue 必须先完成技术方案讨论：
   - 读取 spec / DR / 当前代码结构。
   - 识别可能影响的模块与文件区域。
   - 提出 2-3 个技术实现方案。
   - 给出推荐方案和取舍理由。
   - 与用户确认架构边界、数据流 / 控制流、文件影响范围、测试策略、风险与约束。
   - 用户确认技术方案后，才进入 Implementation Plan 生成。
4. 生成 SDD header。
5. 生成 Technical Design 章节，作为本 plan 的设计基线。
6. 生成 Implementation Tasks 章节，作为 Technical Design 的执行展开。
7. 写入 `docs/vX.Y.Z/plans/NNN-feature-<name>.md`，状态 `draft`。
8. 用户确认后，将状态切换为 `planned`。

#### 5.6.2 代码类 DR 模式

输入示例：

```text
/sdd:plan fix-0001-login-null-error
/sdd:plan chg-0002-payment-policy
/sdd:plan arch-0003-module-split
```

输出：

```text
docs/vX.Y.Z/plans/NNN-<dr-id>.md
```

前置条件：

```text
docs/vX.Y.Z/decisions/<dr-id>.md 状态为 accepted
```

动作：

1. 读取对应 DR。
2. 读取 `spec.md`。
3. 进入 Technical Planning Dialogue。
4. Technical Planning Dialogue 必须先完成技术方案讨论：
   - 读取 spec / DR / 当前代码结构。
   - 识别可能影响的模块与文件区域。
   - 提出 2-3 个技术实现方案。
   - 给出推荐方案和取舍理由。
   - 与用户确认架构边界、数据流 / 控制流、文件影响范围、测试策略、风险与约束。
   - 用户确认技术方案后，才进入 Implementation Plan 生成。
5. 生成 Technical Design 章节，作为本 plan 的设计基线。
6. 生成 Implementation Tasks 章节，作为 Technical Design 的执行展开。
7. 写入 `docs/vX.Y.Z/plans/NNN-<dr-id>.md`，状态 `draft`。
8. 用户确认后，将状态切换为 `planned`。

plan 头部：

```md
- 状态：draft
- 类型：feature | fix | feat | chg | arch
- 上游 spec：docs/vX.Y.Z/specs/spec.md
- 关联 DR：null | <dr-id>
```

失败处理：

```text
spec 未 approved → 拒绝 feature plan。
DR 未 accepted → 拒绝代码类 DR plan。
文档类 DR ID → 拒绝 plan，提示文档类 DR 不生成 Implementation Plan。
用户未批准 → 保持 draft。
```

### 5.7 `/sdd:code <NNN|work-item>`

职责：

```text
按 plan 执行代码实现。
```

`<work-item>` 用于定位已生成的 plan，可以是：

1. plan 序号，例如 `001`、`002`
2. 完整 plan basename，例如 `001-feature-login`、`002-chg-0003-login-retry-policy`
3. feature name / normalized feature name，例如 `login`、`feature-login`
4. 代码类 DR ID，例如 `fix-0001-login-null-error`

解析规则：

1. 如果输入是 `NNN`，精确匹配 `docs/vX.Y.Z/plans/NNN-*.md`。
2. 如果输入是完整 plan basename，精确匹配同名 `.md`。
3. 如果输入是 feature name / DR ID，按后缀匹配 `NNN-<normalized>.md` 或 `NNN-<dr-id>.md`。
4. 如果匹配 0 个 plan，拒绝并提示先运行 `/sdd:plan <work-item>`。
5. 如果匹配多个 plan，拒绝并提示使用 plan 序号，例如 `/sdd:code 002`。

前置条件：

```text
对应 plan 文件存在
plan 状态为 planned 或 coding
```

代码类 DR 模式额外要求：

```text
关联 DR 状态为 accepted
```

动作：

1. 解析并读取 plan 文件。
2. 校验 plan 状态为 `planned` 或 `coding`。
3. 如果是代码类 DR plan，校验关联 DR 状态为 `accepted`。
4. 让用户选择执行模式：
   - 高质量模式：`superpowers:subagent-driven-development`
   - 快速模式：`superpowers:executing-plans`
5. 将 plan 状态从 `planned` 切换为 `coding`。如果已经是 `coding`，保持不变。
6. 按用户选择的模式执行 plan。
7. 执行 `superpowers:verification-before-completion`。
8. 执行成功且 verification 通过后，将 plan 状态切换为 `done`。
9. 如果 plan 关联代码类 DR，则将 DR `accepted → closed`。
10. 写入 DR `closed_reason: committed`。
11. 写入 DR `closed_at`。
12. 如有 `supersedes`，回填旧 DR `superseded_by`。

失败处理：

```text
执行失败或 verification 失败时，plan 保持 coding。
下次 /sdd:code <NNN|work-item> 可继续执行。
关联 DR 保持 accepted。
```

完成判定：

```text
Superpowers 执行完成 + verification 通过。
不解析 checkbox 作为 SDD 状态真相。
```

### 5.8 `/sdd:dr <tag> <title>`

职责：

```text
创建 Decision Record。
```

tag：

```text
fix | feat | chg | arch | spec | doc | typo
```

动作：

1. 解析 tag 和 title。
2. 生成全局递增 DR ID。
3. 写入 `docs/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md`。
4. 状态为 `drafting`。

DR 头部：

```md
- 状态：drafting
- tag：fix
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null
```

### 5.9 `/sdd:dr accept <id>`

职责：

```text
接受 DR，允许落地。
```

前置条件：

```text
DR 状态为 drafting
```

动作：

1. 校验 DR 存在。
2. 将状态 `drafting → accepted`。
3. 不写 `closed_reason`。
4. 不写 `closed_at`。
5. 不回填 supersede 链。
6. 输出下一步建议。

下一步建议：

```text
代码类 DR：/sdd:plan <id>
文档类 DR：运行 /sdd:spec 或对应文档 Skill 完成变更；变更批准后由该 Skill 关闭 DR
```

### 5.10 `/sdd:dr dismiss <id> <reason>`

职责：

```text
驳回 drafting DR。
```

前置条件：

```text
DR 状态为 drafting
```

动作：

1. 将状态 `drafting → closed`。
2. 写入 `closed_reason: dismissed`。
3. 写入 `dismissed_reason`。
4. 写入 `closed_at`。

失败处理：

```text
accepted 或 closed DR 不允许 dismiss。
错误时另起 DR supersede。
```

### 5.11 `/sdd:status`

职责：

```text
展示当前版本状态与下一步建议。
```

动作：

1. 解析唯一活跃版本。
2. 检查 `prd.md` 是否存在。
3. 检查 `spec.md` 状态。
4. 扫描 `plans/*.md` 状态。
5. 扫描 `drafting / accepted` DR。
6. 输出下一步建议。

不做：

- 不做一致性诊断
- 不查 git log
- 不做 CONFORMANCE

### 5.12 `/sdd:doctor`

职责：

```text
做 Plugin 安装完整性和最小项目一致性诊断。
```

检查：

- Plugin manifest
- 11 个 Skill
- `hooks.json`
- 模板文件
- `scripts/install-deps.sh`
- 依赖可达性
- status 字段是否可解析
- DR 状态是否合法
- closed DR 是否有 `closed_reason`
- accepted 代码类 DR 是否有去掉 `NNN-` 前缀后与 DR ID 对应的 plan
- done 的代码类 DR plan 对应 DR 是否仍 accepted

不做：

- 不查 git log
- 不做 CONFORMANCE
- 不分析源码变更

### 5.13 `/sdd:archive`

职责：

```text
归档当前活跃版本。
```

前置条件：

1. 存在唯一活跃版本。
2. `prd.md` 存在。
3. `spec.md` 状态为 `approved`。
4. 所有 `plans/*.md` 状态为 `done`。
5. 不存在 `drafting` DR。
6. 不存在 `accepted` DR。

动作：

1. 将 `docs/vX.Y.Z/` 移动到 `docs/archive/vX.Y.Z/`。
2. git 仓库中优先使用 `git mv`。
3. 不移动 `docs/requirements/`。
4. 不移动 `docs/CONSTITUTION.md`。
5. 不修改归档文档内部状态。

失败处理：

```text
存在未完成 plan 或未关闭 DR 时拒绝。
```

## 6. Hook 规则

### 6.1 触发范围

Hook 只注册到：

```text
PreToolUse: Write/Edit
```

不注册或不实现：

- PostToolUse
- PreCompact
- 源码路径门控
- CONSTITUTION must / should 机器解析

### 6.2 路径门控表

| 写入目标 | 前置条件 |
| --- | --- |
| `docs/vX.Y.Z/prd.md` | 无 |
| `docs/vX.Y.Z/specs/spec.md` | `docs/vX.Y.Z/prd.md` 存在 |
| `docs/vX.Y.Z/plans/NNN-feature-*.md` | `docs/vX.Y.Z/specs/spec.md` 的 `- 状态：approved` |
| `docs/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md` | 去掉 `NNN-` 前缀后的同名 DR 状态为 `accepted` |
| `docs/vX.Y.Z/decisions/*.md` | 无 |
| `docs/requirements/*.md` | 无 |
| `docs/archive/**` | 默认不写；archive 命令内部移动 |
| `src/**` | v0.1 不拦截 |
| 其他路径 | v0.1 不拦截 |

### 6.3 成功行为

条件满足：

```text
exit 0
允许本次 Write/Edit 继续
```

### 6.4 失败行为

条件不满足：

```text
exit 2
stderr 输出中文错误说明
阻止本次 Write/Edit
```

示例：

```text
无法写入 docs/v0.1.0/plans/001-feature-login.md：
前置文档 docs/v0.1.0/specs/spec.md 状态为 draft，期望 approved。
请先完成 /sdd:spec 并批准 Functional Specification。
```

### 6.5 Hook 不负责的事情

Hook 不限制用户修改 `docs/CONSTITUTION.md`。宪法文件是用户调整项目流程约束的入口；MVP 不用 Hook 锁死该文件。

Hook 不做：

- 不生成文档
- 不修改 status
- 不判断文档质量
- 不检查用户是否真的批准
- 不阻止用户手工改 status
- 不阻止修改 `planned` / `coding` / `done` plan
- 不拦截 `src/**`

## 7. 模板结构

### 7.0 `CONSTITUTION.default.md`

```md
# CONSTITUTION

> SDD Plugin 项目级流程强制约束。用户可以修改本文件；修改后，本文件即为当前项目新的流程宪法。

## 1. 阶段门控
- must: SDD 主流程必须按 `/sdd:init → /sdd:new → /sdd:prd → /sdd:spec → /sdd:plan → /sdd:code → /sdd:archive` 推进。
- must: `/sdd:spec` 必须在 `prd.md` 存在后执行。
- must: feature plan 必须在 `spec.md` 状态为 `approved` 后生成。
- must: `/sdd:code` 只能执行状态为 `planned` 或 `coding` 的 plan。

## 2. 文档状态
- must: SDD 管理的状态行只能使用 `- 状态：<value>` 格式。
- must: spec 状态只能是 `draft` 或 `approved`。
- must: plan 状态只能是 `draft`、`planned`、`coding` 或 `done`。
- must: DR 状态只能是 `drafting`、`accepted` 或 `closed`。
- should: 状态推进应由对应 SDD Skill 完成，不应手工直接改状态。

## 3. DR 流程
- must: 会影响代码实现的变更必须使用代码类 DR：`fix`、`feat`、`chg` 或 `arch`。
- must: 只影响文档表达且不改变系统行为的变更可以使用文档类 DR：`spec`、`doc` 或 `typo`。
- must: 代码类 DR 必须先 `accepted`，才能生成对应 Implementation Plan。
- must: 代码类 DR 只有在关联 plan 完成并通过 verification 后才能关闭为 `committed`。
- may: typo 类修订可以按项目约定跳过 DR。

## 4. Plan 约束
- must: plan 是增量实施记录，文件名必须带版本内递增序号 `NNN-`。
- must: Implementation Tasks 是 Technical Design 的执行展开，不是独立设计层。
- must: 如果实现过程中需要改变技术方案、架构边界、模块影响、数据流 / 控制流、测试策略或实现范围，应通过代码类 DR 创建新的增量 plan。
- must: 当前存在 `coding` plan 时，不把新功能或行为变更直接塞进正在 coding 的原 plan。

## 5. Skill 身份
- must: SDD Skill 执行前必须读取本文件，并将其作为本次 Skill 的项目流程约束上下文。
- must: 若用户请求与本文件冲突，Skill 必须先指出冲突；除非用户先修改本文件，否则不直接执行冲突操作。
- must: 各 Skill 只做自己职责范围内的事情。

## 6. Subagent / Code Worker 约束
- must: subagent 或 code worker 不应自行推进 SDD 文档状态，除非当前 `/sdd:code` Skill 明确要求。
- must: code worker 必须按 plan 执行，并在完成前运行 verification。

## 7. Hook 行为
- must: MVP Hook 只守护 L1 路径 → 前置文档状态门控。
- must: Hook 失败时使用退出码 2，并输出中文错误说明。
- must: Hook 不做文档质量判断、不解析本文件 must / should、不拦截 `src/**`。

## 8. 错误处理
- must: Skill 失败时不得破坏上一稳定文档状态。
- should: 执行失败或 verification 失败时，plan 保持 `coding`，关联 DR 保持 `accepted`。

## 9. 用户修改
- may: 用户可以修改本文件以改变项目流程约束。
- should: 修改本文件后，后续 SDD Skill 应以修改后的内容为准。
```

### 7.1 `prd.md`

```md
# PRD：<产品/版本名>

- 版本：vX.Y.Z
- 日期：YYYY-MM-DD

## 上游需求资料
| 路径 | 摘要 |
| ---- | ---- |

## 1. 背景
## 2. 目标用户
## 3. 问题与痛点
## 4. 产品目标
## 5. 范围
### 5.1 In Scope
### 5.2 Out of Scope
## 6. 成功标准
## 7. 风险与假设
```

### 7.2 `spec.md`

```md
# Functional Specification：<名称>

- 版本：vX.Y.Z
- 状态：draft
- 上游 PRD：docs/vX.Y.Z/prd.md

## 1. 功能概述
## 2. 用户故事
## 3. 功能行为
## 4. 业务规则
## 5. 输入输出
## 6. 边界与异常场景
## 7. 验收场景
### Scenario 1: ...
Given ...
When ...
Then ...
## 8. 非目标
## 9. 关联 DRs
| DR ID | tag | title | status | date |
```

### 7.3 `plans/*.md`

```md
# NNN-<work-item> Implementation Plan

- 序号：NNN
- 状态：draft
- 类型：feature | fix | feat | chg | arch
- 上游 spec：docs/vX.Y.Z/specs/spec.md
- 关联 DR：null | <dr-id>

## Technical Design

### 1. 技术方案
### 2. 架构边界
### 3. 模块影响
### 4. 数据流 / 控制流
### 5. 测试策略
### 6. 风险与约束

## Implementation Tasks

本章节是 Technical Design 的执行展开，不是独立设计层。

如果实现过程中需要改变技术方案、架构边界、模块影响、数据流 / 控制流、测试策略或实现范围，不直接改写既有 tasks；应通过代码类 DR 创建新的增量 plan。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ...
**Architecture:** ...
**Tech Stack:** ...

## Global Constraints

...

### Task 1: ...
**Files:**
...
**Interfaces:**
...
- [ ] Step 1: ...
```

### 7.4 `decisions/*.md`

```md
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- tag：fix | feat | chg | arch | spec | doc | typo
- 日期：YYYY-MM-DD
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |

## 背景
## 决策
## 影响
## 落地方式
```

## 8. Status / Doctor / Archive

### 8.1 `/sdd:status`

`/sdd:status` 是导航命令，不是诊断命令。

输出：

1. 当前活跃版本
2. PRD 是否存在
3. SPEC 状态
4. Plans 状态列表
5. Drafting DR 列表
6. Accepted DR 列表
7. 下一步建议

示例：

```text
当前活跃版本：v0.1.0

PRD：存在
SPEC：approved

Plans：
- 001-feature-login：done
- 002-fix-0001-null-login：coding

DRs：
- drafting：arch-0002-split-auth
- accepted：fix-0001-null-login

下一步建议：
- /sdd:code 002
```

### 8.2 `/sdd:doctor`

`/sdd:doctor` 是诊断命令。

检查：

```text
Plugin 安装完整性：
- .claude-plugin/plugin.json
- 11 个 skills/<name>/SKILL.md
- hooks/hooks.json
- scripts/install-deps.sh
- scripts/hooks/pre-tool-use.sh
- CONSTITUTION.default.md
- 模板文件
- Superpowers / Spec-Kit 可达性

项目最小一致性：
- 是否存在 docs/CONSTITUTION.md
- 是否存在唯一活跃版本
- status 行是否可解析
- status 值是否合法
- accepted 代码类 DR 是否有去掉 `NNN-` 前缀后与 DR ID 对应的 plan
- done 的代码类 DR plan 对应 DR 是否仍 accepted
- closed DR 是否有 closed_reason
```

不做：

- 不做 git log 回溯
- 不做源码变更审计
- 不做 CONSTITUTION must / should 机器验证

### 8.3 `/sdd:archive`

前置条件：

1. 存在唯一活跃版本。
2. `prd.md` 存在。
3. `spec.md` 状态为 `approved`。
4. 所有 `plans/*.md` 状态为 `done`。
5. 不存在 `drafting` DR。
6. 不存在 `accepted` DR。

动作：

```text
docs/vX.Y.Z/ → docs/archive/vX.Y.Z/
```

若是 git 仓库，优先使用 `git mv`。否则使用 `mv`。

不移动：

```text
docs/requirements/
docs/CONSTITUTION.md
```

不修改归档后的文档状态。

## 9. MVP 验收标准

### 9.1 初始化与版本

- `/sdd:init` 能创建 `docs/CONSTITUTION.md`、`docs/requirements/`、`docs/archive/`，且不依赖 `CLAUDE.md` / `AGENTS.md`。
- `/sdd:new v0.1.0` 能创建 `docs/v0.1.0/specs`、`plans`、`decisions`。
- 存在多个未归档版本时，主流程 Skill 拒绝执行。

### 9.2 PRD → SPEC

- `/sdd:prd` 能生成无状态 `prd.md`。
- `/sdd:spec` 在 `prd.md` 不存在时拒绝。
- `/sdd:spec` 能通过对话生成 `spec.md`，初始状态 `draft`。
- 用户确认后 `spec.md` 状态变为 `approved`。

### 9.3 SPEC → PLAN

- `/sdd:plan login` 在 spec 非 `approved` 时拒绝。
- `/sdd:plan login` 能按最大序号加一生成 `plans/001-feature-login.md`。
- 后续 plan 能继续生成 `002-*`、`003-*`，不覆盖已有 plan。
- plan 初始状态 `draft`。
- 用户确认后 plan 状态变为 `planned`。
- plan 包含 SDD header、Technical Design、Superpowers-compatible tasks。

### 9.4 DR → PLAN → CODE

- `/sdd:dr fix <title>` 能生成 `drafting` DR。
- `/sdd:dr accept <id>` 能将 DR 改为 `accepted`。
- `/sdd:plan <id>` 在代码类 DR 非 `accepted` 时拒绝。
- `/sdd:plan <id>` 能生成 `plans/NNN-<dr-id>.md`，并保留完整 DR ID。
- `/sdd:code NNN` 能精确定位并执行编号 plan。
- 非编号输入匹配多个 plan 时，`/sdd:code` 拒绝并提示使用序号。
- `/sdd:code NNN` 完成后 plan 状态 `done`，DR 状态 `closed`，`closed_reason: committed`。
- 文档类 DR 被 `/sdd:spec` 关联并批准落地后，DR 状态 `closed`，`closed_reason: committed`。

### 9.5 CODE 执行

- `/sdd:code <NNN|work-item>` 在 plan 非 `planned` / `coding` 时拒绝。
- `/sdd:code` 启动时让用户选择：
  - 高质量模式：`subagent-driven-development`
  - 快速模式：`executing-plans`
- 执行失败时 plan 保持 `coding`。
- 执行成功 + verification 通过后 plan 状态 `done`。

### 9.6 Hook

- 写 `spec.md` 但 `prd.md` 不存在 → Hook 拒绝。
- 写 feature plan 但 spec 非 `approved` → Hook 拒绝。
- 写代码类 DR plan 但 DR 非 `accepted` → Hook 拒绝。
- 写 `src/**` → Hook 不拦。

### 9.7 Status / Doctor / Archive

- `/sdd:status` 能显示活跃版本、PRD、SPEC、plans、drafting / accepted DR 和下一步建议。
- `/sdd:doctor` 能检查 Plugin 安装完整性、`docs/CONSTITUTION.md` 存在性和最小项目一致性。
- `/sdd:archive` 在存在未 done plan 或 drafting / accepted DR 时拒绝。
- `/sdd:archive` 成功后移动版本目录，不移动 `docs/requirements/`。

## 10. MVP 明确不实现

以下能力不进入 MVP；后续 implementation plan 不得把它们作为 v0.1 任务加入：

- 集中状态仓库：`.sdd/state.json`、SQLite、JSON cache。
- 多活跃版本或 `current-version` 文件。
- `src/**` Hook 门控。
- CONSTITUTION `must` / `should` 机器解析。
- git log CONFORMANCE 回溯。
- PostToolUse 进度记账。
- PreCompact 状态持久化。
- 字段级 status 防篡改。
- 自动判断 PRD 是否已批准。
- 自动解析 plan checkbox 作为 SDD `done` 真相。
- 自动修改 `CLAUDE.md` / `AGENTS.md`。
- 独立 TRD / technical-design 文档层。
- 公开插件市场分发。
