# SDD Plugin v0.1 实现规格（文档驱动状态）

> 本文档描述 SDD Codeagent Plugin v0.1 的**实现规格**：可在 Claude Code 平台上手工 / 半自动验收的功能切片。
>
> **v0.1 设计原则**：**完全砍掉 `state.json`，所有状态信息在各文档头部就地保存**——`prd.md` / `spec.md` / `plan-*.md` / `dr-*.md` / `research.md` 各自维护 `- 状态：<value>` 字段。Plugin / Skill 负责维护各文档的 status 字段，不做集中状态仓库。

## 0. 范围与不在范围

### 0.1 v0.1 入范围（先做）

- **11 个 Skill 直接当 slash command 入口**：`/sdd:init`、`/sdd:new`、`/sdd:research`、`/sdd:prd`、`/sdd:spec`、`/sdd:plan`、`/sdd:code`、`/sdd:dr`、`/sdd:status`、`/sdd:archive`、`/sdd:doctor`（命名风格跟 superpowers 一致）
  - 7 个主流程 Skill：`init`、`new`、`research`、`prd`、`spec`、`plan`、`code`
  - 4 个 Skill 横切：`dr`、`status`、`archive`、`doctor`
- **文档驱动状态模型**：每个文档头部 `- 状态：<value>` 字段，无 `state.json`
- PreToolUse L1 路径门控（读目标路径对应前置文档的 status 字段）
- CONSTITUTION.md 八章节骨架 + 默认 must 条款
- DR 决策模型（v0.1 简化：单一 `drafting / closed` 两态，关闭原因 in-file 标注）
- 5 个文档模板：`research` / `prd` / `spec` / `feature-plan` / `dr`（每模板头部含 status 字段）
- `scripts/install-deps.sh` + 三道防线（`/sdd:init` 调 + SessionStart 检查 + doctor 诊断）

### 0.2 v0.1 不入范围（后做）

- `state.json` 集中状态仓库——v0.1 砍掉，所有状态在文档就地维护
- L2 / L3 宪法 must / should 检查（PreToolUse）—— v0.1 只做 L1 文档 status 校验
- CONFORMANCE 回溯检测（`/sdd:doctor` B 组）—— v0.2
- PostToolUse 进度记账 —— v0.2
- PreCompact 持久化 —— v0.2
- `/sdd:status` 详细输出 —— v0.1 只做最小版（扫文档输出）
- `/sdd:doctor` B 组（项目状态诊断）—— v0.1 只做 A 组
- `/sdd:research` 硬门 —— v0.1 不设
- 多版本并行 —— v0.1 仅支持单一活跃版本

### 0.3 裁剪依据

- 文档驱动状态满足 v0.1 最小可跑闭环
- 砍掉 `state.json` 消除了字段同步守护问题（§3.5 整章简化）
- L1 路径门控改读文档 status，Hook 不需 hardcode phase 状态
- 文档间依赖图（hardcode 在 hook 里）覆盖主要写作路径

---

## 1. 顶层目录与文件清单

```
sdd-codeagent-plugin/
├── .claude-plugin/
│   └── plugin.json                          # 仅 name/version/description
├── skills/                                   # 11 个 Skill 直接当 slash command 入口
│   ├── init/
│   │   └── SKILL.md
│   ├── new/
│   │   └── SKILL.md
│   ├── research/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── research.md.tmpl              # 文档模板放 skill 内 references/
│   ├── prd/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── prd.md.tmpl
│   ├── spec/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── spec.md.tmpl
│   ├── plan/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── feature-plan.md.tmpl
│   ├── code/
│   │   └── SKILL.md                          # 无文档模板（直接读 plan）
│   ├── dr/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── dr.md.tmpl
│   ├── status/
│   │   └── SKILL.md                          # 无文档模板（只读）
│   ├── archive/
│   │   └── SKILL.md                          # 无文档模板
│   └── doctor/
│       └── SKILL.md                          # 无文档模板
├── scripts/                                  # POSIX 脚本
│   ├── install-deps.sh                       # 三道防线之一
│   └── hooks/
│       ├── pre-tool-use.sh                   # L1 文档 status 校验
│       └── session-start.sh                  # 依赖检查 + CONSTITUTION 注入
├── hooks/
│   └── hooks.json                            # Hook 注册
├── CONSTITUTION.default.md                   # 宪法骨架默认内容
└── README.md                                 # Plugin 自身 README
```

> **Skill 目录约定**（跟 superpowers 一致）：
> - `skills/<name>/SKILL.md` ← Skill 入口（必需）
> - `skills/<name>/references/` ← 文档模板、参考材料（可选）
> - `skills/<name>/scripts/` ← Skill 内部脚本（可选，本项目未使用）
> - `skills/<name>/examples/` ← Skill 使用示例（可选，本项目未使用）
> - **禁止** `skills/<name>/templates/` 子目录约定（与 Claude Code Skills 规范不符）
>
> **不**创建 `commands/` 目录、`templates/` 全局共享目录、`.sdd/state.json`、`scripts/status.js`、`scripts/render-template.js`、`scripts/archive.sh`。

---

## 2. ~~state.json schema~~

v0.1 **不创建 `.sdd/state.json`**——所有状态信息在各文档头部就地维护。详细约束见 §3 文档驱动状态模型。

---

## 3. 文档驱动状态模型

### 3.1 文档头部 status 字段约定

每个 spec / prd / plan / DR / research 文档**头部维护** `- 状态：<value>` 字段，由 Skill 在写作时创建、由批准动作切换。

| 文档类型 | status 取值 | 创建者 | 切换者 |
| --- | --- | --- | --- |
| `research.md` | `open` / `closed` | `research` | 用户 |
| `prd.md` | `draft` / `approved` | `prd` | 用户批准 |
| `spec.md` | `draft` / `approved` | `spec` | 用户批准 |
| `plans/feature-*.md` | `draft` / `planned` / `coding` / `done` | `plan` | 用户批准 / `/sdd:code` 启动 / 完成 |
| `plans/fix-*.md` | `draft` / `planned` / `coding` / `done` | `plan`（DR 触发的 fix 模式） | 同上 |
| `decisions/*.md` (DR) | `drafting` / `closed` | `dr` | `/sdd:dr accept \| dismiss` |

### 3.2 文档依赖图（hook hardcode）

L1 PreToolUse hook 把目标路径映射到「前置文档」，读前置文档 status 判定是否允许写入：

| 写入路径 | 前置文档 | 前置 status 条件 |
| --- | --- | --- |
| `docs/vX.Y.Z/prd.md` | 无 | 任何阶段都可写（起 draft） |
| `docs/vX.Y.Z/specs/spec.md` | `docs/vX.Y.Z/prd.md` | `approved` |
| `docs/vX.Y.Z/plans/feature-*.md` | `docs/vX.Y.Z/specs/spec.md` | `approved` |
| `docs/vX.Y.Z/plans/fix-*.md` | `docs/vX.Y.Z/decisions/<同名 DR>.md` | `drafting`（fix 模式：DR `accept` 之前不能写 plan） |
| `docs/vX.Y.Z/decisions/*.md` | 无 | 任何阶段都可写（起 drafting） |
| `docs/requirements/*.md` | 无 | 不进入 L1（项目级调研文档） |
| `src/**` | 无 | 不进入 L1（v0.1 源码路径不拦截） |

### 3.3 DR 关闭原因（in-file 标注）

DR 关闭原因**只写在 DR 文件头部**「关闭记录」段，不写入任何集中状态：

```markdown
## 关闭记录
- closed_reason: committed | superseded | dismissed | null
- closed_at: YYYY-MM-DDTHH:MM:SSZ
- supersedes: [<old-dr-id>, ...]      # 本 DR 取代的旧 DR
- superseded_by: <new-dr-id> | null    # 谁取代了本 DR
- dismissed_reason: <reason> | null    # 用户提供的 dismiss 理由
```

| 关闭原因 | closed_reason 取值 | 何时写入 |
| --- | --- | --- |
| 用户接受 | `committed` | `/sdd:dr accept <id>` |
| 被新 DR 取代 | `superseded` | 新 DR `accept` 时回填（旧 DR 的 `superseded_by` 字段） |
| 偏差不成立 | `dismissed` | `/sdd:dr dismiss <id> <reason>` |

### 3.4 DR supersede / dismiss 范围

- **`drafting` 阶段**：可 dismiss（`/sdd:dr dismiss <id> <reason>`），可在 `supersedes` 字段写入旧 DR ID
- **`closed` 阶段**：**不**允许 dismiss —— 错误时另起 DR `supersede` 旧 DR
- **supersede 链回填**：新 DR `closed (committed)` 时**才**回填旧 DR 的 `superseded_by` 字段。新 DR 中途 `dismissed` 旧 DR 完全不受波及

### 3.5 跨文档变更追溯

每个文档头部维护「关联 DRs」表 + 章节变更履历。变更追溯纯文档级：

```markdown
## 关联 DRs
| DR ID | tag | title | closed_reason | date |
| ----- | --- | ----- | ------------- | ---- |

<details><summary>变更履历</summary>

| 序号 | DR ID | tag | 摘要 |
| ---- | ----- | --- | ---- |
</details>
```

`/sdd:dr` Skill 在状态流转时维护这些表字段。

---

## 4. Skill 列表（11 个 slash command 入口）

> **v0.1 入口机制**：所有 11 个 Skill 直接当 slash command 入口（`/sdd:<skill-name>`），跟 superpowers 一致。每个 Skill 的 YAML frontmatter `name` 字段是命令短名，`description` 让 Claude 在自然语言场景自动识别。
>
> **不再有 `commands/` 目录**——Skill 自己处理 args 解析 + 业务逻辑。

| Skill | 前置条件（读文档 status） | 写产物 |
| --- | --- | --- |
| `init` | 无 | `docs/CONSTITUTION.md` + `docs/` 目录骨架 |
| `new <version>` | `docs/CONSTITUTION.md` 存在（已初始化） | `docs/vX.Y.Z/` 目录 |
| `research <topic>` | 无 | `docs/requirements/<slug>-<yyyy-mm>.md` |
| `prd` | 无 | `docs/vX.Y.Z/prd.md`（status: draft） |
| `spec` | `docs/vX.Y.Z/prd.md` status == approved | `docs/vX.Y.Z/specs/spec.md`（status: draft） |
| `plan <name>` | feature 模式：`spec.md` status == approved；fix 模式：同名 DR status == drafting | `docs/vX.Y.Z/plans/<name>.md` |
| `code <name>` | `plans/<name>.md` status ∈ {planned, coding} | 源码文件 + `plans/<name>.md` status 更新 |
| `dr` | 无（横切 Skill，自身内部 args 解析） | `docs/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md`（status: drafting） 或 状态流转 |
| `status` | 无 | 只读（扫文档） |
| `archive` | 核心文档 status 均 == approved / done | 文件系统 mv |
| `doctor` | 无 | 只读 |

### 4.0 `dr` Skill 内部 args 分发

`dr` Skill 是**多模式** Skill，根据 args 形式分发到三种动作：

| 调起形式 | Skill 动作 |
| --- | --- |
| `/sdd:dr [tag] <title>` | args 解析：tag ∈ {fix,feat,chg,arch,spec,doc,typo} + title slug → 起草模式 → 写新 DR 文件，status: drafting |
| `/sdd:dr accept <id>` | args 解析：单 token 当作 DR ID → accept 模式 → status 改 closed + 写 `closed_reason: committed` + `closed_at` + supersede 链回填 |
| `/sdd:dr dismiss <id> <reason>` | args 解析：首 token DR ID + 其余 join 为 reason → dismiss 模式 → status 改 closed + `closed_reason: dismissed` + `dismissed_reason` |

**Skill 内部 args 解析规则**：
- 首 token 是 `accept` / `dismiss` → 子命令模式
- 首 token 是 tag enum 之一 → 起草模式
- 其他 → 错误 + 提示「用法：`/sdd:dr [tag] <title>` / `/sdd:dr accept <id>` / `/sdd:dr dismiss <id> <reason>`」

### 4.1 阶段 Skill 的前置校验（读文档 status）

| Skill | 前置校验 |
| --- | --- |
| `spec` | `docs/vX.Y.Z/prd.md` status == approved |
| `plan <name>` (feature) | `docs/vX.Y.Z/specs/spec.md` status == approved |
| `plan <DR-id>` (fix) | `docs/vX.Y.Z/decisions/<DR-id>.md` status == drafting |
| `code <name>` | `docs/vX.Y.Z/plans/<name>.md` status ∈ {planned, coding} |
| `archive` | 核心文档（`prd.md` / `spec.md` / `plans/*.md`）均 status == approved / done |

---

## 5. PreToolUse L1 文档自身 status 校验

### 5.1 路径 → 前置文档映射（hook hardcode）

参见 §3.2 表。

### 5.2 文档 status 读取规则

L1 PreToolUse hook 用 bash 实现：

```bash
# 1. 解析目标写入路径
target_path="$1"

# 2. 路径 → 前置文档映射
case "$target_path" in
  docs/v*/prd.md)            require=() ;;
  docs/v*/specs/spec.md)     require=("docs/v$ver/prd.md") ;;
  docs/v*/plans/feature-*)   require=("docs/v$ver/specs/spec.md") ;;
  docs/v*/plans/fix-*)       require=("docs/v$ver/decisions/<DR-id>.md") ;;
  docs/v*/decisions/*)       require=() ;;
  docs/requirements/*)       require=() ;;  # 不进入 L1
  src/*)                      require=() ;;  # 不进入 L1
  *)                          require=() ;;
esac

# 3. 读每个前置文档头部 status 字段
for prereq in "${require[@]}"; do
  status=$(grep -E "^- 状态：" "$prereq" | head -1 | awk '{print $NF}')
  expected=$2  # 该前置文档期望的 status 值
  if [[ "$status" != "$expected" ]]; then
    echo "前置文档 $prereq 状态为 $status，期望 $expected" >&2
    exit 2
  fi
done

exit 0
```

### 5.3 越阶段处理

```
exit code: 2
stderr: "前置文档 <path> 状态 <current>，期望 <expected>。请先执行对应阶段 Skill"
```

### 5.4 Hook 实现位置

`scripts/hooks/pre-tool-use.sh`（POSIX bash），由 `hooks/hooks.json` 注册到 `PreToolUse Write/Edit` 事件。

---

## 6. CONSTITUTION 骨架

`CONSTITUTION.default.md`（Plugin 自带，`/sdd:init` 时复制到 `docs/CONSTITUTION.md`）：

```markdown
# CONSTITUTION

> SDD Plugin 项目级流程强制约束。修改请保留章节结构，只改 severity / 细则。

## 1. 阶段门控
- must: 文档状态推进必须由 `/sdd:<阶段>` Skill 触发，禁止直接 Edit 切 status

## 2. DR 流程
- must: 任何修改代码（fix / feat / chg / arch）前必须先有 status == drafting 的 DR
- must: 跨版本修改代码必须先 `/sdd:dr` 起草 DR，不能 `/sdd:code` 绕过 DR
- must: 修改 specs/spec.md / feature-*.md 前必须有 spec / doc DR（status: drafting）
- may: typo 类修订可跳过 DR
- may: `docs/requirements/*.md` 修订不强制走 DR

## 3. Skill 身份
- must: 各 Skill 只做自己份内事
- must: Skill 改文档 status 字段，由 Skill 自己负责状态切换

## 4. subagent 调度
- must: subagent 不写状态字段

## 5. Hooks 行为
- must: Hook 只守护「路径 → 前置文档 status」的合法性
- must: Hook 失败时退出码 2 + stderr 提示，**不**做隐式绕过

## 6. 多 Skill 协作
- must: 主流程 Skill 之间通过文档 status 字段同步

## 7. 错误处理
- must: Skill 失败时**不**破坏文档状态字段（保留上一稳定态）

## 8. 门控破坏检测
- must: v0.2 实现 CONFORMANCE 检查（回扫 git log 比对文档 status）
```

---

## 7. 5 个文档模板（头部含 status 字段）

### 7.1 `skills/research/references/research.md.tmpl`

```markdown
# 研究：<topic>

> 项目级调研文档（不参与版本阶段门控）。
> 创建：{{date}}  作者：<author>
> 状态：open

## 背景
<为什么研究这个问题？>

## 调研方法
<如何调研？读了哪些资料？>

## 发现
### 关键事实 1
### 关键事实 2
### 关键事实 3

## 建议
<对项目的下一步建议>

## 关联 DRs
| DR ID | tag | title | closed_reason | date |
| ----- | --- | ----- | ------------- | ---- |
```

### 7.2 `skills/prd/references/prd.md.tmpl`

```markdown
# PRD：<项目名>

> 版本：{{version}}
> 状态：draft

## 1. 用户故事
（3-5 个核心用户故事）

## 2. 功能范围
### 2.1 必做
### 2.2 不做
### 2.3 后续

## 3. 验收标准
（可量化的标准）

## 4. 风险与依赖

## 关联 DRs
| DR ID | tag | title | closed_reason | date |
| ----- | --- | ----- | ------------- | ---- |
```

### 7.3 `skills/spec/references/spec.md.tmpl`

```markdown
# SPEC：<项目名>

> 版本：{{version}}
> 状态：draft
>
> **重要**：v0.1 `skills/spec/references/spec.md.tmpl` 是 Plugin 自带的占位骨架。运行时由 `spec` Skill 调用 Spec-Kit 提供的 `spec-template.md`（User Story P1/P2/P3 + Given-When-Then Acceptance Scenarios），并把 Spec-Kit `plan-template.md` 中的"项目层元信息"（Technical Context / Constitution Check / Project Structure）合并到 spec.md 头部。
>
> Plugin 模板仅做"双 DR 表占位"+"章节变更履历 details 块占位"，最终内容由 Skill + Spec-Kit 共同生成。

## Technical Context
（语言 / 框架 / 部署目标）

## Constitution Check
（对照 CONSTITUTION §1-§7 must 条款）

## Project Structure
（顶层目录规划）

## 关联 DRs
| DR ID | tag | title | closed_reason | date |
| ----- | --- | ----- | ------------- | ---- |
（自动 append，由 dr 维护）

## §1. <一级章节>
（章节内容…）

<details><summary>变更履历</summary>

| 序号 | DR ID | tag | 摘要 |
| ---- | ----- | --- | ---- |
（自动 append，由 dr 维护）
</details>
```

### 7.4 `skills/plan/references/feature-plan.md.tmpl`

```markdown
# Plan：<name>

> 模式：{{mode}}
> 状态：draft
>
> **重要**：v0.1 `skills/plan/references/feature-plan.md.tmpl` 是 Plugin 自带占位骨架。运行时由 `plan` Skill 调用 Superpowers `writing-plans` 生成实际内容（任务列表 [ID] [P?] [Story] + TDD 步骤 + commit 粒度）。Plugin 模板仅做头部状态行占位。

## 关联 DRs
| DR ID | tag | title | closed_reason | date |
| ----- | --- | ----- | ------------- | ---- |

## 任务列表

### [1] [P?] [Story] <带文件路径的描述>
- 状态：todo
- TDD：
  - RED: <测试用例描述>
  - GREEN: <实现描述>
  - REFACTOR: <重构描述>
- commit: <commit message>

### [2] ...
```

### 7.5 `skills/dr/references/dr.md.tmpl`

```markdown
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- tag  ：{{tag}}
- 日期：{{date}}

## 影响的 spec 资产
| 资产 | 章节 / ID |
| ---- | --------- |
| specs/spec.md | §3.1 |
| plans/feature-payment.md | Task 2 |

## 现象
（输入是什么、输出是什么、当前实际行为与期望的偏差。）

## 期望
（按 spec 验收标准或用户表述，期望的正确行为。）

## supersedes
（可选，被本 DR 取代的旧 DR ID 列表。）

## superseded_by
（自动维护：本 DR 被取代后由 Skill 写入新 DR 的 ID。）

## 关闭记录
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null
```

> **NNNN 跨 tag 共享同一序号池**：`fix-0001`、`spec-0005` 共用全局递增（`max(existing) + 1`）。

---

## 8. install-deps.sh 与依赖完备性

### 8.1 `scripts/install-deps.sh`

```bash
#!/usr/bin/env bash
# install-deps.sh - 调用 Claude Code CLI 装外部依赖 Plugin
set -e

check() {
  local plugin_name="$1"
  claude plugin list 2>/dev/null | grep -q "^${plugin_name}\b"
}

install() {
  local plugin_name="$1"
  local source="$2"
  if check "$plugin_name"; then
    echo "[skip] ${plugin_name} 已装"
  else
    echo "[installing] ${plugin_name}..."
    claude plugin install "$source"
  fi
}

install "superpowers" "claude-plugins-official/superpowers"
install "spec-kit" "claude-plugins-official/spec-kit"

echo "[done] 所有依赖已就绪"
```

### 8.2 三道防线

| 时机 | 触发点 | 行为 |
| --- | --- | --- |
| **首次安装** | 用户手动跑 `scripts/install-deps.sh` | 装外部依赖 |
| **`/sdd:init`** | 项目初始化 Skill | 调 install-deps.sh + 验证依赖到位 |
| **SessionStart Hook** | 每次会话启动 | 检查 Superpowers / Spec-Kit 可达性，缺失提示用户 |

### 8.3 v0.1 `/sdd:init` 流程（无 state.json 极简版）

1. 检测 `docs/CONSTITUTION.md` 是否存在：
   - 不存在 → 继续
   - 存在 → 拒绝并提示「已初始化，请用 `/sdd:status` 查看当前状态」
2. 调用 `scripts/install-deps.sh`：
   - 退出码 0 → 步骤 3
   - 非零 → 报错 + 提示「请先手动运行 `scripts/install-deps.sh`」
3. 验证依赖（`claude plugin list` 包含 superpowers + spec-kit）：
   - 都包含 → 步骤 4
   - 任一缺失 → 报错
4. 创建 `docs/` 目录结构（requirements / archive 子目录）
5. 写入 `docs/CONSTITUTION.md`（从 `CONSTITUTION.default.md` 拷贝）
6. 完成

---

## 9. v0.1 验收清单

v0.1 视为完成，当且仅当以下 7 项全部通过：

1. **Plugin 装入 Claude Code**：`/plugin install <path>` 后 `/sdd:init` 等 Skill 可见
2. **空白仓库端到端**：依次跑 `/sdd:init → /sdd:new v0.0.1 → /sdd:research → /sdd:prd → /sdd:spec → /sdd:plan demo → /sdd:code demo`，仅在阶段门控点（PRD / spec / plan 批准）由用户做一次批准
3. **L1 文档自身 status 校验**：写 `docs/vX.Y.Z/specs/spec.md` 但 `prd.md` 状态非 `approved` → PreToolUse 退出码 2 + 提示
4. **`/sdd:status`**：扫所有 `docs/vX.Y.Z/` 文档输出每个文档 status；列出所有 status == drafting 的 DR
5. **`/sdd:archive`**：把 `docs/v0.0.1/` 迁移到 `docs/archive/v0.0.1/`（含 `prd.md / specs/spec.md / plans/*.md / decisions/*.md`）；git 跟踪则 `git mv`，未跟踪则 `mv`；`docs/requirements/*.md` **不**随版本归档
6. **外部框架调用**（约束）：所有对外部框架（Superpowers / Spec-Kit）的调用都通过 Skill 编排，不在 Plugin 内部复制实现
7. **DR 流程验证**：
   - 7.1 `/sdd:dr fix <title>` → 起 DR 文件 status == drafting
   - 7.2 `/sdd:dr accept <id>` → DR 文件 status == closed，`关闭记录` 段写 `closed_reason: committed`、`closed_at`、`supersede` 链回填（如有 `supersedes`）
   - 7.3 `/sdd:dr dismiss <id> <reason>` → status == closed、`closed_reason: dismissed`、`dismissed_reason`
   - 7.4 `closed` 阶段 DR dismiss Skill 拒绝，提示「错误时另起 DR supersede」

---

## 10. v0.1 简化决策

v0.1 是独立实现规格文档，以下是 v0.1 范围内**有意做出的简化**：

| 差异项 | v0.1 实现 | 备注 |
| --- | --- | --- | --- |
| **集中状态仓库（state.json / SQLite / JSON）** | **不创建**——状态全在文档头部就地维护 | 消除字段同步守护问题 |
| **`committing` 中间态** | 简化为 `drafting → closed` 直跳 | v0.1 失败由用户重试 |
| **`affects_frozen` 字段** | 简化为 `drafting` 阶段即视为冻结 | 减少字段 |
| **`closed_via` 字段** | 不写入 | 关闭原因只 in-file 标注 |
| **`artifacts.spec.drs` 数组** | **不写**，只通过 spec.md 头部「关联 DRs」表 + 章节变更履历维护 | 文档驱动，不开集中索引 |
| **L2 / L3 宪法检查** | 不实现 | v0.1 L1 已够 |
| **CONFORMANCE 回溯** | 不实现 | 留给后续版本 |
| **`artifacts.features[*].status`** | 移入 `plans/<name>.md` 头部 status 字段 | 文档驱动 |
| **集中状态机（INITED→PRD→SPEC→FEATURE_PLAN→CODE→RELEASE→ARCHIVED）** | 由文档 status 派生（读 PRD / SPEC / plan 头部 status） | 文档是真相 |
| **PreToolUse L1 phase 集合** | hardcode 在 hook 里，但读文档 status 而非集中状态 | 文档驱动 |
| **`/sdd:research` 硬门** | 不设硬门 | v0.1 不影响流程 |
| **DR 派发告警** | 不实现 | v0.1 subagent 只看 plan + spec |
| **PostToolUse / PreCompact** | 不实现 | 留给后续版本 |
| **`/sdd:doctor` B 组** | 不实现 | 留给后续版本 |
| **`commands/` 目录 + 转发层** | **不创建**——11 个 Skill 直接当 slash command 入口 | 跟 superpowers 一致，避免双层冗余 |
| **顶层 `templates/` 共享目录** | **不创建**——文档模板按 Skill 拆分，放 `skills/<name>/references/<name>.md.tmpl` | 跟 Claude Code Skills 规范一致：skill 内允许 `scripts/` `examples/` `references/` 子目录，**禁止 `templates/` 子目录约定** |

---

## 11. 不入范围（v0.1 明确放弃）

- 任何形式的集中状态仓库（`.sdd/state.json`、SQLite、JSON file 都不要）
- `commands/` 目录（slash command 转发层）—— Skill 直接当入口，不开双层
- 顶层 `templates/` 全局共享目录——文档模板按 Skill 拆分进 `skills/<name>/references/`
- `skills/<name>/templates/` 子目录约定——不符合 Claude Code Skills 规范
- Hook 字段级 status 修改守护（v0.1 接受用户手工改 status 字段）
- L2 / L3 宪法 must/should 检查
- CONFORMANCE 回溯检测
- PostToolUse 进度记账
- PreCompact 持久化
- `/sdd:doctor` B 组（项目状态诊断）
- `/sdd:status` 详细输出（v0.1 只扫文档输出）
- 跨平台适配（OpenCode / Cursor / Copilot CLI）
- 多版本并行 state.json
- Plugin 分发到公开市场
- 公开 PRD 演子（跨版本复制）
- 跨会话并发（state.json 多终端同时写——已砍）
- Hook 脚本语言跨平台统一（v0.1 仅 bash）

---

## 12. 开放问题（v0.1 后续）

- **文档驱动状态的可观察性**：v0.1 没有集中状态，`/sdd:status` 扫所有文档的性能开销。/sdd:status 大于 N 个文档时是否需要缓存？—— 评估
- **supersede 链的存储**：v0.1 DR 文件自身标注 supersede 链，但跨多 DR 的链式 supersede（DR A superseded_by DR B，DR B superseded_by DR C）仅靠逐个文件读，能否快速查询？—— 评估
- **commit vs accept 的语义边界**：v0.1 DR `closed` 不代表"行动已落地"，代码 / 文档落地由文档自身 status 跟踪。两条线的耦合度？—— 评估
- **Hook 读 status 字段的解析精度**：v0.1 L1 hook 用 `grep -E "^- 状态："` 读文档 status，Markdown 格式漂移（缩进、表格混排）会破坏解析。是否引入结构化解析？—— 评估

---

**最后更新**：2026-07-10
