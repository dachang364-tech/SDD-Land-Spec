---
name: code
description: Execute an SDD implementation plan or eligible lightweight fix DR. Use for /sdd:code.
---

# /sdd:code

Execute an existing Implementation Plan, or execute an accepted lightweight fix DR when `plan_required: no` and `code_required: yes`.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init` or `/sdd:doctor`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or inconsistent state, stop and ask the user to run `/sdd:doctor`.
6. Resolve the input through Work item lookup, then use exactly one execution mode.

## Work item lookup

1. If input is a complete plan basename, match the same `.md` basename and use plan execution mode. This lookup occurs before DR-like validation so names such as `007-001-fix-login-null.md` remain valid plan inputs.
2. If input matches a document-class DR id `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(spec|doc|typo)-[a-z0-9]+(-[a-z0-9]+)*$`, refuse: `文档类 DR 不执行 /sdd:code。`
3. If input is DR-like (starts with three digits and a hyphen) but is not a valid full DR ID, fail explicitly: `无效 DR ID；必须使用 001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>。` Do not fall through to plan or feature-name lookup.
4. If input matches a code-class DR id `^(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])-(fix|feat|chg|arch)-[a-z0-9]+(-[a-z0-9]+)*$`, first check for a matching plan by exact DR ID suffix. If no plan matches, read `docs/versions/vX.Y.Z/decisions/<dr-id>.md` and use lightweight fix DR mode only when DR `tag` is `fix` and `plan_required: no`.
5. If input is `NNN`, match `docs/versions/vX.Y.Z/plans/NNN-*.md` and use plan execution mode.
6. If input is a feature name, match by plan suffix and use plan execution mode.
7. If zero plans match and no eligible lightweight fix DR matches, stop and ask the user to run `/sdd:plan <work-item>` or confirm a lightweight fix DR.
8. If multiple plans match, stop and ask the user to use the plan number, for example `/sdd:code 002`.

## Plan execution mode

- plan 状态必须是 `planned` 或 `coding`。
- 基于 `## 文档引用` 验证 plan `implements` 的 approved spec 或 accepted code-class DR。
- spec mode plan 必须 `implements` 一个 approved spec。
- code-class DR mode plan 必须 `implements` 一个 accepted code-class DR（`accepted`、`class: code`、`plan_required: yes`、`code_required: yes`）。
- document-class DR 不允许进入 `/sdd:code`。

Steps:

1. Change plan 状态从 `planned` 切换为 `coding`; if already `coding`, keep it.
2. Ask the user to choose execution mode:
   - 高质量模式：`superpowers:subagent-driven-development`
   - 快速模式：`superpowers:executing-plans`
3. Execute the plan.
4. Run `superpowers:verification-before-completion`.
5. When execution succeeds and verification 通过后，将 plan 状态切换为 `done`.
6. If the plan implements an accepted code-class DR, change that DR from `accepted` to `closed`.
7. Set DR `closed_reason: committed`.
8. Set DR `closed_at` to current UTC timestamp.
9. If the DR has `supersedes`, update superseded DR files with `superseded_by`.

Failure behavior:

```text
plan remains coding
associated DR remains accepted
```

## Lightweight fix DR mode

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
6. Because no plan exists, no plan status is changed.

Failure behavior:

```text
DR remains accepted
no plan status is changed
```

## Boundaries

- 不创建 active version、不修改 state.json、不创建或修订 PRD/spec/plan/DR 设计正文、不修复 `## 文档引用` 表、不接受或 dismiss DR、不处理 document-class DR、不归档版本。
