# SDD Plugin

SDD Plugin 是一个面向 Claude Code 的 Specification Driven Development（SDD）工作流插件。它通过一组 `/sdd:*` slash commands，把项目开发流程组织为：需求资料 → PRD → Functional Specification → Implementation Plan → Code → Archive，并提供 Decision Record（DR）变更闭环和最小 Hook 门控。

## 功能概览

SDD Plugin MVP 提供以下能力：

- 初始化项目级 SDD 目录和流程宪法 `docs/CONSTITUTION.md`
- 创建唯一活跃版本目录 `docs/vX.Y.Z/`
- 生成项目级调研资料 `docs/requirements/*.md`
- 生成无状态 PRD：`docs/vX.Y.Z/prd.md`
- 生成 Functional Specification：`docs/vX.Y.Z/specs/spec.md`
- 生成 Implementation Plan：`docs/vX.Y.Z/plans/NNN-*.md`
- 按 plan 执行代码实现
- 创建、接受、驳回 Decision Record
- 查看当前 SDD 状态
- 做插件安装和项目一致性诊断
- 归档已完成版本到 `docs/archive/`
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

```bash
cd /path/to/sdd-plugin
```

如果你正在使用本仓库当前 worktree，可进入：

```bash
cd /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.worktrees/sdd-plugin-mvp-workflow
```

### 2. 安装依赖 plugin

```bash
scripts/install-deps.sh
```

该脚本会检查并从 GitHub 仓库安装依赖 plugin，不依赖 Claude plugin marketplace：

```text
superpowers: https://github.com/obra/superpowers.git
spec-kit: https://github.com/github/spec-kit.git
```

### 3. 安装本地 plugin 到 Claude Code

```bash
claude plugin install /path/to/sdd-plugin
```

当前 worktree 示例：

```bash
claude plugin install /Users/apple/Desktop/vibecoding-project/SDD-Land-Spec/.worktrees/sdd-plugin-mvp-workflow
```

也可以在 Claude Code 交互界面中执行：

```text
/plugin install /path/to/sdd-plugin
```

### 4. 查看安装结果

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
/sdd:new v0.1.0
/sdd:status
```

预期结果：

- `/sdd:init` 创建：
  - `docs/CONSTITUTION.md`
  - `docs/requirements/`
  - `docs/archive/`
- `/sdd:new v0.1.0` 创建：
  - `docs/v0.1.0/specs/`
  - `docs/v0.1.0/plans/`
  - `docs/v0.1.0/decisions/`
- `/sdd:status` 展示当前活跃版本状态和下一步建议。

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
PRD → Functional Specification → Implementation Plan → Code → Archive
```

## 变更流程

代码类变更使用 DR 流程：

```text
/sdd:dr fix|feat|chg|arch <title>
  → /sdd:dr accept <id>
  → /sdd:plan <id>
  → /sdd:code <NNN|id>
```

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
| `/sdd:init` | 初始化当前项目的 SDD 目录结构和 `docs/CONSTITUTION.md` |
| `/sdd:new vX.Y.Z` | 创建唯一活跃版本目录 |
| `/sdd:research <topic>` | 生成项目级调研资料 |
| `/sdd:prd` | 生成产品需求文档 PRD |
| `/sdd:spec` | 基于 PRD 生成 Functional Specification |
| `/sdd:plan <work-item>` | 基于 approved spec 或 accepted code-class DR 生成 Implementation Plan |
| `/sdd:code <NNN|work-item>` | 按计划执行代码实现 |
| `/sdd:dr <tag> <title>` | 创建 Decision Record |
| `/sdd:dr accept <id>` | 接受 DR，允许后续落地 |
| `/sdd:dr dismiss <id> <reason>` | 驳回 drafting 状态 DR |
| `/sdd:status` | 展示当前版本状态和下一步建议 |
| `/sdd:doctor` | 检查插件安装完整性和项目最小一致性 |
| `/sdd:archive` | 归档当前已完成版本 |

## 文档结构

插件会在使用项目中维护以下结构：

```text
docs/
├── CONSTITUTION.md
├── requirements/
│   └── *.md
├── archive/
└── vX.Y.Z/
    ├── prd.md
    ├── specs/
    │   └── spec.md
    ├── plans/
    │   └── NNN-*.md
    └── decisions/
        └── <tag>-NNNN-<slug>.md
```

## Hook 门控

MVP 只实现 PreToolUse L1 文档门控：

- 写 `docs/vX.Y.Z/specs/spec.md` 前要求 `docs/vX.Y.Z/prd.md` 存在
- 写 `docs/vX.Y.Z/plans/NNN-feature-*.md` 前要求 `spec.md` 状态为 `approved`
- 写 `docs/vX.Y.Z/plans/NNN-{fix,feat,chg,arch}-*.md` 前要求对应 DR 状态为 `accepted`
- 不拦截 `src/**`
- 不解析 `docs/CONSTITUTION.md` 的 `must` / `should`
- 不创建 `.sdd/state.json`

## 本项目验证

在插件项目根目录运行：

```bash
bash tests/test-doctor-contract.sh && bash tests/test-common-library.sh && bash tests/test-pre-tool-use.sh && bash tests/test-skill-contracts.sh && bash tests/test-mvp-acceptance.sh
```

期望输出：

```text
PASS: skeleton contract
PASS: common library
PASS: pre-tool-use hook
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

通常可以先移除旧版本，再重新安装本地目录：

```bash
claude plugin remove sdd
claude plugin install /path/to/sdd-plugin
```

如果你的 Claude Code 版本命令名称不同，以 `claude plugin --help` 或 Claude Code 内 `/plugin` 显示为准。

## MVP Non-Goals

当前 MVP 明确不实现：

- 不创建 `.sdd/state.json`
- 不支持多个未归档活跃版本
- 不对 `src/**` 做 Hook 门控
- 不机器解析 `docs/CONSTITUTION.md` 的 `must` / `should`
- 不做 git log CONFORMANCE 回溯
- 不做 PostToolUse 进度记账
- 不做 PreCompact 状态持久化
- 不自动修改 `CLAUDE.md` 或 `AGENTS.md`
- 不发布到公开插件市场
