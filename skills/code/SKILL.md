---
name: code
description: Execute an SDD implementation plan. Use for /sdd:code <NNN|work-item>.
---

# /sdd:code

Execute an existing Implementation Plan.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Locate the plan from `<NNN|work-item>`.
4. Require plan status to be `planned` or `coding`.
5. If plan has a code-class DR, require DR status to be `accepted`.

## Plan lookup

1. If input is `NNN`, match `docs/vX.Y.Z/plans/NNN-*.md`.
2. If input is a complete plan basename, match the same `.md` basename.
3. If input is feature name or DR ID, match by suffix.
4. If zero plans match, stop and ask the user to run `/sdd:plan <work-item>`.
5. If multiple plans match, stop and ask the user to use plan number, for example `/sdd:code 002`.

## Execution mode

Ask the user to choose:

1. 高质量模式：`superpowers:subagent-driven-development`
2. 快速模式：`superpowers:executing-plans`

## Steps

1. Change plan 状态从 `planned` 切换为 `coding`; if already `coding`, keep it.
2. Execute the plan with the chosen Superpowers sub-skill.
3. Run `superpowers:verification-before-completion`.
4. When execution succeeds and verification 通过后，将 plan 状态切换为 `done`.
5. If plan has a code-class DR, change that DR from `accepted` to `closed`.
6. Set DR `closed_reason: committed`.
7. Set DR `closed_at` to current UTC timestamp.
8. If the DR has `supersedes`, update superseded DR files with `superseded_by`.

## Failure behavior

If execution or verification fails:

```text
plan remains coding
associated DR remains accepted
```
