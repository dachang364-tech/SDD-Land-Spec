# SDD Plugin 设计规格：Triage Skill

- 日期：2026-07-13
- 类型：Design Spec
- 目标：定义 `/sdd:triage` 用户疑问分诊 skill，让 Agent 在实现后、验收中、测试中或继续讨论时先判断问题来源、推荐后续路径，并保留用户最终选择权

## 0. 背景

DR Advanced 规定用户在 `/sdd:code` 完成后提出的疑问，不应默认被当作代码 bug 处理。

这类疑问可能来自多个阶段：

- 代码实现偏离了 spec 或 plan。
- plan 本身遗漏、拆解错误或实现路径不合理。
- spec 表达不清、验收标准不足或契约缺失。
- 用户提出了新的需求或行为变更。
- 用户只是希望理解既有设计、plan 或代码行为。

如果 Agent 在缺少分诊的情况下直接创建 DR、修改 spec、修订 plan 或改代码，容易把解释请求误判为变更，也容易把 plan/spec 问题误修成代码补丁。

因此需要独立的 `/sdd:triage` skill，专门负责分析用户疑问、判断问题更可能属于哪个阶段、给出推荐路径和可选路径，并等待用户选择。

## 1. 设计目标

`/sdd:triage` 的目标是：

1. 在用户提出疑问后先做分诊，而不是直接进入 DR、spec、plan 或 code 流程。
2. 区分 code implementation issue、plan issue、spec issue、new requirement / change request、explanation only 和 unclear, needs user choice。
3. 给出置信度、已读取依据、简短原因、推荐路径和可选路径。
4. 支持默认轻量分诊和 `--deep` 深度分诊。
5. 使用最小上下文和渐进式读取，避免默认扫描整个 active version、全部 plan、全部 DR 或全量代码。
6. 明确 `/sdd:triage` 只推荐路线，不创建 DR、不修改文档、不修改代码、不改变状态。
7. 保留用户最终选择权。

## 2. 非目标

本规格不要求实现：

- 自动创建 DR。
- 自动接受 DR。
- 自动修改 spec。
- 自动修改 plan。
- 自动修改 code。
- 自动关闭 DR。
- 自动改变 plan 状态。
- 自动替用户选择后续处理路径。
- 一次性全量扫描 active version。
- 默认读取所有 `plans/*.md`、所有 `decisions/*.md` 或全部代码。
- 机器级因果证明或完整静态分析。
- 对历史 triage 结果建立集中状态库。

## 3. Skill 定位

`/sdd:triage` 是 DR Advanced 的前置分诊 skill。

它不替代 `/sdd:dr`、`/sdd:spec`、`/sdd:plan`、`/sdd:code`。

职责边界：

- `/sdd:triage` 负责判断路线。
- `/sdd:dr` 负责创建或接受 DR。
- `/sdd:spec` 负责修订 Functional Spec。
- `/sdd:plan` 负责生成或修订 Implementation Plan。
- `/sdd:code` 负责执行代码实现和 verification。

`/sdd:triage` 的输出是建议，不是状态变更。

## 4. 适用场景

`/sdd:triage` 适用于用户在实现后、验收中、测试中或继续讨论时提出疑问，例如：

- “这个是不是有问题？”
- “为什么这里这样实现？”
- “这里是不是应该改？”
- “这个行为和我预期不一样。”
- “这个 plan 当时是不是漏了什么？”
- “spec 里是不是应该说明这个边界？”

如果用户已经明确选择了后续路径，例如明确要求创建 DR、修改 spec、修订 plan 或执行 code，则可以直接进入对应 skill；但 Agent 仍应在发现问题来源不明确时建议先运行 `/sdd:triage`。

## 5. Preconditions

`/sdd:triage` 执行前应：

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`。
2. Resolve the unique active version directory。
3. 确认用户疑问的最小定位信息，例如功能名、小节号、DR ID、plan 文件名、错误现象或相关文件路径。
4. 读取 active version 的最小结构信息，例如 spec、plans、decisions 的文件名列表。
5. 按候选范围读取相关 `specs/spec.md` 小节。
6. 当用户疑问引用 plan、实现过程或已完成工作时，读取相关 `plans/*.md`。
7. 当用户疑问引用 DR、决策或由 DR 引入的行为时，读取相关 `decisions/*.md`。
8. 只有需要判断当前实现是否符合 spec 和 plan 时，才读取相关代码。
9. Do not modify files。

如果用户疑问缺少足够定位信息，`/sdd:triage` 应先要求用户补充上下文，或输出低置信度分诊并说明缺失信息。

## 6. Hard Rules

`/sdd:triage` 必须遵守：

- 不创建 DR。
- 不接受 DR。
- 不修改 spec。
- 不修改 plan。
- 不修改 code。
- 不关闭 DR。
- 不改变 plan 状态。
- 不替用户选择后续路径。
- 必须向用户说明推荐路径和可选路径。
- 必须等待用户确认后，才能建议进入其他 skill。

## 7. Token 控制与渐进式读取

`/sdd:triage` 可能读取 spec、plan、DR、代码和对话上下文，因此必须按最小上下文原则执行。

硬规则：

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `plans/*.md`。
- 不得默认读取所有 `decisions/*.md`。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。
- 必须优先使用用户提供的功能名、小节号、DR ID、plan 文件名、错误现象或相关文件路径来缩小范围。

推荐读取顺序：

1. 先理解用户疑问，必要时要求用户补充定位信息。
2. 读取 active version 的最小结构信息，例如 spec、plans、decisions 的文件名列表。
3. 只读取相关 spec 小节，而不是整份 spec。
4. 只读取相关 plan，而不是全部 plans。
5. 只读取相关 DR，而不是全部 decisions。
6. 只有当需要判断实现是否偏离 spec / plan 时，才读取相关代码。
7. 如果证据不足，先输出低置信度分诊，并说明还需要读取哪些上下文。

`/sdd:triage` 支持两种深度：

```text
/sdd:triage
```

默认轻量分诊。只读取必要文档，不扫全量代码。

```text
/sdd:triage --deep
```

深度分诊。允许读取更多相关 plan、DR 或代码，但仍必须按候选范围渐进读取，不允许无界扫描。

## 8. 分诊原则

收到用户疑问后，ClaudeCode 应按以下顺序分析：

1. 现有 spec 是否已经明确描述期望行为。
2. 现有 plan 是否正确覆盖 spec 中的相关行为。
3. 当前代码实现是否符合 plan 和 spec。
4. 用户疑问是否暴露了 spec 缺失、歧义或验收标准不足。
5. 用户是否实际提出了新的需求或行为变更。
6. 该问题是否只是对现有设计、plan 或代码行为的解释请求。

## 9. Classification

`/sdd:triage` 应输出一个分类：

```text
code implementation issue
plan issue
spec issue
new requirement / change request
explanation only
unclear, needs user choice
```

分类含义：

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 基本明确，但 plan 拆解、实现策略、任务边界或验收安排有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

如果证据不足，ClaudeCode 应明确说明不确定点，并给出需要用户选择的后续路径。

## 10. Output Format

`/sdd:triage` 应使用以下输出结构：

```text
我的判断：这是 <分类>。
置信度：low | medium | high
已读取依据：
- <spec 小节或文件>
- <plan 文件，如有>
- <DR 文件，如有>
- <代码文件，如有>
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

输出要求：

- 置信度必须出现。
- 已读取依据必须出现。
- 推荐路径必须是建议，不得替用户执行。
- 可选路径必须给出用户可以选择的后续流程。
- 如果判断为 `explanation only`，推荐路径应为 `explain only -> no DR`。

## 11. 分诊路径

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且可轻量修复 | `fix DR -> code -> verification` |
| B | 代码实现问题，但需要 plan | `fix DR -> plan -> code -> verification` |
| C | plan 问题 | `fix DR -> revised plan -> code -> verification` |
| D | spec 问题 | `fix/spec DR -> spec -> plan -> code -> verification` |
| E | 新需求或行为变更 | `new feat/chg DR -> spec -> plan -> code -> verification` |
| F | 仅解释现有行为 | `explain only -> no DR` |

路径选择规则：

- 路径 A 只适用于 spec 已明确、plan 没有明显错误、代码实现局部偏离、修复范围小且风险低的情况。
- 路径 B 适用于代码实现问题影响范围较大、需要拆解步骤或存在多种修复方案的情况。
- 路径 C 适用于 spec 正确但 plan 漏项、任务拆解错误或验收安排不足的情况。
- 路径 D 适用于 spec 缺失、歧义或验收标准不足的情况。
- 路径 E 适用于用户实际提出新能力、行为变更、删除功能或改变验收标准的情况。
- 路径 F 适用于当前行为符合 spec、plan 和代码实现，只需要解释的情况。

## 12. 原 DR 的处理

原 feature/chg/arch DR 表达原始变更决策，不应承载后续发现的独立问题。

规则：

- 如果原 DR 已经完成 `/sdd:code` 并进入验收或后续讨论阶段，后续问题默认使用新的 DR 表达。
- 如果原 DR 已关闭，不重新打开原 DR。
- 如果原 DR 尚未完成实现，且问题仍属于同一轮 plan/code 执行范围，可以继续在原 DR 的当前 plan/code 流程中处理，但仍应向用户说明这个选择。
- 新 DR 可以在内容中引用原 DR，但不通过 `supersedes` 表达普通 bug 修复关系，除非它确实替代了原决策。

## 13. 对 skill 和测试的预期影响

后续实现本规格时，预计需要检查或修改：

```text
skills/triage/SKILL.md
skills/dr/SKILL.md
skills/spec/SKILL.md
skills/plan/SKILL.md
skills/code/SKILL.md
tests/test-skill-contracts.sh
```

预期变化：

1. 新增 `skills/triage/SKILL.md`。
2. `/sdd:triage` 只输出分类、置信度、已读取依据、原因、推荐路径和可选路径。
3. `/sdd:triage` 支持默认轻量分诊和 `--deep` 深度分诊。
4. `/sdd:triage` 使用最小上下文和渐进式读取。
5. `/sdd:triage` 不创建 DR、不修改文档、不修改代码、不改变任何状态。
6. `/sdd:dr`、`/sdd:spec`、`/sdd:plan`、`/sdd:code` 的提示文案应能与 triage 推荐路径衔接。
7. contract tests 覆盖 triage 的职责边界、输出格式、分类集合、token 控制规则和禁止修改状态规则。

## 14. 验收标准

Triage Skill 实现完成后，应满足以下验收标准：

1. 存在 `skills/triage/SKILL.md`。
2. `/sdd:triage` 能判断用户疑问属于 `code implementation issue`、`plan issue`、`spec issue`、`new requirement / change request`、`explanation only` 或 `unclear, needs user choice`。
3. `/sdd:triage` 输出置信度和已读取依据。
4. `/sdd:triage` 输出推荐路径和可选路径。
5. `/sdd:triage` 明确等待用户选择。
6. `/sdd:triage` 不创建 DR、不接受 DR、不关闭 DR。
7. `/sdd:triage` 不修改 spec、不修改 plan、不修改 code。
8. `/sdd:triage` 不改变 plan 状态。
9. `/sdd:triage` 默认使用轻量分诊，不默认扫描整个 active version。
10. `/sdd:triage` 不默认读取全部 `plans/*.md`、全部 `decisions/*.md` 或全部代码。
11. `/sdd:triage --deep` 可以读取更多相关上下文，但仍必须按候选范围渐进读取。
12. 如果证据不足，`/sdd:triage` 输出低置信度分诊，并说明缺失依据或需要用户选择的路径。
13. 对代码实现小问题，`/sdd:triage` 可以推荐轻量 fix 路径 `fix DR -> code -> verification`。
14. 对 plan、spec、新需求和解释请求，`/sdd:triage` 能推荐对应路径，而不是默认改代码。
15. ClaudeCode 只提供推荐和可选路径，最终由用户选择是否创建 DR、修改 spec、修订 plan 或改代码。
