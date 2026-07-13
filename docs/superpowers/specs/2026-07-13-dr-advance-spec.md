# SDD Plugin V0.2.0 设计规格：DR 分类模板与落地流程

- 日期：2026-07-13
- 状态：draft
- 类型：Design Spec
- 目标：定义 DR 模板分类、字段语义、默认推导规则，以及 code-class / document-class DR 的标准落地流程

## 0. 背景

当前 SDD Plugin 已经存在通用 DR 模板：

```text
skills/dr/references/dr.md.tmpl
```

现有模板能够记录 DR 的基本状态、tag、关闭原因、影响资产、背景、决策、影响和落地方式。

但现有工作流已经明确区分两类 DR：

```text
code-class DR: fix | feat | chg | arch
document-class DR: spec | doc | typo
```

两类 DR 的后续流程不同：

- code-class DR 会影响代码实现，必须生成 Implementation Plan，并通过 `/sdd:code` 执行后关闭。
- document-class DR 不影响代码实现，不生成 Implementation Plan，不执行 `/sdd:code`，由文档修订流程关闭。

当前模板没有显式表达 DR class、是否需要修改 spec、是否需要 plan、是否需要 code，因此 Agent 和用户只能从 tag 隐式推断后续流程。

V0.2.0 需要让 DR 模板直接承载这些流程判定信息。

## 1. 设计目标

V0.2.0 的 DR 模板设计目标是：

1. 明确区分 code-class DR 与 document-class DR。
2. 显式记录该 DR 是否需要修改 spec、是否需要 plan、是否需要 code。
3. 支持“同时修改 spec 和代码”的代码类 DR 流程。
4. 支持“只修代码且符合现有 spec”的 fix DR 流程。
5. 支持“只改文档表达，不改变行为和代码”的文档类 DR 流程。
6. 降低 Agent 仅靠 tag 推断流程的歧义。
7. 保持一个主模板，避免过早拆分多个模板文件。

## 2. 不在范围

V0.2.0 的本设计不要求实现：

- 集中状态仓库。
- 机器级状态图解析。
- Hook 对 DR 字段的完整语义校验。
- 多版本并行。
- 对历史 DR 文件的强制迁移。

历史 DR 可以继续保留旧格式。新模板只约束 V0.2.0 之后新建的 DR。

## 3. DR 分类模型

### 3.1 code-class DR

code-class DR 适用于会影响代码实现的变更。

包含 tag：

```text
fix | feat | chg | arch
```

code-class DR 的基本规则：

- 必须先从 `drafting` 切换到 `accepted`。
- 必须生成 Implementation Plan。
- 必须通过 `/sdd:code` 执行。
- 只有关联 plan 完成并通过 verification 后，才能关闭为 `closed`。
- 关闭时 `closed_reason` 必须为 `committed`。

### 3.2 document-class DR

document-class DR 适用于只影响文档表达、不改变系统行为、不影响代码实现的变更。

包含 tag：

```text
spec | doc | typo
```

document-class DR 的基本规则：

- 必须先从 `drafting` 切换到 `accepted`。
- 不生成 Implementation Plan。
- 不执行 `/sdd:code`。
- 文档修订完成后关闭。
- 关闭时 `closed_reason` 应说明文档修订结果，例如 `document-updated`。

## 4. 新 DR 模板

V0.2.0 继续使用一个 DR 模板文件：

```text
skills/dr/references/dr.md.tmpl
```

模板内容应调整为：

```markdown
# DR-<tag>-NNNN：<标题>

- 状态：drafting
- class：code | document
- tag：fix | feat | chg | arch | spec | doc | typo
- 日期：YYYY-MM-DD
- spec_change：yes | no | maybe
- plan_required：yes | no
- code_required：yes | no
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

## 契约影响

## 实现影响

## 文档影响

## 落地方式

## 验证方式
```

## 5. 字段语义

### 5.1 `class`

`class` 表示 DR 的流程类别。

允许值：

```text
code | document
```

规则：

- `fix`、`feat`、`chg`、`arch` 必须是 `code`。
- `spec`、`doc`、`typo` 必须是 `document`。

### 5.2 `spec_change`

`spec_change` 表示该 DR 是否需要修改 Functional Specification 或相关规格文档。

允许值：

```text
yes | no | maybe
```

含义：

- `yes`：必须修改 spec 或对应规格文档。
- `no`：不修改 spec，代码或文档变更应符合现有契约。
- `maybe`：需要 Agent 根据影响范围判断，并在 DR 正文中说明。

### 5.3 `plan_required`

`plan_required` 表示该 DR 是否必须生成 Implementation Plan。

允许值：

```text
yes | no
```

规则：

- code-class DR 必须为 `yes`。
- document-class DR 必须为 `no`。

### 5.4 `code_required`

`code_required` 表示该 DR 是否需要执行代码变更。

允许值：

```text
yes | no
```

规则：

- code-class DR 必须为 `yes`。
- document-class DR 必须为 `no`。

## 6. tag 默认推导规则

`/sdd:dr <tag> <title>` 创建 DR 时，应根据 tag 自动填充默认字段。

| tag | class | spec_change | plan_required | code_required | 说明 |
| --- | --- | --- | --- | --- | --- |
| `feat` | `code` | `yes` | `yes` | `yes` | 新增用户可见能力、API、流程、页面、命令 |
| `chg` | `code` | `yes` | `yes` | `yes` | 修改或删除现有功能行为、规则、输出或验收标准 |
| `fix` | `code` | `no` | `yes` | `yes` | 修复实现偏离现有 spec，使代码回到既有契约 |
| `arch` | `code` | `maybe` | `yes` | `yes` | 调整架构、模块边界或技术结构，可能不改变用户行为 |
| `spec` | `document` | `yes` | `no` | `no` | 修改 Functional Specification 的表达或结构，但不改变代码实现 |
| `doc` | `document` | `maybe` | `no` | `no` | 修改非 spec 文档或说明性内容 |
| `typo` | `document` | `no` | `no` | `no` | 修复错字、格式或明显表述错误 |

Agent 可以在创建 DR 时调整 `spec_change`，但不得违反 `class`、`plan_required`、`code_required` 的强约束。

## 7. 标准流程

### 7.1 改 spec + 改代码

适用于新增功能、修改行为、删除功能、改变验收标准，或修复时发现 spec 本身也需要调整的场景。

```text
/sdd:dr feat|chg|arch|fix <title>
→ /sdd:dr accept <id>
→ /sdd:spec
   关联该 accepted code-class DR 修订 spec
   spec: draft → approved
   DR 保持 accepted
→ /sdd:plan <id>
→ /sdd:code <NNN|id>
   plan: coding → done
   DR: accepted → closed
   closed_reason: committed
```

规则：

- 这类 DR 虽然会修改 spec，但仍然是 code-class DR。
- spec 修订完成后不得关闭 DR。
- DR 必须保持 `accepted`，继续进入 plan/code。

### 7.2 只修代码，spec 不变

适用于 Agent 识别到实现偏离现有 spec，例如上一个 plan 实现有问题，但需求契约本身正确的场景。

```text
/sdd:dr fix <title>
→ /sdd:dr accept <id>
→ /sdd:plan <id>
→ /sdd:code <NNN|id>
   plan: coding → done
   DR: accepted → closed
   closed_reason: committed
```

规则：

- 不修改 spec。
- 必须新建或使用尚处于 `drafting` 的 fix DR。
- 不重新打开已经完成的旧 plan。
- 不重新 accept 已经 `closed` 的旧 DR。
- `/sdd:plan` 应生成新的增量 Implementation Plan。

### 7.3 只改文档，不改行为、不改代码

适用于只澄清表达、修正文档结构、修复错字，且不改变系统行为和代码实现的场景。

```text
/sdd:dr spec|doc|typo <title>
→ /sdd:dr accept <id>
→ /sdd:spec 或对应文档 Skill
→ DR: accepted → closed
```

规则：

- 不生成 Implementation Plan。
- 不执行 `/sdd:code`。
- 若文档修订过程中发现会影响代码实现，必须停止 document-class 流程，改为创建 code-class DR。

## 8. Skill 行为要求

### 8.1 `/sdd:dr`

`/sdd:dr <tag> <title>` 创建 DR 时必须：

1. 根据 tag 填充 `class`、`spec_change`、`plan_required`、`code_required`。
2. 使用 V0.2.0 DR 模板。
3. 在输出中提示下一步：
   - code-class DR：`/sdd:dr accept <id>`，然后 `/sdd:plan <id>`；如果 `spec_change` 为 `yes` 或 `maybe`，提示先评估是否运行 `/sdd:spec`。
   - document-class DR：`/sdd:dr accept <id>`，然后运行 `/sdd:spec` 或对应文档 Skill。

### 8.2 `/sdd:dr accept <id>`

接受 DR 时必须：

1. 要求 DR 状态为 `drafting`。
2. 将状态改为 `accepted`。
3. 读取 `class`、`spec_change`、`plan_required`、`code_required`。
4. 输出下一步：
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: maybe`：要求 Agent 说明是否需要修订 spec；如果需要，先 `/sdd:spec`，否则 `/sdd:plan <id>`。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan`。

### 8.3 `/sdd:spec`

`/sdd:spec` 必须支持两类关联 DR：

1. accepted document-class DR。
2. accepted code-class DR 且 `spec_change` 为 `yes` 或经判断需要修改 spec。

当关联 code-class DR 修订 spec 时：

- spec 可以从 `draft` 切换到 `approved`。
- code-class DR 必须保持 `accepted`。
- 不得因为 spec 修订完成而关闭 code-class DR。
- 输出下一步应指向 `/sdd:plan <id>`。

当关联 document-class DR 修订文档时：

- 文档修订完成后可以关闭 document-class DR。
- 不得输出 `/sdd:plan` 或 `/sdd:code` 作为下一步。

### 8.4 `/sdd:plan`

`/sdd:plan <work-item>` 必须：

1. 接受 code-class DR id：`fix|feat|chg|arch-NNNN-<slug>`。
2. 拒绝 document-class DR id：`spec|doc|typo-NNNN-<slug>`。
3. 要求 code-class DR 状态为 `accepted`。
4. 要求 `plan_required: yes`。
5. 生成新的增量 Implementation Plan。

### 8.5 `/sdd:code`

`/sdd:code <NNN|id>` 必须：

1. 要求 plan 状态为 `planned` 或 `coding`。
2. 如果 plan 关联 code-class DR，要求 DR 状态为 `accepted`。
3. 执行实现并运行 verification。
4. 成功后将 plan 状态改为 `done`。
5. 成功后将关联 DR 改为 `closed`。
6. 设置 `closed_reason: committed` 和 `closed_at`。
7. 如果实现或 verification 失败，plan 保持 `coding`，DR 保持 `accepted`。

## 9. 验收标准

V0.2.0 实现完成后，应满足以下验收标准：

1. 新建 DR 文件包含 `class`、`spec_change`、`plan_required`、`code_required` 字段。
2. `feat`、`chg`、`fix`、`arch` 自动生成 code-class DR。
3. `spec`、`doc`、`typo` 自动生成 document-class DR。
4. `/sdd:plan` 拒绝 document-class DR。
5. `/sdd:spec` 能区分 document-class DR 和需要修订 spec 的 code-class DR。
6. code-class DR 在 spec 修订完成后仍保持 `accepted`。
7. code-class DR 只能在 `/sdd:code` 成功并通过 verification 后关闭。
8. document-class DR 不进入 `/sdd:plan` 和 `/sdd:code`。
9. “只修代码且符合现有 spec”的场景使用 `fix` DR，并生成新的增量 plan。
10. 旧格式 DR 不要求自动迁移，但新建 DR 必须使用 V0.2.0 模板。

## 10. 示例

### 10.1 只修代码且符合现有 spec

```markdown
# DR-fix-0003：修复 plan 执行后状态未正确关闭

- 状态：drafting
- class：code
- tag：fix
- 日期：2026-07-13
- spec_change：no
- plan_required：yes
- code_required：yes
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |
| docs/v0.2.0/specs/spec.md | DR 关闭规则 |

## 背景

当前实现未按既有 spec 在 `/sdd:code` 成功后关闭关联 DR。

## 决策

修复代码实现，使其重新符合既有 spec。

## 契约影响

无。现有 spec 正确。

## 实现影响

需要修改 `/sdd:code` 的执行逻辑。

## 文档影响

无。

## 落地方式

创建新的增量 Implementation Plan，并通过 `/sdd:code` 执行。

## 验证方式

执行相关测试，并确认 plan 变为 `done`、DR 变为 `closed`、`closed_reason` 为 `committed`。
```

### 10.2 同时修改 spec 和代码

```markdown
# DR-chg-0004：调整 DR 模板以显式区分流程类别

- 状态：drafting
- class：code
- tag：chg
- 日期：2026-07-13
- spec_change：yes
- plan_required：yes
- code_required：yes
- closed_reason: null
- closed_at: null
- supersedes: []
- superseded_by: null
- dismissed_reason: null

## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |
| skills/dr/references/dr.md.tmpl | DR 模板 |
| skills/dr/SKILL.md | DR 创建与接受流程 |
| skills/spec/SKILL.md | 关联 code-class DR 修订 spec |

## 背景

现有 DR 模板没有显式记录 DR class 和后续流程要求。

## 决策

在 DR 模板中增加 `class`、`spec_change`、`plan_required`、`code_required` 字段。

## 契约影响

需要更新 SDD Plugin 规格，明确新字段和流程判定规则。

## 实现影响

需要更新 DR Skill、Spec Skill、Plan Skill 的行为说明或实现。

## 文档影响

需要修订 spec 与相关 Skill 文档。

## 落地方式

先通过 `/sdd:spec` 更新规格，再通过 `/sdd:plan` 生成实现计划，最后通过 `/sdd:code` 落地。

## 验证方式

新建不同 tag 的 DR，确认默认字段与后续流程提示符合本规格。
```
