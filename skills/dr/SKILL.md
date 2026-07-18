---
name: dr
description: Create, accept, or dismiss SDD decision records. Use for /sdd:dr <tag> <title>, /sdd:dr accept <id>, or /sdd:dr dismiss <id> <reason>.
---

# /sdd:dr

Manage Decision Records under `docs/versions/vX.Y.Z/decisions/`.

## Tags

```text
fix | feat | chg | arch | spec | doc | typo
```

## Tag defaults

| tag | class | spec_change | plan_required | code_required |
| --- | --- | --- | --- | --- |
| fix | code | no | yes | yes |
| feat | code | yes | yes | yes |
| chg | code | yes | yes | yes |
| arch | code | maybe | yes | yes |
| spec | document | yes | no | no |
| doc | document | maybe | no | no |
| typo | document | no | no | no |

简单实现 bug 可以由用户选择轻量 fix 流程：`tag: fix`、`class: code`、`spec_change: no`、`plan_required: no`、`code_required: yes`。如果修复涉及 API contract、schema、状态机、hook 或跨模块流程变化，不使用轻量 fix，应保持 `plan_required: yes` 并生成新的增量 Implementation Plan。

`spec_change` 和 `plan_required` 只能在不违反 `class` 与 `code_required` 强约束的前提下调整。

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.

## Dispatch

1. If first argument is `accept`, run accept mode.
2. If first argument is `dismiss`, run dismiss mode.
3. If first argument is a valid tag, run create mode.
4. Otherwise print usage.

## Create mode

Input: `/sdd:dr <tag> <title>`

Steps:

1. Scan `docs/versions/vX.Y.Z/decisions/*.md`.
2. Generate version-local increasing DR number `NNN`; if none, use `001`. Fail DR creation when the next DR number would exceed `999`.
3. Slugify title into a non-empty lowercase kebab-case slug using only ASCII lowercase letters, digits, and hyphens.
4. Write `docs/versions/vX.Y.Z/decisions/NNN-<tag>-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
5. `DR ID` 指去掉 `.md` 后的完整 DR basename。
6. 标题标识格式固定为 `DR-NNN-<tag>`，slug 不进入标题标识。
7. 不兼容 `<tag>-NNNN-<slug>` 旧格式，不提供 alias、双写或模糊读取。
8. Derive `class`, `spec_change`, `plan_required`, `code_required` from the tag defaults table.
9. Initial status is `drafting`.
10. If the user chooses lightweight fix, set `plan_required: no` but keep `class: code` and `code_required: yes`.
11. Write the `## 文档引用` table; if no formal reference, use the fixed empty-set row `| 未声明。 | - | - | - | - |`.
   - 引用 project-level requirements：同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
   - 引用跨版本文档：同时写相对 Markdown link 和版本 locator。
   - `## 文档引用` 是 DR 的正式关系来源；`## 影响资产` 只做摘要，不作为正式关系来源。
12. Output next step:
   - code-class DR: run `/sdd:dr accept <id>`; after accept, next step depends on `plan_required` and may be `/sdd:plan <id>` or `/sdd:code <id>`. If `spec_change` is `yes` or `maybe`, first evaluate whether `/sdd:spec` is needed.
   - document-class DR: run `/sdd:dr accept <id>`, then `/sdd:spec` or the corresponding document Skill.

Example: `/sdd:dr accept 001-fix-login-null`

## Accept mode

Input: `/sdd:dr accept <id>`

Precondition: DR 状态为 drafting。

Steps:

1. Change `drafting → accepted`.
2. Do not write `closed_reason`.
3. Do not write `closed_at`.
4. Do not update supersede chain.
5. Read `class`, `spec_change`, `plan_required`, `code_required`.
6. Output next step:
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 运行 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: maybe`：说明是否需要修订 spec；如需要先 `/sdd:spec`，再按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`；如不需要直接按 `plan_required` 进入。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan` 或 `/sdd:code`。

## Dismiss mode

Input: `/sdd:dr dismiss <id> <reason>`

Precondition: DR 状态为 drafting。

Example: `/sdd:dr dismiss 001-fix-login-null <reason>`

Steps:

1. Change `drafting → closed`.
2. Set `closed_reason: dismissed`.
3. Set `dismissed_reason` to the provided reason.
4. Set `closed_at` to current UTC timestamp.

## Supersede rules

- accepted 或 closed DR 需要替代时，应新建 DR，并通过 `supersedes` 和 `## 文档引用` 引用被替代 DR。
- 跨版本替代不回写旧版本文档；closed DR 不重新打开；`superseded` 不作为 DR status，只能通过 `superseded_by` 或新 DR 的 `supersedes` 表达。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 spec/plan、不修改 code、不归档版本。
- `/sdd:dr accept` 不关闭 DR；`/sdd:dr dismiss` 不允许作用于 accepted 或 closed DR。
- DR 的正式关系以 `## 文档引用` 为准，`## 影响资产` 只做摘要。
