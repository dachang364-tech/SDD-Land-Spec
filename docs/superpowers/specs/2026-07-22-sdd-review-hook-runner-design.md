# SDD Review 触发重构设计

- 日期：2026-07-22
- 状态：draft
- 类型：Design Spec
- 目标：将受管文档的自动 review 从 `Skill 内部编排` 下沉为 `Hook + 共享 runner`，让 `/sdd:review` 保持为对外入口但变薄，并保证 `/sdd:prd`、`/sdd:spec` 等写入流程不再依赖模型是否继续执行后续步骤。

## 文档引用

| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | review 对外入口 | [skills/review/SKILL.md](../../../skills/review/SKILL.md) | `/sdd:review` | 该 Skill 仍然保留，但其核心编排应下沉到共享 runner |
| references | PRD Skill | [skills/prd/SKILL.md](../../../skills/prd/SKILL.md) | `/sdd:prd` | 该 Skill 不再直接负责触发 review 编排，只保留文档生成职责 |
| references | Spec Skill | [skills/spec/SKILL.md](../../../skills/spec/SKILL.md) | `/sdd:spec` | 同上 |
| references | Hook 行为 | [scripts/hooks/pre-tool-use.sh](../../../scripts/hooks/pre-tool-use.sh) | - | 现有 pre-tool-use 只负责写前门控，本设计新增写后触发语义 |
| references | Hook 注册 | [hooks/hooks.json](../../../hooks/hooks.json) | - | 现有 hooks 配置只注册 SessionStart 与 PreToolUse，需要补充写后触发入口 |

## 1. 背景

当前受管文档的 review 触发主要依赖 Skill 合同中的“写完后继续触发 review”语义。这种方式的问题是：

1. 它依赖模型在完成写入后继续执行后续步骤，可靠性不足。
2. 自动 review、手动 review、不同文档类型的 mode 顺序分散在多个 Skill 中，容易漂移。
3. 运行时触发与对外合同混在一起，导致用户无法判断哪一层保证了 review 一定发生。

本设计要解决的是：**受管文档一旦成功写入，就由运行时机制统一触发 review，不再依赖 Skill 是否“记得继续执行”**。

## 2. Goals

1. 对 `docs/versions/vX.Y.Z/research/*.md`、`prd/prd.md`、`spec/*.md`、`plan/*.md`、`dr/*.md` 的成功写入统一触发 review。
2. 将 review 编排从 `/sdd:review` 中下沉到共享 runner。
3. 保留 `/sdd:review` 作为对外入口，但让它变成薄入口与用户回执层。
4. 让自动触发与手动触发复用同一条核心 review 执行链。
5. 让 runner 完全无交互，只返回结构化结果和退出码。
6. 保持现有 `/sdd:prd`、`/sdd:spec` 等 Skill 的文档生成职责，不要求它们再显式编排 review。

## 3. Non-Goals

本次不纳入：

- 修改 `doc-reviewer` 的内部评分模型或 schema。
- 改变 `research / prd / dr / spec / plan` 的具体模板内容。
- 改变 review 的质量标准本身。
- 改造 `PreToolUse` 的写前门控语义。
- 将 Hook 作用范围扩展到所有文件，仅覆盖 SDD 受管文档路径。
- 让 runner 直接承担用户交互。

## 4. Core Design Principles

### 4.1 自动触发属于运行时保证

自动 review 不应依赖模型继续执行后续步骤，而应由写后 Hook 在受管文档写入成功后统一触发。Skill 仍然可以描述语义，但不再承担“记得继续触发”的职责。

### 4.2 `/sdd:review` 保留为对外合同

用户仍然可以显式调用 `/sdd:review`。它负责解释能力边界、接受用户输入、展示结果，并承接人工确认，但不再自行重复完整编排。

### 4.3 runner 必须无交互

runner 只做确定性编排：识别路径、决定 mode、调用 subagent、校验输出、聚合结果。它不向用户追问，不打开分支对话，也不承接确认流程。

### 4.4 单一 review 核心

自动触发与手动触发必须进入同一条 review 核心执行链，避免不同入口产生不同规则、不同输出和不同失败语义。

## 5. Proposed Architecture

### 5.1 组件划分

本设计引入三层：

1. **Hook 层**
   - 监听 SDD 受管路径的写入成功事件。
   - 判断是否需要触发 review。
   - 只负责把结构化请求交给 runner。

2. **review runner**
   - 完全无交互。
   - 接收结构化输入。
   - 识别 `document_type` 与 `mode` 链路。
   - 调用 `doc-reviewer`。
   - 校验并聚合结果。

3. **`/sdd:review` 入口层**
   - 对用户暴露稳定命令。
   - 复用 runner。
   - 负责把 runner 的结构化结果转换成用户可读回执。

### 5.2 逻辑关系

```text
写入受管文档
  ↓
PostToolUse Hook
  ↓
review runner
  ↓
doc-reviewer
  ↓
结构化结果 + 用户回执
```

手动入口则是：

```text
用户输入 /sdd:review
  ↓
review runner
  ↓
doc-reviewer
  ↓
结构化结果 + 用户回执
```

### 5.3 Hook 覆盖范围

Hook 只覆盖 SDD 受管文档路径：

- `docs/versions/vX.Y.Z/research/*.md`
- `docs/versions/vX.Y.Z/prd/prd.md`
- `docs/versions/vX.Y.Z/spec/*.md`
- `docs/versions/vX.Y.Z/plan/*.md`
- `docs/versions/vX.Y.Z/dr/*.md`

不覆盖：

- `src/**`
- 其他非 SDD 受管路径
- 任意用户自定义草稿目录

## 6. Review Runner Contract

### 6.1 输入

runner 接收结构化输入，至少包括：

- `document_path`
- `invocation_source`：`automatic` 或 `manual`
- 可选 `document_type`
- 可选 `mode`

### 6.2 职责

runner 负责：

1. 校验目标路径是否属于受管文档。
2. 识别文档类型。
3. 决定 mode 链路。
4. 构造传给 `doc-reviewer` 的载荷。
5. 调用 `doc-reviewer`。
6. 校验返回是否符合 schema。
7. 聚合最终结果。
8. 返回结构化状态和退出码。

### 6.3 输出

runner 只输出结构化结果，不进行用户对话。其结果至少要表达：

- 是否通过
- 是否阻断
- 是否需要用户确认
- 剩余问题或阻断项
- 已执行的 mode
- 总轮次

### 6.4 错误语义

runner 遇到以下情况应返回失败：

- 文档路径不在受管范围内
- 文档不存在或不可读
- 文档类型无法识别
- 模板或标准文件缺失
- `doc-reviewer` 返回非预期结构
- schema 校验失败

## 7. `/sdd:review` 调整方式

### 7.1 保留入口，收敛职责

`/sdd:review` 不应再完整持有 review 编排逻辑，而应变成：

1. 接收用户输入。
2. 调用 runner。
3. 读取 runner 结果。
4. 生成用户回执。
5. 在需要时承接用户确认。

### 7.2 入口与实现分离

`/sdd:review` 负责“用户怎么使用这个能力”，runner 负责“这个能力怎么执行”。

因此，`/sdd:review` 需要保留，但内容应明显变薄，避免与 runner 复制同一套规则。

## 8. Error and Failure Semantics

### 8.1 自动触发失败

当 Hook 触发的自动 review 失败时，系统必须明确告诉用户：

- 文档写入已发生，或
- 写入和 review 一并被视为失败

具体选择取决于后续实现约束，但设计层必须强制定义这种语义，不能模糊处理。

### 8.2 手动触发失败

手动调用 `/sdd:review` 失败时，应保留与自动触发一致的结果表达，避免用户手工 review 和自动 review 语义不一致。

### 8.3 无交互原则

runner 不负责向用户追问；任何需要确认的内容都应由 `/sdd:review` 或更上层调用者承接。

## 9. Testing Strategy

### 9.1 Hook 触发测试

需要验证：

- 写入受管路径后，Hook 会触发 review runner。
- 非受管路径不会触发。
- 受管路径中的不同文档类型映射到正确的 review 链路。

### 9.2 runner 测试

需要验证：

- runner 对路径分类是确定的。
- runner 调用 `doc-reviewer` 时使用的结构化输入正确。
- runner 对 schema 失败、缺失模板、无效路径都返回失败。

### 9.3 `/sdd:review` 回归测试

需要验证：

- `/sdd:review` 仍然可以作为人工入口使用。
- 它的用户回执来自 runner。
- 它不再复制核心编排逻辑。

## 10. Acceptance Criteria

1. SDD 受管文档写入成功后，会触发统一 review 路径。
2. Hook 的覆盖范围只包括 SDD 受管文档路径。
3. `runner` 无交互，且只输出结构化结果和退出码。
4. `/sdd:review` 仍然存在，但明显变薄。
5. 自动 review 与手动 review 复用同一条核心逻辑。
6. `prd`、`spec` 等 Skill 不再依赖模型继续执行后续 review 步骤。
7. 设计不会把 `doc-reviewer` 暴露成新的对外公共入口。

## 11. Decision Summary

本次设计采用以下结论：

- 自动 review 应由运行时机制保证，而不是由 Skill 合同“提醒执行”。
- Hook 负责触发，runner 负责编排，`/sdd:review` 负责对外合同与用户回执。
- `doc-reviewer` 维持为内部执行单元，不升级为公共入口。
- 这个结构最适合当前“必须自动 review，但只覆盖受管路径”的需求。
