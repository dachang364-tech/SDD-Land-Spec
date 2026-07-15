---
name: status
description: Show current SDD version status and next-step guidance. Use for /sdd:status.
---

# /sdd:status

展示 SDD 项目当前生命周期状态、active version 内容概览和下一步建议。轻量状态查看入口，不是诊断或修复工具。

## Steps

1. Read `docs/CONSTITUTION.md`; if missing, report the project is not initialized, suggest `/sdd:init`, then stop.
2. Check `docs/versions/` exists; if missing, report incomplete structure, suggest `/sdd:init` or `/sdd:doctor`, then stop.
3. 扫描 docs/versions/v*/state.json。
4. If any version directory is missing `state.json`, has unparseable JSON, is missing required `version`, `state`, `created_at`, or `archived_at` fields, has a `version` mismatch, has an illegal `state`, or violates the active/archived `archived_at` rule, report a consistency error, suggest `/sdd:doctor`, then stop.
5. If 0 active version:
   - 输出项目已初始化。
   - 输出 `Active version：未发现`。
   - If archived versions exist, list their version and `archived_at`.
   - 下一步建议：`/sdd:new vX.Y.Z`。
   - 不扫描 `prd.md`、`specs/`、`plans/`、`decisions/`。
6. If 1 active version:
   - 输出 active version 路径，例如 `docs/versions/v0.3.0/`。
   - 输出 version state：`active`。
   - Check `prd.md` existence.
   - Scan `specs/*.md`, list each spec file and its Markdown 头部状态。
   - Scan `plans/*.md`, list each plan file and status.
   - Scan `decisions/*.md`, group by `drafting`, `accepted`, `closed`; for `closed` show `closed_reason` / `superseded_by` if present.
   - 输出下一步建议。
7. If multiple active versions (发现多个 active version):
   - 输出一致性错误，列出所有 active version。
   - 下一步建议：`/sdd:doctor`。

## Boundaries

- 不修复 state.json、不创建版本、不归档版本、不检查 Markdown links、不检查引用表语义、不诊断源码、不读取 git log。
