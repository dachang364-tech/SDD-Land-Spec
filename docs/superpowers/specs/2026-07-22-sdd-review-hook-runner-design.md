# SDD 文档 Review 触发重构设计

- 日期：2026-07-22
- 状态：draft
- 类型：Design Spec
- 目标：将受管文档的 review 权威触发点从 `PostToolUse Hook` 收回到各文档 Skill 与 `/sdd:review` 内部，形成“新建文档必须显式 review、修改已有文档不自动 review”的统一流程，并让 `/sdd:review` 成为唯一的 review 编排入口与用户回执层。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | review 对外入口 | [skills/review/SKILL.md](../../../skills/review/SKILL.md) | `/sdd:review` | 该 Skill 将从“手工入口 + Hook 配套层”收敛为“创建后必经 review 入口 + 修改后可选复审入口” |
| references | Spec Skill | [skills/spec/SKILL.md](../../../skills/spec/SKILL.md) | `/sdd:spec` | 该 Skill 在新建 spec 时必须显式触发 review，并在拿到结果后才允许进入审批讨论 |
| references | Plan Skill | [skills/plan/SKILL.md](../../../skills/plan/SKILL.md) | `/sdd:plan` | 该 Skill 在新建 plan 时必须显式触发 review，并在拿到结果后才允许推进状态 |
| references | Hook 行为 | [scripts/hooks/post-tool-use.sh](../../../scripts/hooks/post-tool-use.sh) | - | 当前版本由写后 Hook 统一触发 review，本设计将撤销这一职责 |
| references | Hook 注册 | [hooks/hooks.json](../../../hooks/hooks.json) | - | 需要同步删除 `PostToolUse` 注册及其 review 相关合同 |
| references | Skill 规范化约束 | [2026-07-21-sdd-skills-claude-code-normalization-design.md](./2026-07-21-sdd-skills-claude-code-normalization-design.md) | - | 本次属于 `skills/*/SKILL.md` 合同重构，必须遵守 `/skill-creator` 约束与现有能力边界 |

## 1. 背景

当前实现已经把自动 review 下沉到写后 Hook，并通过共享 runner 统一执行。这解决了“Skill 可能写完文档后忘记继续 review”的问题，但也引入了新的结构性问题；本次重构要把这些职责收回到 `/sdd:review` Skill：

1. Hook 只能观察单次 `Write/Edit`，无法可靠区分“新建文档完成”与“正在增量修改已有文档”。
2. 对 `spec`、`plan` 这类可能被多轮分段写入的文档，Hook 会对同一文档的中间态重复触发 review。
3. review 触发时机从“流程节点”退化成“文件事件”，导致 review 过早、过多，用户回执噪音增大。
4. 新建文档和修改文档在业务语义上本应区分对待，但 Hook 无法承载这种高上下文流程判断。

本设计要解决的是：**review 何时发生，必须由文档 Skill 基于 create/update 语义来决定，而不是由通用写后 Hook 基于文件事件来猜测。**

## 2. Goals

1. 对 `research / prd / dr / spec / plan` 统一建立 create/update 两态的 review 规则。
2. 新建文档时，必须显式执行 `/sdd:review`，未拿到有效结果不能继续后续流程。
3. 修改已有文档时，不自动执行 review，将是否复审的控制权交给用户。
4. `/sdd:review` 作为统一的 review 入口、唯一编排入口和用户回执层。
5. 移除 `PostToolUse Hook` 对受管文档自动触发 review 的权威职责，避免增量写入导致重复 review。
6. 删除独立 `review runner`，把原有校验、编排和回执职责收敛到 `/sdd:review` Skill。

## 3. Non-Goals

本次不纳入：

- 修改 `doc-reviewer` 的内部评分模型或 schema。
- 改变 `research / prd / dr / spec / plan` 的模板内容或标准内容。
- 改造 `PreToolUse` 的写前门控语义。
- 扩展 review 到非受管文档路径。
- 为“修改已有文档”增加新的半自动或定时 review 机制。
- 重新设计 `archive`、`code`、`new` 等非文档生成主流程的核心语义。

## 4. Core Design Principles

### 4.1 review 触发属于流程语义，不属于文件事件

是否执行 review，取决于“当前文档生命周期阶段”，而不是“刚发生了一次写入”。只有文档 Skill 才有足够上下文区分：

- 这是新建文档还是更新已有文档
- 当前写入是不是本轮生成流程的最终落盘
- 没有 review 结果时，后续流程是否必须被 gate 住

### 4.2 create 与 update 必须分流

新建文档和修改文档不是同一种业务动作：

- 新建文档意味着一个新的受管资产开始进入正式流程，应立即走 review gate。
- 修改已有文档更接近增量修订，不应强制立即复审，而应由用户决定是否需要复核。

### 4.3 `/sdd:review` 保留且升级为流程级入口

`/sdd:review` 不能再只是“手工补充入口”。在新设计里：

- 新建文档后，它是必经的统一 review 入口。
- 修改已有文档后，它是可选的复审入口。
- 它承接用户回执、确认项，以及对 `doc-reviewer` 的编排调用。

### 4.4 Hook 不再承担流程判断

本次删除 `PostToolUse` 注册及 `scripts/hooks/post-tool-use.sh`；不保留文档 review 相关的写后 Hook 路径。创建/修改的判定、gate 和后续动作都应回到 Skill 合同里。

## 5. Proposed Architecture

### 5.1 组件划分

本设计收敛为两层：

1. **文档 Skill 层**
   - 负责区分 create / update。
   - 负责在 create 后显式调用 review。
   - 负责在 update 后把是否复审交给用户。
   - 负责根据 review 结果决定是否推进后续流程。

2. **`/sdd:review` 入口与编排层**
   - 对用户暴露稳定命令。
   - 识别 `document_type` 与 `mode` 链路。
   - 调用 `doc-reviewer`。
   - 校验并聚合结构化结果。
   - 负责把结构化结果转换成用户可读回执，并在需要时承接用户确认。

### 5.2 逻辑关系

新建文档时：

```text
文档 Skill 判定目标文档不存在
  ↓
写入新文档
  ↓
显式调用 /sdd:review
  ↓
doc-reviewer
  ↓
结构化结果 + 用户回执
  ↓
Skill 决定是否允许继续后续流程
```

修改已有文档时：

```text
文档 Skill 判定目标文档已存在
  ↓
更新文档
  ↓
不自动 review
  ↓
提示用户如需复审可执行 /sdd:review <doc-path>
```

### 5.3 create / update 判定规则

文档 Skill 必须在写入前显式判断目标文件是否已存在：

- **不存在**：视为 create
- **存在**：视为 update

本判定必须发生在 Skill 流程内，而不是由 Hook 基于路径事后猜测。

## 6. Review Trigger Contract

### 6.1 create 规则

对以下文档类型统一适用：

- `research`
- `prd`
- `dr`
- `spec`
- `plan`

当目标文档不存在且本次写入属于 create 时：

1. Skill 写入文档成功后，必须立即触发 `/sdd:review <doc-path>`。
2. 如果没有拿到有效 review 结果，Skill 不能宣称流程完成。
3. 如果 review 结果阻断、无效或需要用户确认，则后续流程必须停在当前 gate。
4. 对有状态文档：
   - `spec` 保持 `draft`
   - `plan` 保持 `draft`
5. 对无同等状态流的文档：
   - `research`、`prd`、`dr` 也必须明确区分“文档已写入”和“创建流程已完成有效复审”这两层语义。

### 6.2 update 规则

当目标文档已存在且本次属于 update 时：

1. Skill 只负责更新文档。
2. 不自动触发 review。
3. 回执统一改为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
4. 是否复审、何时复审，由用户自己决定。

### 6.3 不再允许的旧语义

以下旧语义在重构后应视为废止：

- “成功写入后由 `PostToolUse Hook` 自动完成 review”
- “所有受管文档写入事件都统一自动触发 review”
- “修改已有文档时也默认立即进入自动 review”

## 7. `/sdd:review` 编排合同

### 7.1 输入

`/sdd:review` 必须围绕受管文档路径自行组装 `doc-reviewer` 所需输入，至少包括：

- `document_path`
- `invocation_source`：`manual`，以及在 Skill 内部显式调用时可保留一个创建流来源值
- `document_type`
- `mode`
- `template_path`
- `standard_path`
- `repair_policy`
- `upstream_paths`
- `max_rounds`

### 7.2 职责

`/sdd:review` 负责：

1. 校验目标路径是否属于受管文档。
2. 识别文档类型。
3. 决定 mode 链路。
4. 构造传给 `doc-reviewer` 的载荷。
5. 调用 `doc-reviewer`。
6. 校验返回是否符合 schema。
7. 聚合最终结果。
8. 返回结构化状态并向用户展示回执。

### 7.3 输出

`/sdd:review` 必须基于结构化结果向用户输出单份聚合回执，至少表达：

- 是否阻断
- 是否需要用户确认
- 剩余问题或阻断项
- 已执行的 mode
- 相关文档路径与文档类型

### 7.4 错误语义

`/sdd:review` 遇到以下情况仍应返回失败：

- 文档路径不在受管范围内
- 文档不存在或不可读
- 文档类型无法识别
- 模板或标准文件缺失
- `doc-reviewer` 返回非预期结构
- schema 校验失败

## 8. `/sdd:review` 调整方式

### 8.1 新定位

`/sdd:review` 在新设计下同时承担两种入口语义：

1. **创建后必经入口**：被文档 Skill 在 create 流程内显式调用。
2. **修改后可选入口**：由用户在 update 后按需手工调用。

### 8.2 入口与实现统一

`/sdd:review` 既负责“用户怎么获得 review 能力”，也负责“review 怎么被编排执行”。

因此，`/sdd:review` 应保留：

1. 用户输入约定
2. `doc-reviewer` 调用编排
3. 结果展示
4. 用户确认承接

但不再承担“自动触发来自 Hook”的叙述中心。

## 9. Error and Failure Semantics

### 9.1 create 流程中的 review 失败

当 create 流程中显式调用的 review 失败时，系统必须明确告诉用户：

- 文档写入已发生
- 但创建流程尚未完成有效复审
- 因此后续流程不能继续推进

这条语义比旧的 Hook 失败语义更直接，也更符合用户对“流程 gate”的理解。

### 9.2 update 流程中的失败语义

update 流程默认不自动 review，因此不存在“更新后自动 review 失败”的主路径。若用户随后手工执行 `/sdd:review` 失败，则按手工 review 失败处理。

### 9.3 无交互原则

`doc-reviewer` 不负责向用户追问；任何需要确认的内容都应由 `/sdd:review` 或更上层文档 Skill 承接。

## 10. Impacted Skills

### 10.1 必须更新的 Skill

以下 Skill 合同必须同步更新，因为它们当前直接写着 Hook 自动触发 review，或持有 `/sdd:review` 的旧定位：

- `skills/review/SKILL.md`
- `skills/research/SKILL.md`
- `skills/prd/SKILL.md`
- `skills/dr/SKILL.md`
- `skills/spec/SKILL.md`
- `skills/plan/SKILL.md`

### 10.2 各 Skill 的预期调整

1. **`/sdd:review`**
   - 从“手工入口 + Hook 配套层”改为“创建后必经入口 + 修改后可选入口”。
   - 去掉“自动 review 由 Hook 触发”的主合同。
   - 保留对外合同、用户输入说明、用户回执和确认承接语义。

2. **`/sdd:research` / `/sdd:prd` / `/sdd:dr` / `/sdd:spec` / `/sdd:plan`**
   - 明确区分 create 与 update。
   - create：写入后显式调用 review。
   - update：写入后不自动 review，由用户决定。
   - 保留各文档类型对应的 mode 语义，例如：
     - `research / prd / dr -> quality`
     - `spec / plan -> quality -> feasibility`
   - 保留 review 阻断、待确认项和不得绕过 gate 的流程约束。

### 10.3 非核心但需要复核的文件

以下文件不是主改造对象，但需要同步删除或收敛 Hook 自动触发的旧合同：

- `scripts/hooks/post-tool-use.sh`
- `hooks/hooks.json`
- `tests/test-post-tool-use.sh`
- `tests/test-skill-contracts.sh`
- `tests/test-mvp-acceptance.sh`
- 其他引用“Hook 自动 review”的 README / TESTING / 设计文档

## 11. Testing Strategy

### 11.1 create / update 分流测试

需要验证：

- 新建 `spec` 时，Skill 会显式触发 review。
- 更新现有 `spec` 时，Skill 不自动触发 review。
- 同样的分流语义覆盖 `research / prd / dr / plan`。

### 11.2 gate 测试

需要验证：

- create 流程拿不到有效 review 结果时，后续流程不会继续。
- `spec` 未完成有效 review 时，不进入审批讨论。
- `plan` 未完成有效 review 时，不从 `draft` 推进到 `planned`。

### 11.3 `/sdd:review` 回归测试

需要验证：

`/sdd:review` 仍然可以作为人工入口使用。
- 它可以被 create 流程内部显式调用。
- 它的用户回执来自自身对结构化结果的聚合，而不是外部 runner。

### 11.4 Hook 回归测试

需要验证：

- `PostToolUse Hook` 不再对受管文档自动触发 review。
- 多次 `Write/Edit` 同一文档不会导致重复自动 review。
- 删除或降级 Hook 后，不影响手工 `/sdd:review` 与 Skill 内显式 review。

## 12. Acceptance Criteria

1. 新建受管文档时，流程内必须显式执行 review。
2. 新建文档拿不到有效 review 结果时，后续流程不能继续。
3. 修改已有文档时，不自动执行 review。
4. `/sdd:review` 仍然存在，并成为创建后必经入口与修改后可选入口。
5. `PostToolUse` 注册与 `scripts/hooks/post-tool-use.sh` 已删除。
6. `spec` 和 `plan` 的状态 gate 与 review 结果保持一致。
7. 用户对“创建 vs 修改”的心智模型清晰且单一。

## 13. Decision Summary

本次设计采用以下结论：

- review 触发点应属于文档 Skill 的流程语义，不属于通用写后 Hook。
- create 与 update 必须明确分流：创建必经 review，修改不自动 review。
- `/sdd:review` 保留并升级为流程级共享入口，同时成为唯一编排入口。
- `PostToolUse` 注册与 `scripts/hooks/post-tool-use.sh` 已删除，原有文档 review 触发职责完全退出运行时路径。