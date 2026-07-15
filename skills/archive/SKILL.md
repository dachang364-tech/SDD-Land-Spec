---
name: archive
description: Archive the current active SDD version. Use for /sdd:archive.
---

# /sdd:archive

把唯一 active version 转为 archived 状态，生成版本归档入口，更新全局 archive index，执行归档前引用检查。归档不移动版本目录。

## Preconditions

1. `docs/CONSTITUTION.md` 必须存在；缺失时停止，提示运行 `/sdd:init`。
2. `docs/versions/` 必须存在；缺失时停止，提示运行 `/sdd:init` 或 `/sdd:doctor`。
3. 恰好存在一个 `state: active` 的版本。
4. active version 目录名与 `state.json.version` 一致。
5. `state.json.state` 为 `active`，`archived_at` 为 `null`。
6. active version 的 `specs/*.md` 至少一份。
7. 所有 `specs/*.md` 的 Markdown 头部状态必须为 `approved`。
8. 所有 `plans/*.md` 的 Markdown 头部状态必须为 `done`；没有 plan 时通过。
9. 所有 `decisions/*.md` 的 Markdown 头部状态必须为 `closed`；没有 DR 时通过。
10. DR 不得使用 `dismissed` 或 `superseded` 作为状态值。
11. `prd.md` 缺失不阻止归档。
12. active version 内不存在 `ARCHIVE.md`，或用户明确允许覆盖。
13. Blocking 引用检查必须通过。

## Blocking reference checks

- 本地相对 Markdown `.md` 链接目标必须存在。
- 跨版本引用必须有版本 locator；project-level requirements 引用必须有 `project:` locator。
- locator 格式必须合法；Markdown link 和 locator 必须指向同一目标。
- 关系值必须属于枚举：`references`、`derives_from`、`implements`、`modifies`、`replaces`、`deprecates`。
- `## 文档引用` 表必须可解析。
- 矩阵外强引用（`modifies`、`replaces`、`deprecates`）属于 blocking。
- plan 使用 `modifies`、`replaces`、`deprecates` 属于 blocking。
- `ARCHIVE.md` 不得声明新引用关系；`INDEX.md` 不得声明文档引用关系或链接具体 spec/plan/DR/requirements。

## Warning reference checks

- 矩阵外弱引用（`references` 且有说明）、plan 引用 PRD 或 requirements 作为背景、spec 引用 plan、同版本引用额外写 locator、正文链接疑似证据链但未同步到 `## 文档引用`、`说明` 过短。

## Steps

1. 扫描 `docs/versions/v*/state.json`，解析唯一 active version。
2. 执行归档前置条件检查。
3. 从 active version 的 PRD、spec、plans、DR 提取归档摘要信息。
4. 从 PRD、spec、plans、DR 的 `## 文档引用` 表机械提取 `文档引用摘要`：只读取引用表，不阅读全文；提取 `目标标识` 匹配 `vX.Y.Z:` 或 `project:` 的行写入「跨版本与项目级关系」；提取关系为 `modifies`/`replaces`/`deprecates` 的同版本行写入「本版本强关系」；不根据正文链接补推关系。
5. 在 active version 目录内生成或覆盖 `docs/versions/vX.Y.Z/ARCHIVE.md`。
6. 检查生成后的 `ARCHIVE.md` 中本地相对 Markdown `.md` 链接。
7. 将该版本 `state.json.state` 从 `active` 改为 `archived`，保留 `created_at`，写入 `archived_at`。
8. 创建或更新 `docs/archive/INDEX.md`（每个 archived version 最多一行，链接 `../versions/vX.Y.Z/ARCHIVE.md`）。
9. 检查 `docs/archive/INDEX.md` 本次新增或修改的本地相对 Markdown `.md` 链接。
10. 输出归档结果：归档版本、`ARCHIVE.md` 路径、`INDEX.md` 路径、当前 0 active version、下一步建议 `/sdd:new vX.Y.Z`。

归档后的 `state.json`：

```json
{
  "version": "vX.Y.Z",
  "state": "archived",
  "created_at": "<原值>",
  "archived_at": "YYYY-MM-DDTHH:MM:SSZ"
}
```

## ARCHIVE.md template

```markdown
# Archive：vX.Y.Z

- 状态：archived
- archived_at：YYYY-MM-DDTHH:MM:SSZ
- source_version：docs/versions/vX.Y.Z
- archive_entry：docs/archive/INDEX.md

## 1. 版本摘要

## 2. 关键入口

| 类型 | 链接 | 说明 |
| ---- | ---- | ---- |
| PRD | <存在时 [prd.md](./prd.md)，否则 未发现。> | 产品目标与范围 |
| Spec | <至少一份 spec 链接> | 功能契约 |
| Plans | [plans/](./plans/) | 实施记录 |
| DRs | [decisions/](./decisions/) | 决策记录 |

## 3. Specs

| Spec | 状态 | 摘要 |
| ---- | ---- | ---- |

## 4. Plans

| Plan | 状态 | 关联来源 | 验证摘要 |
| ---- | ---- | -------- | -------- |

## 5. DRs

| DR | class | tag | 状态 | 摘要 |
| -- | ----- | --- | ---- | ---- |

## 6. 文档引用摘要

### 6.1 跨版本与项目级关系

| 来源文档 | 关系 | 目标文档 | 目标标识 | 说明 |
| -------- | ---- | -------- | -------- | ---- |
| 未发现。 | - | - | - | - |

### 6.2 本版本强关系

| 来源文档 | 关系 | 目标文档 | 说明 |
| -------- | ---- | -------- | ---- |
| 未发现。 | - | - | - |

## 7. 验证摘要

## 8. 遗留事项

## 9. 已知限制 / 风险
```

## INDEX.md template

```markdown
# SDD Archive Index

本文件是 archived versions 的全局入口。每个 archived version 最多一行，详情见对应版本的 `ARCHIVE.md`。

| 版本 | 归档时间 | 摘要 | 入口 |
| ---- | -------- | ---- | ---- |
| vX.Y.Z | YYYY-MM-DDTHH:MM:SSZ | <一句话摘要> | [ARCHIVE.md](../versions/vX.Y.Z/ARCHIVE.md) |
```

Rules:

- 只从 `## 文档引用` 表机械提取 `文档引用摘要`，不从正文链接推断新关系。
- 空集合使用固定行 `未发现。`；无法机械提取时使用 `未能机械提取；请查看原始文档。`。
- `INDEX.md` 不链接具体 spec、plan、DR 或 requirements。

## Error handling

- 前置条件失败、`ARCHIVE.md` 生成或链接检查失败时，停止归档，不修改 `state.json`，不更新 `INDEX.md`。
- `state.json` 更新失败时，归档失败，不更新 `INDEX.md`。
- `INDEX.md` 创建或更新失败时，整体归档不算成功；此时版本可能已进入 `archived`，提示用户运行 `/sdd:doctor` 或手动修复全局入口。

## Boundaries

- 不移动版本目录、不创建下一版本、不修改 spec/plan/DR 状态或正文、不修复引用表、不修复 Markdown links、不从正文链接生成正式引用关系、不读取 git log、不审计源码、不把 verification 作为归档阻塞条件。
