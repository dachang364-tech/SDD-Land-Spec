# SDD Plugin 设计规格：DR Advanced

- 日期：2026-07-13
- 状态：draft
- 类型：Design Spec
- 取代：`2026-07-13-dr-advance-spec.md`、`2026-07-13-dr-advanced-followup-spec.md`
- 目标：定义 DR Advanced 的完整规则，包括 DR 分类模板、字段语义、标准落地流程、跨文档 Markdown 链接、用户疑问分诊、轻量 fix DR、以及用户最终选择权

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

- code-class DR 会影响代码实现，通常需要 Implementation Plan，并通过 `/sdd:code` 执行后关闭。
- document-class DR 不影响代码实现，不生成 Implementation Plan，不执行 `/sdd:code`，由文档修订流程关闭。

DR Advanced 需要让 DR 模板直接承载流程判定信息，并补齐真实使用中发现的后续规则：

1. Functional Spec、Implementation Plan、DR 之间互相引用时，应该能直接跳转到对应文档文件。
2. `/sdd:code` 完成后，用户提出的疑问不一定都是代码 bug，也可能来自 plan、spec、新需求或只是解释请求。
3. 对于很小的实现 bug，不应强制走完整 `fix DR -> plan -> code` 流程。
4. ClaudeCode 应提供分析和推荐，但后续路线必须由用户确认。

## 1. 设计目标

DR Advanced 的目标是：

1. 明确区分 code-class DR 与 document-class DR。
2. 显式记录 DR 是否需要修改 spec、是否需要 plan、是否需要 code。
3. 支持“同时修改 spec 和代码”的代码类 DR 流程。
4. 支持“只修代码且符合现有 spec”的 fix DR 流程。
5. 支持“只改文档表达，不改变行为和代码”的文档类 DR 流程。
6. 支持轻量 fix DR：简单实现 bug 可以不生成 Implementation Plan。
7. 让 spec、plan、DR 之间的跨文档引用可以直接链接到目标文件。
8. 在用户提出疑问后，先判断问题属于 code、plan、spec、新需求还是解释请求。
9. 明确 ClaudeCode 只能推荐后续路径，最终由用户选择。
10. 降低 Agent 仅靠 tag 推断流程的歧义。
11. 保持一个主 DR 模板，避免过早拆分多个模板文件。

## 2. 非目标

本规格不要求实现：

- 集中状态仓库或 DR 数据库。
- 机器级状态图解析。
- Hook 对 DR 字段的完整语义校验。
- 多版本并行。
- 对历史 DR 文件的强制迁移。
- 将 DR markdown 文件全文嵌入 spec 或 plan。
- 引入 `!INCLUDE`、transclusion、wiki link 等非标准 Markdown 语法。
- 自动修复已经失效的 DR 链接。
- 自动替用户选择后续处理路径。
- 对所有轻量 fix 强制生成 Implementation Plan。

历史 DR 可以继续保留旧格式。新模板只约束 DR Advanced 落地后新建的 DR。

## 3. DR 分类模型

### 3.1 code-class DR

code-class DR 适用于会影响代码实现的变更。

包含 tag：

```text
fix | feat | chg | arch
```

基本规则：

- 必须先从 `drafting` 切换到 `accepted`。
- 必须通过 `/sdd:code` 执行。
- 通常必须生成 Implementation Plan。
- 只有关联 plan 完成，或轻量 fix 通过 verification 后，才能关闭为 `closed`。
- 关闭时 `closed_reason` 必须为 `committed`。

### 3.2 document-class DR

document-class DR 适用于只影响文档表达、不改变系统行为、不影响代码实现的变更。

包含 tag：

```text
spec | doc | typo
```

基本规则：

- 必须先从 `drafting` 切换到 `accepted`。
- 不生成 Implementation Plan。
- 不执行 `/sdd:code`。
- 文档修订完成后关闭。
- 关闭时 `closed_reason` 应说明文档修订结果，例如 `document-updated`。

## 4. DR 模板

DR Advanced 继续使用一个 DR 模板文件：

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

默认规则：

- code-class DR 默认为 `yes`。
- document-class DR 必须为 `no`。
- 简单实现 bug 可以由用户选择轻量 fix 流程，将 `plan_required` 设为 `no`。

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

Agent 可以在创建 DR 时调整 `spec_change` 和 `plan_required`，但不得违反 `class` 和 `code_required` 的强约束。

## 7. 标准流程

### 7.1 改 spec + 改代码

适用于新增功能、修改行为、删除功能、改变验收标准，或修复时发现 spec 本身也需要调整的场景。

```text
/sdd:dr feat|chg|arch|fix <title>
-> /sdd:dr accept <id>
-> /sdd:spec
   关联该 accepted code-class DR 修订 spec
   spec: draft -> approved
   DR 保持 accepted
-> /sdd:plan <id>
-> /sdd:code <NNN|id>
   plan: coding -> done
   DR: accepted -> closed
   closed_reason: committed
```

规则：

- 这类 DR 虽然会修改 spec，但仍然是 code-class DR。
- spec 修订完成后不得关闭 DR。
- DR 必须保持 `accepted`，继续进入 plan/code。

### 7.2 只修代码，spec 不变，需要 plan

适用于实现偏离现有 spec，且修复影响范围较大、需要拆解步骤或存在多种修复方案的场景。

```text
/sdd:dr fix <title>
-> /sdd:dr accept <id>
-> /sdd:plan <id>
-> /sdd:code <NNN|id>
   plan: coding -> done
   DR: accepted -> closed
   closed_reason: committed
```

规则：

- 不修改 spec。
- 必须新建或使用尚处于 `drafting` 的 fix DR。
- 不重新打开已经完成的旧 plan。
- 不重新 accept 已经 `closed` 的旧 DR。
- `/sdd:plan` 应生成新的增量 Implementation Plan。

### 7.3 只修代码，spec 不变，轻量 fix

适用于简单实现 bug：spec 已明确、plan 没有明显错误、代码实现局部偏离、修复范围小且风险低。

```text
/sdd:dr fix <title>
-> /sdd:dr accept <id>
-> /sdd:code <id>
   DR: accepted -> closed
   closed_reason: committed
```

DR 字段建议：

```markdown
- class：code
- tag：fix
- spec_change：no
- plan_required：no
- code_required：yes
```

规则：

- 即使只改几行代码，也应保留轻量 fix DR，以便记录问题来源、修复原因和验证结果。
- 轻量 fix 不生成 Implementation Plan，但必须有明确 verification。
- 如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不应使用轻量 fix。

### 7.4 只改文档，不改行为、不改代码

适用于只澄清表达、修正文档结构、修复错字，且不改变系统行为和代码实现的场景。

```text
/sdd:dr spec|doc|typo <title>
-> /sdd:dr accept <id>
-> /sdd:spec 或对应文档 Skill
-> DR: accepted -> closed
```

规则：

- 不生成 Implementation Plan。
- 不执行 `/sdd:code`。
- 若文档修订过程中发现会影响代码实现，必须停止 document-class 流程，改为创建 code-class DR。

## 8. 跨文档 Markdown 链接

DR Advanced 流程中的跨文档引用应统一使用标准 Markdown 链接：

```markdown
[<stable-text>](<relative-path>)
```

适用范围：

- spec 引用 DR。
- plan 引用 DR。
- DR 引用 spec。
- DR 引用 plan。
- DR 引用其他 DR。
- 新 fix/chg/feat DR 引用原始 DR 或历史 plan。

链接文本应优先使用稳定标识：

- 引用 DR 时，使用 DR ID。
- 引用 plan 时，使用 plan 文件名或 plan ID。
- 引用 spec 时，使用 `spec.md`。

章节号、章节标题、说明文字可以保留为普通文本，不强制做 Markdown anchor 链接。

### 8.1 spec 引用 DR

Functional Spec 的 `关联 DR` 表格中，`DR` 列应使用 Markdown 链接：

```markdown
| DR | tag | class | spec_change | 状态 | 关联小节 |
| --- | ---- | ---- | ---- | ---- | ---- |
| [feat-0001-dark-mode-particle-background](../decisions/feat-0001-dark-mode-particle-background.md) | feat | code | yes | accepted | §4.6 装饰背景层 |
```

spec 正文小节可以写来源声明：

```markdown
来源 DR：[feat-0001-dark-mode-particle-background](../decisions/feat-0001-dark-mode-particle-background.md)。
```

### 8.2 plan 引用 DR

Implementation Plan 中记录关联 DR 时，应使用同样的链接规则。

```markdown
- 关联 DR：[feat-0001-dark-mode-particle-background](../decisions/feat-0001-dark-mode-particle-background.md)
```

### 8.3 DR 影响资产表

DR 的 `## 影响资产` 表引用 spec、plan 或其他 DR 时，应使用 Markdown 链接指向目标文件。

```markdown
## 影响资产
| 资产 | 章节 / ID |
| ---- | --------- |
| spec | [spec.md](../specs/spec.md) §4.6 装饰背景层 |
| plan | [001-dark-mode-particle-background.md](../plans/001-dark-mode-particle-background.md) |
| decision | [feat-0001-dark-mode-particle-background](./feat-0001-dark-mode-particle-background.md) |
```

说明：

- DR 引用同目录下的其他 DR 时，可以使用 `./<dr-file>.md`。
- DR 引用 spec 时，使用 `../specs/spec.md`。
- DR 引用 plan 时，使用 `../plans/<plan-file>.md`。

### 8.4 不强制 anchor 链接

跨文档引用应优先保证文件级链接稳定。章节号和标题可以放在链接后作为普通文本。

推荐：

```markdown
[spec.md](../specs/spec.md) §4.6 装饰背景层
```

不强制：

```markdown
[spec.md §4.6](../specs/spec.md#46-装饰背景层暗黑模式粒子背景)
```

原因：Markdown anchor 受渲染器、中文标题、标点、编号变化影响，稳定性弱于文件级相对链接。

## 9. 用户疑问的分诊与后续流程选择

当 `/sdd:code <dr-id>` 按 plan 完成实现后，用户在验收、测试或继续与 ClaudeCode 讨论时，可能提出新的疑问。该疑问不一定都是代码 bug，也可能来自 plan 错误、spec 缺失、原始需求变化，或只是用户需要解释现有行为。

本版本需要解决的问题是：ClaudeCode 应先帮助用户分析疑问属于哪个阶段的问题，再给出推荐流程；最终选择权属于用户，ClaudeCode 不应直接替用户决定后续路线。

### 9.1 分诊原则

收到用户疑问后，ClaudeCode 应按以下顺序分析：

1. 现有 spec 是否已经明确描述期望行为。
2. 现有 plan 是否正确覆盖 spec 中的相关行为。
3. 当前代码实现是否符合 plan 和 spec。
4. 用户疑问是否暴露了 spec 缺失、歧义或验收标准不足。
5. 用户是否实际提出了新的需求或行为变更。
6. 该问题是否只是对现有设计、plan 或代码行为的解释请求。

ClaudeCode 应输出一个简短判断，说明疑问更可能属于：

```text
code implementation issue
plan issue
spec issue
new requirement / change request
explanation only
unclear, needs user choice
```

如果证据不足，ClaudeCode 应明确说明不确定点，并给出需要用户选择的后续路径。

### 9.2 ClaudeCode 只能推荐，不能替用户选择

ClaudeCode 可以推荐最合适的路径，但必须让用户确认。

推荐输出结构：

```text
我的判断：这是 <分类>。
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

除非用户明确授权，否则 ClaudeCode 不应直接创建 DR、修改 spec、修改 plan 或改代码。

### 9.3 分诊路径

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且可轻量修复 | `fix DR -> code -> verification` |
| B | 代码实现问题，但需要 plan | `fix DR -> plan -> code -> verification` |
| C | plan 问题 | `fix DR -> revised plan -> code -> verification` |
| D | spec 问题 | `fix/spec DR -> spec -> plan -> code -> verification` |
| E | 新需求或行为变更 | `new feat/chg DR -> spec -> plan -> code -> verification` |
| F | 仅解释现有行为 | `explain only -> no DR` |

### 9.4 原 DR 的处理

原 feature/chg/arch DR 表达原始变更决策，不应承载后续发现的独立问题。

规则：

- 如果原 DR 已经完成 `/sdd:code` 并进入验收或后续讨论阶段，后续问题默认使用新的 DR 表达。
- 如果原 DR 已关闭，不重新打开原 DR。
- 如果原 DR 尚未完成实现，且问题仍属于同一轮 plan/code 执行范围，可以继续在原 DR 的当前 plan/code 流程中处理，但仍应向用户说明这个选择。
- 新 DR 可以在内容中引用原 DR，但不通过 `supersedes` 表达普通 bug 修复关系，除非它确实替代了原决策。

## 10. Skill 行为要求

### 10.1 `/sdd:dr`

`/sdd:dr <tag> <title>` 创建 DR 时必须：

1. 根据 tag 填充 `class`、`spec_change`、`plan_required`、`code_required`。
2. 使用 DR Advanced 模板。
3. 在输出中提示下一步。
4. 在写入 `影响资产` 或引用其他 DR 时，使用 Markdown 链接格式。

### 10.2 `/sdd:dr accept <id>`

接受 DR 时必须：

1. 要求 DR 状态为 `drafting`。
2. 将状态改为 `accepted`。
3. 读取 `class`、`spec_change`、`plan_required`、`code_required`。
4. 输出下一步：
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 决定 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`：根据 `plan_required` 决定 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: maybe`：要求 Agent 说明是否需要修订 spec。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan`。

### 10.3 `/sdd:spec`

`/sdd:spec` 必须支持两类关联 DR：

1. accepted document-class DR。
2. accepted code-class DR 且 `spec_change` 为 `yes` 或经判断需要修改 spec。

当关联 code-class DR 修订 spec 时：

- spec 可以从 `draft` 切换到 `approved`。
- code-class DR 必须保持 `accepted`。
- 不得因为 spec 修订完成而关闭 code-class DR。
- 输出下一步应根据 `plan_required` 指向 `/sdd:plan <id>` 或 `/sdd:code <id>`。
- 写入 `关联 DR` 表格时，应使用 Markdown 链接格式。

当关联 document-class DR 修订文档时：

- 文档修订完成后可以关闭 document-class DR。
- 不得输出 `/sdd:plan` 或 `/sdd:code` 作为下一步。

### 10.4 `/sdd:plan`

`/sdd:plan <work-item>` 必须：

1. 接受 code-class DR id：`fix|feat|chg|arch-NNNN-<slug>`。
2. 拒绝 document-class DR id：`spec|doc|typo-NNNN-<slug>`。
3. 要求 code-class DR 状态为 `accepted`。
4. 要求 `plan_required: yes`。
5. 生成新的增量 Implementation Plan。
6. 写入 `关联 DR` 时，使用 Markdown 链接格式。

### 10.5 `/sdd:code`

`/sdd:code <NNN|id>` 必须：

1. 支持执行 plan，也支持执行 `plan_required: no` 的轻量 fix DR。
2. 如果输入 plan，要求 plan 状态为 `planned` 或 `coding`。
3. 如果 plan 关联 code-class DR，要求 DR 状态为 `accepted`。
4. 如果输入轻量 fix DR，要求 DR 状态为 `accepted`、`plan_required: no`、`code_required: yes`。
5. 执行实现并运行 verification。
6. 成功后将 plan 状态改为 `done`，如果本次执行有 plan。
7. 成功后将关联 DR 改为 `closed`。
8. 设置 `closed_reason: committed` 和 `closed_at`。
9. 如果实现或 verification 失败，plan 保持 `coding`，DR 保持 `accepted`。

## 11. 对模板和测试的预期影响

后续实现本规格时，预计需要检查或修改：

```text
skills/dr/SKILL.md
skills/dr/references/dr.md.tmpl
skills/spec/SKILL.md
skills/spec/references/spec.md.tmpl
skills/plan/SKILL.md
skills/plan/references/plan.md.tmpl
skills/code/SKILL.md
tests/test-skill-contracts.sh
```

预期变化：

1. DR 模板包含 `class`、`spec_change`、`plan_required`、`code_required`。
2. `/sdd:dr` 根据 tag 生成默认字段。
3. `/sdd:spec` 支持 document-class DR 与需要修订 spec 的 code-class DR。
4. `/sdd:plan` 拒绝 document-class DR，并要求 `plan_required: yes`。
5. `/sdd:code` 支持 plan 执行和轻量 fix DR 执行。
6. spec、plan、DR 中的跨文档引用使用 Markdown 链接格式。
7. contract tests 覆盖 DR 字段、流程分支、轻量 fix、跨文档链接规则。

## 12. 验收标准

DR Advanced 实现完成后，应满足以下验收标准：

1. 新建 DR 文件包含 `class`、`spec_change`、`plan_required`、`code_required` 字段。
2. `feat`、`chg`、`fix`、`arch` 自动生成 code-class DR。
3. `spec`、`doc`、`typo` 自动生成 document-class DR。
4. `/sdd:plan` 拒绝 document-class DR。
5. `/sdd:plan` 拒绝 `plan_required: no` 的 DR。
6. `/sdd:code` 支持 `plan_required: no` 的轻量 fix DR。
7. `/sdd:spec` 能区分 document-class DR 和需要修订 spec 的 code-class DR。
8. code-class DR 在 spec 修订完成后仍保持 `accepted`。
9. code-class DR 只能在 `/sdd:code` 成功并通过 verification 后关闭。
10. document-class DR 不进入 `/sdd:plan` 和 `/sdd:code`。
11. 新建或修订 spec 时，`关联 DR` 表格中的 DR 使用 Markdown 链接。
12. 新建或修订 plan 时，`关联 DR` 字段使用 Markdown 链接。
13. 新建或修订 DR 时，`影响资产` 表中的 spec、plan、decision 引用使用 Markdown 链接。
14. 跨文档链接目标使用相对路径，章节号和标题可以保留为普通文本。
15. 用户提出疑问后，ClaudeCode 先判断问题更可能属于 code、plan、spec、新需求或仅解释，再推荐后续路径。
16. ClaudeCode 只提供推荐和可选路径，最终由用户选择是否创建 DR、修改 spec、修订 plan 或改代码。
17. 旧格式 DR 不要求自动迁移，但新建 DR 必须使用 DR Advanced 模板。
