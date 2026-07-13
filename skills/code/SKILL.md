---
name: code
description: Execute an SDD implementation plan or eligible lightweight fix DR. Use for /sdd:code.
---

# /sdd:code

Execute an existing Implementation Plan, or execute an accepted lightweight fix DR when `plan_required: no` and `code_required: yes`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Resolve the unique active version directory.
3. Locate the plan from `<NNN|work-item>`.
4. Require plan status to be `planned` or `coding`.
5. If plan has a code-class DR, require DR status to be `accepted`.
6. If plan has a code-class DR, require DR `class` to be `code`.
7. If plan has a code-class DR, require DR `code_required: yes`.

## Work item lookup

1. If input is `NNN`, match `docs/vX.Y.Z/plans/NNN-*.md` and use plan execution mode.
2. If input is a complete plan basename, match the same `.md` basename and use plan execution mode.
3. If input is feature name, match by plan suffix and use plan execution mode.
4. If input matches a code-class DR id `^(fix|feat|chg|arch)-[0-9]{4}-[a-z0-9-]+$`, first check for a matching plan by suffix. If no plan matches, read `docs/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when `plan_required: no`.
5. If zero plans match and no eligible lightweight fix DR matches, stop and ask the user to run `/sdd:plan <work-item>` or confirm a lightweight fix DR.
6. If multiple plans match, stop and ask the user to use plan number, for example `/sdd:code 002`.

## Lightweight fix DR mode

This mode is only for simple implementation bugs that conform to the existing spec and do not require an Implementation Plan.

Preconditions:

```text
DR 状态为 accepted
DR `class` is `code`
DR `tag` is `fix`
DR `spec_change: no`
DR `plan_required: no`
DR `code_required: yes`
```

Steps:

1. Execute the local code fix with the chosen Superpowers sub-skill.
2. Run `superpowers:verification-before-completion`.
3. When execution succeeds and verification passes, change the DR from `accepted` to `closed`.
4. Set DR `closed_reason: committed`.
5. Set DR `closed_at` to current UTC timestamp.
6. Because no plan exists in lightweight fix DR mode, no plan status is changed.

Failure behavior:

```text
DR remains accepted
no plan status is changed
```

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
