---
name: prd
description: Create the product requirements document. Use for /sdd:prd.
---

# /sdd:prd

Create or update `docs/versions/vX.Y.Z/prd/prd.md` for the unique active version.

## Preconditions

1. Read `docs/CONSTITUTION.md`; if missing, stop and ask the user to run `/sdd:init`.
2. Require `docs/versions/` to exist; if missing, stop and ask the user to run `/sdd:init`.
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. If 0 active version, stop and ask the user to run `/sdd:new vX.Y.Z`.
5. If multiple active versions or an inconsistent state, stop and report the project state is inconsistent.
6. Target file is `docs/versions/vX.Y.Z/prd/prd.md`.
7. 如果目标 version 已 archived，则直接失败。

## Dialogue

1. 与用户讨论当前版本的业务背景、目标用户、问题陈述、范围和成功标准。
2. 确认是否需要引用本版本下的 research 文档作为背景材料。
3. 如果 `prd/prd.md` 已存在，先与用户讨论并确认后更新同一文件。

## Output

Write `docs/versions/vX.Y.Z/prd/prd.md` using `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md`.

- 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md` 和同目录下的质量标准。
- 生成前必须读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/template.md` 和 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/quality.standard.md`。
- 如果 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/` 下必要文件缺失，则直接失败并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
- 一个版本只有一个正式 PRD：`docs/versions/vX.Y.Z/prd/prd.md`。
- 如果 `prd/prd.md` 不存在，则创建。
- 如果 `prd/prd.md` 已存在，默认不直接覆盖；必须先与用户确认，再更新同一文件。
- `prd` 不走 `DR` 变更门。
- 不强制 `## 文档引用` 表，由模板与标准定义结构要求。
- 不写 `- 状态：` 行。

## Review

- 成功写入后由运行时 Hook 触发 review；当前流程会通过 `PostToolUse Hook` 自动完成 review，并统一使用 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。
- 如需再次人工复审或查看回执，请调用 `/sdd:review <doc-path>`；其内部继续沿用 `/sdd:review` 的 `doc-reviewer` agent JSON 调用合同。
- runner 对 `prd` 只执行 `quality`，不接入 `feasibility`。
- reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/prd/` 中的模板与标准。
- 用户确认并完成有效复审前，不得绕过该结果推进流程；如果项目模板资产缺失，则直接失败，不降级到 Plugin 内置资产。

## Boundaries

- 不创建 active version、不修改 state.json、不创建 spec/plan/DR、不归档版本。
