---
name: triage
description: Triage user questions after implementation, review, or testing. Use for /sdd:triage and /sdd:triage --deep.
---

# /sdd:triage

Triage user questions before choosing whether to create a DR, revise spec, revise plan, change code, or explain existing behavior.

## Scope

`/sdd:triage` is a read-only diagnostic skill. It recommends a path and waits for the user to choose. It does not execute the chosen path.

It applies when the user asks questions such as:

- “这个是不是有问题？”
- “为什么这里这样实现？”
- “这里是不是应该改？”
- “这个行为和我预期不一样。”
- “这个 plan 当时是不是漏了什么？”
- “spec 里是不是应该说明这个边界？”

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Identify the smallest useful locator from the user question: feature name, section number, DR ID, plan filename, observed symptom, or code path.
4. Read minimal active-version structure information, such as spec, plans, and decisions filenames.
5. Read only the candidate spec section, plan, DR, or code files needed for the question.
6. Do not modify files.

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

## Token control

- 不得一次性读取整个 active version 目录。
- 不得默认读取所有 `plans/*.md`。
- 不得默认读取所有 `decisions/*.md`。
- 不得默认读取代码。
- 必须先建立候选范围，再按候选文件读取。
- 必须优先使用用户提供的功能名、小节号、DR ID、plan 文件名、错误现象或相关文件路径来缩小范围。

Recommended read order:

1. Understand the user question and ask for a locator if needed.
2. Read minimal active-version structure information, such as spec, plans, and decisions filenames.
3. Read only the relevant spec section.
4. Read only the relevant plan.
5. Read only the relevant DR.
6. Read code only when needed to compare implementation against spec or plan.
7. If evidence is insufficient, output a low-confidence triage and state what context is missing.

## Depth

```text
/sdd:triage
```

Default lightweight triage. Read necessary docs only and do not scan all code.

```text
/sdd:triage --deep
```

Deep triage. Read more relevant plan, DR, or code context, but still only after narrowing the candidate range.

## Classification

Output one classification:

| 分类 | 含义 |
| ---- | ---- |
| `code implementation issue` | spec 和 plan 基本正确，但当前代码实现偏离预期。 |
| `plan issue` | spec 基本明确，但 plan 拆解、实现策略、任务边界或验收安排有问题。 |
| `spec issue` | spec 缺失、歧义、契约不完整或验收标准不足。 |
| `new requirement / change request` | 用户提出的是新的能力、行为变化或超出现有 spec 的需求。 |
| `explanation only` | 当前行为符合已批准设计，用户需要解释而不是变更。 |
| `unclear, needs user choice` | 证据不足，或同一问题可合理归入多条路径，需要用户选择。 |

## Analysis order

1. Does the approved spec clearly describe the expected behavior?
2. Does the plan correctly cover the relevant spec behavior?
3. Does the current implementation match the plan and spec?
4. Does the question expose a missing or ambiguous spec rule?
5. Is the user asking for a new requirement or behavior change?
6. Is the user asking only for an explanation of existing behavior?

## Output format

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

## Recommended paths

| 路径 | 判断 | 推荐流程 |
| --- | --- | --- |
| A | 代码实现问题，且可轻量修复 | `fix DR -> code -> verification` |
| B | 代码实现问题，但需要 plan | `fix DR -> plan -> code -> verification` |
| C | plan 问题 | `fix DR -> revised plan -> code -> verification` |
| D | spec 问题 | `fix/spec DR -> spec -> plan -> code -> verification` |
| E | 新需求或行为变更 | `new feat/chg DR -> spec -> plan -> code -> verification` |
| F | 仅解释现有行为 | `explain only -> no DR` |

## Original DR handling

- If the original feature/chg/arch DR has completed `/sdd:code` and the question appears during review or follow-up discussion, use a new DR by default.
- If the original DR is closed, do not reopen it.
- If the original DR has not completed implementation and the issue is still in the same plan/code execution scope, the current flow can continue, but explain this choice to the user.
- A new DR may link to the original DR; do not use `supersedes` for ordinary bug-fix relationships unless the new DR replaces the original decision.
