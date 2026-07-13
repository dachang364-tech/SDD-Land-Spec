---
name: dr
description: Create, accept, or dismiss SDD decision records. Use for /sdd:dr <tag> <title>, /sdd:dr accept <id>, or /sdd:dr dismiss <id> <reason>.
---

# /sdd:dr

Manage Decision Records.

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

`spec_change` 只能在不违反 `class`、`plan_required`、`code_required` 的前提下调整。

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.

## Dispatch

1. If first argument is `accept`, run accept mode.
2. If first argument is `dismiss`, run dismiss mode.
3. If first argument is one of the valid tags, run create mode.
4. Otherwise print usage.

## Create mode

Input:

```text
/sdd:dr <tag> <title>
```

Steps:

1. Generate globally increasing DR number from existing `docs/vX.Y.Z/decisions/*.md`.
2. Slugify title.
3. Write `docs/vX.Y.Z/decisions/<tag>-NNNN-<slug>.md` from `skills/dr/references/dr.md.tmpl`.
4. Fill template placeholders, including the selected tag, title, date, and generated number.
5. Derive `class`, `spec_change`, `plan_required`, and `code_required` from the tag defaults table.
6. Initial status is `drafting`.
7. 写入 `影响资产` 或引用 spec、plan、decision 时，使用 Markdown 链接格式，例如 `[spec.md](../specs/spec.md)`、`[<plan-file>.md](../plans/<plan-file>.md)`、`[<dr-id>](./<dr-id>.md)`；章节号和标题可以作为普通文本放在链接后。
8. Output next step:
   - code-class DR: run `/sdd:dr accept <id>`; if `spec_change` is `yes` or `maybe`, first evaluate whether `/sdd:spec` is needed before `/sdd:plan <id>`.
   - document-class DR: run `/sdd:dr accept <id>`, then `/sdd:spec` or the corresponding document Skill.

## Accept mode

Input:

```text
/sdd:dr accept <id>
```

Precondition:

```text
DR 状态为 drafting
```

Steps:

1. Change `drafting → accepted`.
2. Do not write `closed_reason`.
3. Do not write `closed_at`.
4. Do not update supersede chain.
5. Read `class`, `spec_change`, `plan_required`, and `code_required` from the DR.
6. Output next step:
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 决定 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: maybe`：说明是否需要修订 spec；如果需要，先 `/sdd:spec`，否则 `/sdd:plan <id>`。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan`。

## Dismiss mode

Input:

```text
/sdd:dr dismiss <id> <reason>
```

Precondition:

```text
DR 状态为 drafting
```

Steps:

1. Change `drafting → closed`.
2. Set `closed_reason: dismissed`.
3. Set `dismissed_reason` to the provided reason.
4. Set `closed_at` to current UTC timestamp.

Failure behavior:

```text
accepted 或 closed DR 不允许 dismiss；错误时另起 DR supersede。
```
