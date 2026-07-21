---
name: triage
description: Triage user questions after implementation, review, or testing. Use for /sdd:triage and /sdd:triage --deep whenever you need to route a question to DR, spec, plan, code, or explanation only without making changes.
---

# /sdd:triage

Reference-aware read-only triage before choosing whether to create a DR, revise spec, revise plan, change code, fix references, or explain existing behavior.

## Scope

`/sdd:triage` recommends a path and waits for the user to choose. It does not execute the chosen path.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and report the project state is inconsistent.
6. Only when exactly one legal `state: active` version exists, read documents inside the version.

## Hard rules

- 不创建 DR。
- 不接受 DR。
- 不关闭 DR。
- 不修改 spec。
- 不修改 plan。
- 不修改 code。
- 不改变 plan 状态。
- 不替用户选择后续路径。
- 必须向用户说明推荐路径和可选路径。
- 必须等待用户确认后，才能建议进入其他 skill。
- 不把 `## 影响资产` 当成正式关系来源。

## Token control

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `spec/*.md`。
- 不得默认读取所有 `plan/*.md`。
- 不得默认读取所有 `dr/*.md`。
- 不得默认读取所有 archived versions。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。

## Reference-aware read order

1. Understand the question; ask for a locator if needed.
2. Read minimal active-version structure (prd existence, `spec/*.md`, `plan/*.md`, `dr/*.md` filenames).
3. If the user points to a spec, read the relevant section and that file's `## 文档引用` table.
4. If the user points to a plan, read its status, relevant tasks, and `## 文档引用` table.
5. If the user points to a DR, read its process fields, status, `## 文档引用` table, and needed body sections.
6. Follow `## 文档引用` only to directly relevant target documents.
7. For cross-version references, read only the specific referenced version document.
8. Read code only when comparing implementation against spec/plan/DR.
9. If evidence is insufficient, output a low-confidence triage and state the missing locator or context.

## Depth

```text
/sdd:triage
/sdd:triage --deep
```

`--deep` may read more relevant plan, DR, or code context, but still only after narrowing the candidate range.

## Classification

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 或 accepted code-class DR 基本明确，但 plan 拆解、策略、边界或验收有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `reference issue` | `## 文档引用` 缺失、错误、关系不当、locator 不完整，或仍依赖旧的 `关联 DRs` / `影响资产` 表达正式关系。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

## Output format

```text
我的判断：这是 <分类>。
置信度：low | medium | high
已读取依据：
- <spec 小节或文件，如有>
- <plan 文件，如有>
- <DR 文件，如有>
- <文档引用表或 locator，如有>
- <代码文件，如有>
原因：<简短依据>。
推荐路径：<路径名称>。
可选路径：
1. <路径 A>：<适用条件 / 结果>
2. <路径 B>：<适用条件 / 结果>
3. <路径 C>：<适用条件 / 结果>
请确认你要走哪条路径。
```

## Recommended paths

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且满足轻量 fix 条件 | `/sdd:dr fix <title>`（lightweight）→ accept → `/sdd:code <id>` |
| B | 代码实现问题，但需要 plan | `/sdd:dr fix <title>` → accept → `/sdd:plan <id>` → `/sdd:code <plan>` |
| C | plan 问题 | `/sdd:dr fix <title>` → accept → 新增 incremental plan → `/sdd:code <plan>` |
| D | spec 缺失或歧义 | `/sdd:dr spec <title>` 或 spec-changing code DR → `/sdd:spec` → 后续按 DR class |
| E | 新需求或行为变更 | `/sdd:dr feat|chg <title>` → `/sdd:spec` → `/sdd:plan <id>` → `/sdd:code <plan>` |
| F | 当前行为符合设计 | explain only，不创建 DR |
| G | 引用关系缺失或错误 | document-class `doc` 或 `spec` DR → `/sdd:spec` 或对应文档修订，不进入 `/sdd:plan` 或 `/sdd:code` |

## Boundaries

- 不创建 active version、不修改 state.json、不创建/接受/关闭 DR、不修改 spec/plan/DR/PRD/requirements/code、不生成 plan、不执行 code、不修复引用表、不运行 archive。
- 不在 0 active、多 active 或 state 损坏时继续分析版本内流程。
