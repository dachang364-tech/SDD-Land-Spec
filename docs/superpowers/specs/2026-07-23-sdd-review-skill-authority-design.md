# SDD Review Skill 权威收敛设计

- 日期：2026-07-23
- 状态：draft
- 类型：Design Spec
- 目标：删除 `PostToolUse Hook` 与 `sdd-review-runner.sh`，把受管文档的 review 触发与执行权威统一收敛到 `/sdd:review` Skill；各文档 Skill 在 create 流程中显式调用 `/sdd:review <doc-path>`，update 流程不自动 review。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | review 入口 | [skills/review/SKILL.md](../../../skills/review/SKILL.md) | `/sdd:review` | 新设计下它从“手工入口 + runner 包装层”升级为唯一 review 编排入口 |
| references | PRD Skill | [skills/prd/SKILL.md](../../../skills/prd/SKILL.md) | `/sdd:prd` | create 后显式调用 `/sdd:review <doc-path>`，update 不自动 review |
| references | Plan Skill | [skills/plan/SKILL.md](../../../skills/plan/SKILL.md) | `/sdd:plan` | create 后显式调用 `/sdd:review <doc-path>`，并保留状态 gate |
| references | Hook 注册 | [hooks/hooks.json](../../../hooks/hooks.json) | `PostToolUse` | 需要删除 review 相关注册 |
| references | Hook 脚本 | [scripts/hooks/post-tool-use.sh](../../../scripts/hooks/post-tool-use.sh) | - | 需要删除或退役，不再参与 review 主流程 |
| references | review runner | [scripts/lib/sdd-review-runner.sh](../../../scripts/lib/sdd-review-runner.sh) | - | 需要删除，相关逻辑并回 `/sdd:review` Skill |
| references | Skill 规范化约束 | [CLAUDE.md](../../../CLAUDE.md) | `/skill-creator` 约束 | 本次涉及多个 `skills/*/SKILL.md` 合同修改，必须继续遵守 Skill 规范化约束 |

## 1. 背景

当前仓库虽然已经把“自动 review 的权威触发点”从文档 Skill 部分收回，但实际实现仍然保留了一条活跃链路：`Write/Edit` 成功后，由 `hooks/hooks.json` 注册的 `PostToolUse Hook` 调用 `scripts/hooks/post-tool-use.sh`，再由脚本执行 `scripts/lib/sdd-review-runner.sh`。

这条链路的问题不是“实现细节不够优雅”，而是它和目标流程模型天然冲突：

1. Hook 只能看到文件写入事件，看不到“这是 create 还是 update”的业务语义。
2. 文档 Skill 才知道何时完成了本轮生成；Hook 只会在每次 `Write/Edit` 后被动触发，容易对中间态重复 review。
3. review 的唯一入口实际上被拆成了三层：文档 Skill、`/sdd:review`、shell runner，导致合同分散。
4. 用户心智模型因此混乱：是“写完文档自动 review”，还是“create 后显式进入 review 流程”，当前实现同时存在两套说法。

本次设计的核心判断是：**review 是一个流程节点，不是一个文件事件。** 既然如此，触发与执行权威都应该回到 Skill 层，而不应再由 Hook 或 shell runner 承担主职责。

## 2. Goals

1. 删除 `PostToolUse Hook` 对 review 的注册与实现。
2. 删除 `scripts/lib/sdd-review-runner.sh`，不再保留独立 runner 作为中间执行层。
3. 将 review 的编排、mode 链路、结果校验、用户确认回执统一收敛到 `skills/review/SKILL.md`。
4. 对 `research / prd / dr / spec / plan` 统一建立 create/update 分流：
   - create：写入后显式调用 `/sdd:review <doc-path>`
   - update：不自动 review，只提示手工复审
5. 保留 `spec` / `plan` 的状态 gate：create review 未完成时不得越过 `draft`。
6. 让测试合同从“Hook/runner 存在”切换为“review 由 Skill 显式触发”。

## 3. Non-Goals

本次不包含：

- 改动 `doc-reviewer` 的输出 schema、评分模型或提示词语义。
- 改动 `.sdd/templates/` 中的模板与标准内容。
- 改动 `PreToolUse` 的写前门控。
- 为 update 流程增加新的自动复审机制。
- 引入新的 review CLI 命令名或新的 shell 协议层。

## 4. 核心原则

### 4.1 review 权威只能有一个

用户与测试都必须能回答同一个问题：review 到底由谁负责。新设计下，唯一答案应当是：`/sdd:review` Skill。

### 4.2 create/update 判定必须发生在文档 Skill 内

只有文档 Skill 拥有足够上下文去判断：

- 当前目标文件是否第一次创建
- 当前写入是否本轮生成流程的最终落盘
- review 失败后流程应停在什么 gate

因此 create/update 不能再由 Hook 或 runner 事后猜测。

### 4.3 `/sdd:review` 既是用户入口，也是内部流程入口

`/sdd:review <doc-path>` 不只是用户手工命令，也应是文档 Skill 在 create 后调用的统一内部入口。这样可以保证：

- 所有 review 走同一套编排
- 用户回执只在一个地方定义
- mode 链路与确认语义不再分散在 shell 与 Skill 两边

### 4.4 update 默认不自动 review

update 更接近增量修订而不是资产首次进入流程。默认不自动 review，既符合你的目标，也能避免多轮编辑时的重复噪音。

## 5. 目标架构

### 5.1 组件边界

新架构只保留两层：

1. **文档 Skill 层**
   - 负责 create/update 判定
   - 负责生成或更新文档
   - 负责在 create 后显式调用 `/sdd:review <doc-path>`
   - 负责根据 review 结果决定是否推进后续流程

2. **`/sdd:review` Skill 层**
   - 负责验证目标路径与文档类型
   - 负责决定 review mode 或 mode 链路
   - 负责调用 `doc-reviewer` subagent
   - 负责校验 reviewer 结果
   - 负责聚合用户可读回执
   - 负责承接 `requires_user_confirmation`

不再保留：

- `PostToolUse Hook` 作为 review 触发层
- `post-tool-use.sh` 作为 review 入口脚本
- `sdd-review-runner.sh` 作为 review 编排中间层

### 5.2 流程图

create：

```text
文档 Skill 判断目标文件不存在
  ↓
生成并写入文档
  ↓
显式调用 /sdd:review <doc-path>
  ↓
/sdd:review 判断 document_type 与 mode 链路
  ↓
调用 doc-reviewer subagent
  ↓
校验结果并生成回执
  ↓
文档 Skill 根据结果决定是否继续流程
```

update：

```text
文档 Skill 判断目标文件已存在
  ↓
更新文档
  ↓
不自动 review
  ↓
提示用户如需复审，请执行 /sdd:review <doc-path>
```

## 6. `/sdd:review` 合同重构

### 6.1 新定位

`/sdd:review` 是唯一 review 编排入口，既服务于：

1. 用户手工执行 `/sdd:review <doc-path>` 的场景。
2. 文档 Skill create 后显式进入 review gate 的场景。

### 6.2 内部职责

`/sdd:review` 内部需要承担当前 runner 的关键逻辑，但以 Skill 合同的形式表达，而不是 shell 脚本：

1. 校验目标路径是否属于受管文档。
2. 识别 `document_type`。
3. 决定 mode 链路：
   - `research / prd / dr -> quality`
   - `spec / plan -> quality -> feasibility`
4. 按顺序调用 `doc-reviewer` subagent。
5. 对每个 mode 的结构化结果做 schema 级校验。
6. 聚合为统一回执，至少包含：
   - `document_path`
   - `document_type`
   - `executed_modes`
   - `blocked`
   - `requires_user_confirmation`
   - `remaining_items`
7. 当结果需要用户确认时，由 `/sdd:review` 自己承接确认，再决定是否重新 review。

### 6.3 失败语义

`/sdd:review` 失败时必须明确区分：

- 路径不合法
- 非受管文档
- 模板资产缺失
- reviewer 返回无效结果
- review 被阻断
- review 需要用户确认

其中最后两类不等于“系统崩溃”，但都属于不能继续推进 create gate 的结果。

## 7. 文档 Skill 合同调整

### 7.1 统一规则

`research / prd / dr / spec / plan` 全部改成同一种高层模式：

1. 写入前检查目标文件是否存在。
2. 不存在即 create；存在即 update。
3. create 成功写入后，必须显式调用 `/sdd:review <doc-path>`。
4. update 不自动 review。
5. update 的统一回执为：`文档已更新；如需复审，请执行 /sdd:review <doc-path>`。

### 7.2 各类型 mode 语义

- `research`：create 后执行 `quality`
- `prd`：create 后执行 `quality`
- `dr`：create 后执行 `quality`
- `spec`：create 后执行 `quality -> feasibility`
- `plan`：create 后执行 `quality -> feasibility`

### 7.3 有状态文档 gate

- `spec`：create review 未拿到有效通过结果前，状态保持 `draft`，不得进入普通审批。
- `plan`：create review 未拿到有效通过结果前，状态保持 `draft`，不得推进为 `planned`。

### 7.4 update 不自动 review 的明确边界

删除 Hook 后，update 流程不再存在“写完文件后系统还会偷偷跑 review”的行为。只要当前操作是 update，流程就应该结束在用户可理解的提示语上，而不是隐式触发另一路逻辑。

## 8. 删除项

### 8.1 运行时删除项

需要从实现中删除：

- `hooks/hooks.json` 中的 `PostToolUse` 注册
- `scripts/hooks/post-tool-use.sh`
- `scripts/lib/sdd-review-runner.sh`

### 8.2 合同删除项

需要从 Skill / 文档 / 测试里删除以下旧叙述：

- “成功写入后由 `PostToolUse Hook` 触发 review”
- “自动 review 由 shell runner 统一执行”
- “`/sdd:review` 只是共享 runner 的手工入口”

## 9. 测试策略

### 9.1 Skill 合同测试

需要把 `tests/test-skill-contracts.sh` 从当前的 Hook/runner 中心合同改成：

- `skills/review/SKILL.md` 明确自己是唯一 review 编排入口
- 文档 Skill create 后显式调用 `/sdd:review <doc-path>`
- update 明确不自动 review
- 不再要求出现 `PostToolUse Hook` 或 `scripts/lib/sdd-review-runner.sh`

### 9.2 Hook 回归测试

`tests/test-post-tool-use.sh` 需要删除或重写，因为 PostToolUse 路径本身就是被移除对象。测试目标应改成“Hook 已不存在或不再注册”。

### 9.3 MVP/运行时合同测试

`tests/test-mvp-acceptance.sh` 与其他运行时合同测试需要改为校验：

- `hooks/hooks.json` 不再包含 `PostToolUse`
- `scripts/hooks/post-tool-use.sh` 不再作为必需文件
- `scripts/lib/sdd-review-runner.sh` 不再作为必需文件
- `/sdd:review` 仍存在
- create/update 分流文本存在

### 9.4 gate 测试

仍需验证：

- `spec` create 拿不到有效 review 结果时保持 `draft`
- `plan` create 拿不到有效 review 结果时保持 `draft`
- update 不会自动触发 review

## 10. 风险与权衡

### 10.1 优点

- review 权威只保留一处，心智模型清晰。
- 删除 Hook 后，不再有中间态多次写入导致的重复 review。
- 删除 runner 后，shell 层与 Skill 层不再维护两份相近合同。

### 10.2 代价

- `skills/review/SKILL.md` 会变重，需要重新承接 runner 逻辑。
- 测试合同改动面较大，因为当前大量断言仍绑定 Hook/runner 文本。
- 文档 Skill 与 review Skill 的交互方式需要重新明确，避免出现“调用 `/sdd:review`”但没有清晰结果回传的模糊描述。

### 10.3 为什么不保留 runner

保留 runner 的确能减少一次迁移量，但它会继续制造“双权威”：Skill 负责入口，runner 负责真实流程。你已经明确要求“处理逻辑收敛到 `/review` Skills 中，在 Skills 中调用 Subagent”，因此保留 runner 会违背这个目标，不作为本次方案。

## 11. 验收标准

1. `PostToolUse` 不再注册，不再参与 review。
2. `post-tool-use.sh` 不再是 review 主流程的一部分。
3. `sdd-review-runner.sh` 被删除，其职责并入 `/sdd:review`。
4. `/sdd:review` 成为唯一 review 编排入口。
5. `research / prd / dr / spec / plan` 全部明确区分 create/update。
6. create 后显式调用 `/sdd:review <doc-path>`；update 不自动 review。
7. `spec` 与 `plan` 的 `draft` gate 与 review 结果保持一致。
8. 测试合同不再要求 Hook/runner 存在，而是要求 Skill 驱动 review。

## 12. 决策摘要

本设计的最终结论是：

- 删除 `PostToolUse Hook`。
- 删除 `sdd-review-runner.sh`。
- 将 review 的唯一触发与执行权威收敛到 `/sdd:review` Skill。
- 文档 Skill 在 create 后显式调用 `/sdd:review <doc-path>`。
- update 不自动 review，只保留手工复审提示。

## 13. Self-Review

### 13.1 Placeholder scan

- 无 `TBD`、`TODO`、`path/to/file`、`稍后实现` 等占位符。

### 13.2 Internal consistency

- 文档整体一致假设：Hook 与 runner 都删除，`/sdd:review` 成为唯一权威入口。
- create/update 行为在 Goals、架构、测试、验收标准中表述一致。

### 13.3 Scope check

- 范围聚焦在 review 触发与执行权威重构，没有扩展到模板、review schema、PreToolUse 或非受管文档。

### 13.4 Ambiguity check

- 已明确：update 仍保持“不自动 review”。
- 已明确：create 后走 `/sdd:review`，不是保留 runner，也不是每个文档 Skill 各自调用 `doc-reviewer`。
