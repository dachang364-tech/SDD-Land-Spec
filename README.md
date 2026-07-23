# SDD Plugin

SDD Plugin 是一个面向 Claude Code 的 Specification Driven Development（SDD）工作流插件。它通过一组 `/sdd:*` slash commands，把项目开发流程组织为：需求资料 → PRD → Functional Specification → Implementation Plan → Code → Archive，并提供 Decision Record（DR）变更闭环、统一模板治理和最小 Hook 门控。

## 功能概览

SDD Plugin MVP 提供以下能力：

- 初始化项目级 SDD 目录和流程宪法 `docs/CONSTITUTION.md`
- 在项目根目录缺失 `CLAUDE.md` 时生成默认 Claude Code 项目协作说明；已有时严格保留
- 创建唯一活跃版本目录 `docs/versions/vX.Y.Z/`
- 生成版本内调研资料：`docs/versions/vX.Y.Z/research/*.md`
- 生成无状态 PRD：`docs/versions/vX.Y.Z/prd/prd.md`
- 生成 Functional Specification：`docs/versions/vX.Y.Z/spec/*.md`
- 生成 Implementation Plan：`docs/versions/vX.Y.Z/plan/NNN-*.md`
- 按 plan 执行代码实现
- 创建、接受、驳回 Decision Record
- 对实现后、验收中或测试中的用户疑问执行 `/sdd:triage` 用户疑问分诊，只推荐后续路径，最终由用户选择
- 在 `docs/versions/vX.Y.Z/ARCHIVE.md` 归档已完成版本，并维护 `docs/archive/INDEX.md`
- 通过 PreToolUse Hook 做最小 L1 文档门控

## 安装要求

使用前需要：

- 已安装 Claude Code
- 当前机器可以运行 `claude` CLI
- Git 仓库项目
- Bash 环境

本插件依赖以下 Claude Code plugins：

- `superpowers`
- `spec-kit`

## 本地安装

### 1. 克隆或进入本插件项目

进入本插件仓库根目录：

```bash
cd /path/to/sdd-plugin
```

### 2. 安装依赖 plugin

请用户自行安装依赖插件：

```bash
claude plugin install https://github.com/obra/superpowers.git
claude plugin install https://github.com/github/spec-kit.git
```

如需快捷安装，也可以使用可选辅助脚本：

```bash
scripts/install-deps.sh
```

`/sdd:init` 不会自动安装依赖插件，只会提示用户完成上述安装。

### 3. 添加本地 plugin marketplace

Claude Code 2.1.29 起，`claude plugin install <plugin>` 会从已配置的 marketplace 中查找 plugin；本地目录需要先作为 marketplace 添加，不能直接执行 `claude plugin install /path/to/sdd-plugin`。

安装前确认插件目录包含：

```text
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
agents/doc-reviewer.md
```

添加本地 marketplace：

```bash
claude plugin marketplace add /path/to/sdd-plugin
```

### 4. 从本地 marketplace 安装 SDD plugin

```bash
claude plugin install sdd@sdd-local
```

如果 marketplace 名称不是 `sdd-local`，以 `.claude-plugin/marketplace.json` 中的 `name` 字段为准。

### 5. 查看安装结果

```bash
claude plugin list
```

或在 Claude Code 中执行：

```text
/plugin list
```

确认列表中出现 `sdd`。

## 快速开始

建议先在一个测试项目中试用：

```bash
mkdir -p /tmp/sdd-plugin-test
cd /tmp/sdd-plugin-test
git init
claude
```

进入 Claude Code 后执行：

```text
/sdd:init
/sdd:new v0.2.0
```

预期结果：

- `/sdd:init` 创建：
  - `docs/CONSTITUTION.md`
  - `CLAUDE.md`（仅在项目根目录缺失时生成；已有时保留）
  - `docs/archive/`
  - `.sdd/templates/research/`
  - `.sdd/templates/prd/`
  - `.sdd/templates/spec/`
  - `.sdd/templates/plan/`
  - `.sdd/templates/dr/`
- `/sdd:init` 会提示模板包选择；未显式切换时默认使用 `backend`。
- `/sdd:init` 在项目根目录缺失 `CLAUDE.md` 时会自动生成默认项目协作说明；若已存在则不覆盖、不合并。
- `/sdd:init` 不处理 `AGENTS.md`。
- `/sdd:init` 不会自动安装依赖插件，只会提示用户手动安装 `superpowers` 与 `spec-kit`。
- `/sdd:new v0.2.0` 创建：
  - `docs/versions/v0.2.0/state.json`
  - `docs/versions/v0.2.0/research/`
  - `docs/versions/v0.2.0/prd/`
  - `docs/versions/v0.2.0/spec/`
  - `docs/versions/v0.2.0/plan/`
  - `docs/versions/v0.2.0/dr/`

## 项目模板资产

`/sdd:init` 会将所选模板包展开到 `.sdd/templates/`，这是 `/sdd:research`、`/sdd:prd`、`/sdd:spec`、`/sdd:plan` 和 `/sdd:review` 的运行时唯一模板来源。

`docs/CONSTITUTION.md` 是 SDD 正式流程、状态、review 与门控规则的事实来源；项目根 `CLAUDE.md` 只承载 Claude Code 的项目协作上下文，不替代宪法正文。

当前版本实现的内置模板包为 `backend`。模板包内容由 Plugin 静态资产 `assets/template-packs/backend/` 提供，通过 `/sdd:init` 物化到项目运行时目录；后续文档生成和 reviewer 只读取项目 `.sdd/templates/`，不回退到 Plugin 内置模板。

`/sdd:review` 的实际执行单元是插件安装内容中的 `agents/doc-reviewer.md`；`skills/review/SKILL.md` 负责编排调用合同、mode 顺序和聚合回执约束。

```text
.sdd/
└── templates/
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

## 主流程

SDD Plugin 的主流程是：

```text
/sdd:init
  → /sdd:new vX.Y.Z
  → /sdd:research <topic>   可选
  → /sdd:prd
  → /sdd:spec
  → /sdd:plan <work-item>
  → /sdd:code <NNN|work-item>
  → /sdd:archive
```

对应文档流：

```text
Research → PRD → Functional Specification → Implementation Plan → Code → Archive
```

## Review 流程

`/sdd:review <doc-path>` 是统一 review 入口，由 `/sdd:review` 编排 `doc-reviewer` agent 执行；每次进入 `doc-reviewer` 时只处理一个 mode，但 `/sdd:review` 会按文档类型串起完整的 mode 链路，并先校验机器 JSON 输出是否符合 schema。

- 新建 `research / prd / dr / spec / plan` 文档后，所属 Skill 会显式进入 `/sdd:review <doc-path>`。
- 修改已有文档时，不自动 review；如需复审，请手工执行 `/sdd:review <doc-path>`。
- 系统不再依赖 `PostToolUse Hook` 或 shell runner 触发 review。

默认触发矩阵：

- `research -> quality`
- `prd -> quality`
- `dr -> quality`
- `spec -> quality + feasibility`
- `plan -> quality + feasibility`

其中 `research` 只接入 `quality`，不接入 `feasibility`；并且 `research` 的最小结构校验不要求 `## 文档引用` 表。

## 变更流程

V0.2.0 起，新建 DR 模板会显式记录 `class / spec_change / plan_required / code_required`，用于决定后续是否进入 `/sdd:spec`、`/sdd:plan` 与 `/sdd:code`。

代码类变更使用 DR 流程：

```text
/sdd:dr fix|feat|chg|arch <title>
  → /sdd:dr accept <id>
  → 如果需要修订规格，先 /sdd:spec
  → /sdd:plan <id>
  → /sdd:code <NNN|id>
```

其中，spec-changing code-class DR 在 spec 批准后仍保持 `accepted`，下一步继续进入 `/sdd:plan <id>`，不能在 spec 修订完成时直接关闭。DR ID 是完整文件基名，例如使用 `/sdd:dr accept 001-fix-login-null` 接受 DR。

例如：`/sdd:plan 001-fix-login-null` 会生成 `plan/002-001-fix-login-null.md`。

只修代码且不改契约时，fix DR 通常使用 `spec_change: no`，并生成新的增量 plan。

对于简单实现 bug，可以使用轻量 fix DR：`fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。轻量 fix 不生成 Implementation Plan，但仍必须通过 `/sdd:code <id>` 执行并完成 verification 后才能关闭 DR。

用户在实现后、验收中或测试中提出疑问时，应先运行 `/sdd:triage` 判断问题更可能属于 code、plan、spec、新需求或仅解释。`/sdd:triage` 只输出分类、置信度、已读取依据、原因、推荐路径和可选路径，不创建 DR、不修改 spec、不修改 plan、不修改 code。

spec、plan、DR 之间的引用应使用 Markdown 链接，例如 `[001-feat-example](../dr/001-feat-example.md)`。章节号和标题可以作为普通文本放在链接后，不强制使用 Markdown anchor。

文档类变更使用：

```text
/sdd:dr spec|doc|typo <title>
  → /sdd:dr accept <id>
  → /sdd:spec
  → DR closed
```

## 命令说明

| 命令 | 作用 |
| --- | --- |
| `/sdd:init` | 初始化当前项目的 SDD 目录结构、`docs/CONSTITUTION.md` 与项目运行时模板资产 |
| `/sdd:new vX.Y.Z` | 创建唯一活跃版本目录 |
| `/sdd:research <topic>` | 生成项目级调研资料 |
| `/sdd:prd` | 生成产品需求文档 PRD |
| `/sdd:spec` | 基于 PRD 生成 Functional Specification |
| `/sdd:plan <work-item>` | 基于 approved spec 或 accepted code-class DR 生成 Implementation Plan |
| `/sdd:review [doc-path] [mode?]` | 对已有 research、PRD、spec 或 plan 重新执行 reviewer |
| `/sdd:code <NNN|work-item>` | 按计划执行代码实现 |
| `/sdd:dr <tag> <title>` | 创建 Decision Record |
| `/sdd:dr accept <id>` | 接受 DR，允许后续落地 |
| `/sdd:dr dismiss <id> <reason>` | 驳回 drafting 状态 DR |
| `/sdd:triage [--deep]` | 对用户疑问进行分诊，推荐后续路径并等待用户选择 |
| `/sdd:archive` | 归档当前已完成版本 |

## 文档结构

插件会在使用项目中维护以下结构：

```text
docs/
├── CONSTITUTION.md
├── archive/
│   └── INDEX.md
└── versions/
    └── vX.Y.Z/
        ├── state.json
        ├── research/
        │   └── *.md
        ├── prd/
        │   └── prd.md
        ├── ARCHIVE.md
        ├── spec/
        │   └── *.md
        ├── plan/
        │   └── NNN-*.md
        └── dr/
            └── NNN-<tag>-<slug>.md
```

Decision Record 标准输出路径为 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。

## Hook 门控

MVP 只实现 PreToolUse L1 文档门控：

- 写 `docs/versions/vX.Y.Z/spec/*.md` 前要求 `docs/versions/vX.Y.Z/prd/prd.md` 存在
- 写 `docs/versions/vX.Y.Z/plan/NNN-<slug>.md`（不含 `NNN-<dr-id>.md`，其中 `<dr-id>` 为 `NNN-{fix,feat,chg,arch}-<slug>`）前要求 `spec/*.md` 中至少一个目标 Functional Specification 状态为 `approved`
- 写 `docs/versions/vX.Y.Z/plan/NNN-<dr-id>.md`，其中 `<dr-id>` 为 `NNN-{fix,feat,chg,arch}-<slug>`，前要求对应 DR 状态为 `accepted`
- 允许写 `docs/versions/vX.Y.Z/state.json`、`docs/versions/vX.Y.Z/ARCHIVE.md` 和 `docs/archive/INDEX.md`
- 不拦截 `src/**`
- 不解析 `docs/CONSTITUTION.md` 的 `must` / `should`
- 不创建 `.sdd/state.json`

## 本项目验证

在插件项目根目录运行：

```bash
bash tests/test-template-assets.sh && \
bash tests/test-template-runtime-contract.sh && \
bash tests/test-common-library.sh && \
bash tests/test-pre-tool-use.sh && \
bash tests/test-reference-validation.sh && \
bash tests/test-skill-contracts.sh && \
bash tests/test-mvp-acceptance.sh
```

期望输出：

```text
PASS: template assets
PASS: template runtime contract
PASS: common library
PASS: pre-tool-use hook
PASS: reference validation
PASS: skill contracts
PASS: MVP acceptance
```

## 测试指南

合并或发布前，可以参考：

```text
TESTING.md
```

该文档包含本地测试步骤、Hook 手动验证和安装后试用建议。

## 卸载或重新安装

查看 Claude Code 当前支持的 plugin 命令：

```bash
claude plugin --help
```

通常可以先移除旧版本，更新本地 marketplace，再重新安装：

```bash
claude plugin remove sdd
claude plugin marketplace update sdd-local
claude plugin install sdd@sdd-local
```

如果尚未添加本地 marketplace，先执行：

```bash
claude plugin marketplace add /path/to/sdd-plugin
```

如果你的 Claude Code 版本命令名称不同，以 `claude plugin --help` 和 `claude plugin marketplace --help` 显示为准。

## MVP Non-Goals

当前 MVP 明确不实现：

- 不创建 `.sdd/state.json`
- 不支持多个未归档活跃版本
- 不对 `src/**` 做 Hook 门控
- 不机器解析 `docs/CONSTITUTION.md` 的 `must` / `should`
- 不做 git log CONFORMANCE 回溯
- 不做 PostToolUse 进度记账
- 不做 PreCompact 状态持久化
- 只在项目根目录缺失 `CLAUDE.md` 时生成默认项目协作说明；已有 `CLAUDE.md` 时严格保留，不覆盖、不合并
- 不处理 `AGENTS.md`
- 不发布到公开插件市场
