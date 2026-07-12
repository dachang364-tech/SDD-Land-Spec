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
4. Initial status is `drafting`.

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
5. Output next step:
   - code-class DR: `/sdd:plan <id>`
   - document-class DR: run `/sdd:spec` or corresponding document Skill

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
