# SDD Plugin 设计规格：Archive Advanced 归档增强

- 日期：2026-07-13
- 状态：draft
- 类型：Design Spec
- 目标：定义 `/sdd:archive` 的高级归档能力，让归档版本为后续任务提供上下文入口、决策溯源、验证依据和继续工作的基础

## 0. 背景

当前 `/sdd:archive` 的核心行为是将当前 active version 移动到归档目录：

```text
docs/vX.Y.Z/ -> docs/archive/vX.Y.Z/
```

现有归档规则要求：

- `docs/CONSTITUTION.md` 存在。
- 只有一个 active version。
- `prd.md` 存在。
- `spec.md` 状态为 `approved`。
- 所有 `plans/*.md` 状态为 `done`。
- 没有 `drafting` DR。
- 没有 `accepted` DR。
- 归档时不修改 archived document states。

这个能力可以把已完成版本移出 active workspace，但还不能充分回答后续任务常见的问题：

- 这个版本最终交付了什么？
- 这个版本为什么这样设计？
- 哪些 spec、plan、DR 支撑了最终结果？
- 哪些 verification 证明这个版本可归档？
- 后续新任务应该先读哪里？
- 如果后续发现 bug 或提出新需求，应该从哪个历史决策追溯？

因此，归档不应只是“移动目录”，还应生成一个面向后续任务的版本入口文档。

## 1. 设计目标

Archive Advanced 的目标是：

1. 保持现有 file-driven 模型，不引入集中式状态数据库。
2. 在每个归档版本中生成 `ARCHIVE.md`，作为该版本的上下文入口。
3. 让后续 ClaudeCode 或人类读者能先读 `ARCHIVE.md`，再跳转到 PRD、spec、plan、DR 和 verification 依据。
4. 保留 spec、plan、DR 的原始职责，不把归档摘要变成新的事实来源。
5. 归档时只生成摘要和索引，不修改已完成文档的状态语义。
6. 支持可选的全局 `docs/archive/INDEX.md`，用于列出所有归档版本。
7. 为后续 `/sdd:archive` skill、README、contract tests 更新提供明确规则。

## 2. 非目标

本规格不要求实现：

- `.sdd/state.json` 或任何集中式状态数据库。
- 对 archived spec、plan、DR 的状态重写。
- 对历史归档版本的强制迁移。
- 自动理解代码 diff 并生成完整 release notes。
- 替代 PRD、spec、plan、DR 的原始内容。
- 在归档阶段修复未关闭 DR 或未完成 plan。
- 自动判断未通过验证的版本是否可以归档。

## 3. 核心模型

Archive Advanced 使用两层文档：

```text
docs/archive/
├── INDEX.md                  # 可选，全局归档入口
└── vX.Y.Z/
    ├── ARCHIVE.md            # 必须，单版本归档入口
    ├── prd.md
    ├── specs/
    │   └── spec.md
    ├── plans/
    │   └── NNN-*.md
    └── decisions/
        └── <tag>-NNNN-<slug>.md
```

### 3.1 `ARCHIVE.md` 是归档版本入口

每个归档版本必须包含一个 `ARCHIVE.md`。

`ARCHIVE.md` 的作用是：

- 提供该版本的快速摘要。
- 汇总可跳转入口。
- 汇总完成的 plans。
- 汇总 closed / dismissed / superseded DR。
- 汇总 verification 结果。
- 记录后续任务提示和已知限制。

`ARCHIVE.md` 是派生摘要，不是新的权威事实来源。若它和 PRD、spec、plan、DR 冲突，应以原始文档为准，并修正 `ARCHIVE.md`。

### 3.2 `INDEX.md` 是可选全局入口

`docs/archive/INDEX.md` 是可选能力。

它的作用是列出所有已归档版本，便于后续任务快速找到相关版本。

`INDEX.md` 不应承载太多细节，只记录：

- 版本号。
- 归档时间。
- 简短摘要。
- 链接到该版本的 `ARCHIVE.md`。

如果实现 `INDEX.md`，它应被视为派生索引，可以从各版本 `ARCHIVE.md` 重建。

## 4. `/sdd:archive` 前置条件

Archive Advanced 保留现有前置条件：

1. `docs/CONSTITUTION.md` 存在。
2. 只有一个 active version。
3. `prd.md` 存在。
4. `specs/spec.md` 状态为 `approved`。
5. 所有 `plans/*.md` 状态为 `done`。
6. 没有 `drafting` DR。
7. 没有 `accepted` DR。

新增建议检查：

8. code-class DR 关闭前应已经通过对应 verification。
9. plan 中的 `关联 DR` 链接应指向存在的 DR 文件。
10. spec 中的 `关联 DR` 链接应指向存在的 DR 文件。
11. DR 的 `影响资产` 中引用的 spec、plan、decision 文件应存在。

新增检查失败时，默认阻止归档，并向用户说明需要修复的引用或状态问题。

## 5. `/sdd:archive` 执行流程

推荐流程：

1. 解析 active version，例如 `docs/vX.Y.Z/`。
2. 执行归档前检查。
3. 从 PRD、spec、plans、DR 中提取归档摘要信息。
4. 在 active version 内生成 `ARCHIVE.md`。
5. 如果启用全局索引，则创建或更新 `docs/archive/INDEX.md`。
6. 将 `docs/vX.Y.Z/` 移动到 `docs/archive/vX.Y.Z/`。
7. 输出归档结果和后续入口。

说明：

- 生成 `ARCHIVE.md` 后再移动目录，可以让 `ARCHIVE.md` 内使用归档后稳定的相对路径，例如 `./specs/spec.md`。
- 如果使用 git 仓库，应继续优先使用 `git mv docs/vX.Y.Z docs/archive/vX.Y.Z`。
- 归档过程不应修改 spec、plan、DR 的状态字段。

## 6. `ARCHIVE.md` 模板

`ARCHIVE.md` 应使用以下结构：

```markdown
# Archive：vX.Y.Z

- 状态：archived
- archived_at：YYYY-MM-DDTHH:MM:SSZ
- source_version：docs/vX.Y.Z
- archived_path：docs/archive/vX.Y.Z

## 1. 版本摘要

<用 3-7 行说明该版本最终完成了什么。>

## 2. 关键入口

| 类型 | 链接 |
| ---- | ---- |
| PRD | [prd.md](./prd.md) |
| Spec | [spec.md](./specs/spec.md) |

## 3. Plans

| Plan | 状态 | 关联 DR | 验证 |
| ---- | ---- | ------- | ---- |

## 4. DRs

| DR | class | tag | 状态 | 关联资产 |
| -- | ----- | --- | ---- | -------- |

## 5. Verification Summary

## 6. 后续任务提示

## 7. 已知限制 / 风险
```

### 6.1 版本摘要

版本摘要应由 ClaudeCode 在归档时生成，但必须基于现有 PRD、spec、plan、DR 内容。

摘要应避免新造事实。若无法从文档中确认，应写：

```text
未在现有文档中明确记录。
```

### 6.2 关键入口

关键入口必须使用归档版本内的相对链接。

示例：

```markdown
| PRD | [prd.md](./prd.md) |
| Spec | [spec.md](./specs/spec.md) |
```

### 6.3 Plans 表

Plans 表应列出所有 `plans/*.md`。

示例：

```markdown
| Plan | 状态 | 关联 DR | 验证 |
| ---- | ---- | ------- | ---- |
| [001-dark-mode-particle-background.md](./plans/001-dark-mode-particle-background.md) | done | [feat-0001-dark-mode-particle-background](./decisions/feat-0001-dark-mode-particle-background.md) | passed |
```

### 6.4 DRs 表

DRs 表应列出所有 `decisions/*.md`。

示例：

```markdown
| DR | class | tag | 状态 | 关联资产 |
| -- | ----- | --- | ---- | -------- |
| [feat-0001-dark-mode-particle-background](./decisions/feat-0001-dark-mode-particle-background.md) | code | feat | closed | spec §4.6, plan 001 |
```

### 6.5 Verification Summary

Verification Summary 应汇总归档前能确认的验证信息。

来源可以包括：

- plan 中的验证结果。
- DR 中的验证方式或关闭记录。
- `/sdd:code` 完成时写入的 verification 记录。

如果当前系统尚未有统一 verification 字段，应在该节保守记录：

```text
未发现统一 verification summary 字段；请查看各 plan / DR 中的验证记录。
```

### 6.6 后续任务提示

后续任务提示用于帮助未来的 ClaudeCode 或人类读者开始工作。

可以包含：

- 后续若发现 bug，应优先查看哪些 spec 小节、plan、DR。
- 哪些行为是本版本明确批准的。
- 哪些问题已作为非目标或已知限制保留。
- 哪些 DR 被 superseded 或 dismissed。

后续任务提示不能改变已批准的 spec 语义。

### 6.7 已知限制 / 风险

该节记录归档时已经知道但未解决的问题。

来源可以包括：

- spec 非目标。
- plan 中未覆盖但被明确排除的内容。
- DR 中的影响或风险。
- verification 中的残余风险。

如果没有明确记录，应写：

```text
未在现有文档中明确记录。
```

## 7. `docs/archive/INDEX.md` 模板

如果实现全局索引，`docs/archive/INDEX.md` 应使用简单表格：

```markdown
# SDD Archive Index

| 版本 | 归档时间 | 摘要 | 入口 |
| ---- | -------- | ---- | ---- |
| vX.Y.Z | YYYY-MM-DDTHH:MM:SSZ | <一句话摘要> | [ARCHIVE.md](./vX.Y.Z/ARCHIVE.md) |
```

规则：

- 每个归档版本最多一行。
- 不在 `INDEX.md` 中重复完整 plan / DR 信息。
- 如果索引缺失，单版本 `ARCHIVE.md` 仍然是有效归档。
- 如果索引和版本目录冲突，以版本目录和 `ARCHIVE.md` 为准。

## 8. 跨文档链接规则

归档后的文档应继续遵循 DR Advanced 跨文档链接规则。

在 `ARCHIVE.md` 中：

- 引用 PRD 使用 `./prd.md`。
- 引用 spec 使用 `./specs/spec.md`。
- 引用 plan 使用 `./plans/<plan-file>.md`。
- 引用 DR 使用 `./decisions/<dr-file>.md`。

不强制使用 Markdown anchor 链接到具体章节。章节号和标题可以作为普通文本放在链接后。

示例：

```markdown
[spec.md](./specs/spec.md) §4.6 装饰背景层
```

## 9. 错误处理

### 9.1 前置条件失败

如果现有 archive 前置条件失败，应停止归档，不生成 `ARCHIVE.md`，不移动目录。

示例失败：

- spec 不是 `approved`。
- plan 不是 `done`。
- 存在 `drafting` 或 `accepted` DR。

### 9.2 链接检查失败

如果新增链接检查失败，应停止归档，并列出失效链接。

示例：

```text
无法归档：发现失效引用。
- specs/spec.md -> ../decisions/feat-0001-dark-mode-particle-background.md 不存在
- plans/001-dark-mode-particle-background.md -> ../decisions/feat-0001-dark-mode-particle-background.md 不存在
```

### 9.3 `ARCHIVE.md` 生成失败

如果 `ARCHIVE.md` 生成失败，应停止归档，不移动目录。

原因：没有 `ARCHIVE.md` 的归档版本无法满足 Archive Advanced 的目标。

### 9.4 `INDEX.md` 更新失败

如果 `INDEX.md` 是可选能力，更新失败不应阻止单版本归档，但必须提示用户。

如果用户或配置要求强制维护 `INDEX.md`，更新失败应阻止归档。

## 10. 对 skill、README、测试的预期影响

后续实现本规格时，预计需要检查或修改：

```text
skills/archive/SKILL.md
README.md
tests/test-skill-contracts.sh
```

预期变化：

1. `/sdd:archive` 从“移动目录”升级为“生成归档摘要 + 移动目录”。
2. `skills/archive/SKILL.md` 增加 `ARCHIVE.md` 生成规则。
3. README 说明 `docs/archive/vX.Y.Z/ARCHIVE.md` 是后续任务入口。
4. contract tests 验证 archive skill 包含 `ARCHIVE.md`、`INDEX.md` 可选规则、前置条件和不修改 archived document states。
5. 如果后续实现链接检查，测试应覆盖失效链接阻止归档。

## 11. 验收标准

当本规格进入实现时，至少应满足：

1. `/sdd:archive` 归档每个版本时生成 `ARCHIVE.md`。
2. `ARCHIVE.md` 包含版本摘要、关键入口、plans、DRs、verification summary、后续任务提示、已知限制 / 风险。
3. `ARCHIVE.md` 中的链接使用归档版本内相对路径。
4. 归档不修改 spec、plan、DR 的既有状态字段。
5. 如果存在未完成 plan 或未关闭 DR，归档失败。
6. 如果 `ARCHIVE.md` 生成失败，归档失败。
7. 全局 `docs/archive/INDEX.md` 是可选能力；如果启用，则包含归档版本入口。
8. README 和 contract tests 覆盖 Archive Advanced 的核心规则。
