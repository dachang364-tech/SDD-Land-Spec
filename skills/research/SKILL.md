---
name: research
description: 创建或更新项目级 SDD research 文档。用户执行 `/sdd:research <topic>` 时使用。
---

# /sdd:research

在 active version 下创建或更新 research 文档。

## 前置条件

1. 读取 `docs/CONSTITUTION.md`；如果缺失，停止并提示用户先运行 `/sdd:init`。
2. 要求 `docs/versions/` 存在；如果缺失，停止并提示用户先运行 `/sdd:init`。
3. 扫描 `docs/versions/v*/state.json`。
4. 如果 0 active version，停止并提示用户先运行 `/sdd:new vX.Y.Z`。
5. 如果存在多个 active version 或状态不一致，停止并报告项目状态不一致。
6. 只读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 下的模板与标准。
7. 生成前必须读取 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md` 和 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/quality.standard.md`。
8. 如果 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 下必要文件缺失，则直接失败并提示重新执行 `/sdd:init` 或手工修复项目模板资产。
9. archived version 禁止执行。

## 对话

1. 确认 research 主题。
2. 确认 research 类型 `<type>`、研究目的与信息来源。
3. 确认后续可能消费该研究结论的 PRD、spec、plan 或 DR。
4. 如果同名文档已存在，先向用户确认是否更新同一文档。

## 输出路径

```text
docs/versions/vX.Y.Z/research/<type>-<YYYY-MM-DD>-<slug>.md
```

生成必须使用 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/template.md`。

- `<type>` 使用 kebab-case。
- `<date>` 固定使用 `YYYY-MM-DD`。
- research 文档没有状态机制。
- 不要求 `## 文档引用` 表，是否包含由模板与标准定义。
- 同名文档存在时，用户确认后可直接更新。

## Review

- 写入前显式判断目标文件：目标文件不存在：视为 create；存在：视为 update。
- create：文档生成仍由当前 Skill 负责；成功写入后由 `PostToolUse Hook` 触发 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。`research` 的 runner mode 为 `quality`；review 结果若阻断、需要用户确认、无有效结果或项目模板资产缺失，则不得绕过 gate 推进后续流程。
- update：修改已有文档时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
- 当前 Skill 不直接调用 `doc-reviewer`；自动 review 的触发责任下沉到 `PostToolUse Hook`，手工复审入口保留为 `/sdd:review`。
- reviewer 只消费当前项目 `${CLAUDE_PROJECT_DIR}/.sdd/templates/research/` 中的模板与标准。
- research 的结构、章节和措辞必须以项目运行时模板为准，不降级回 Plugin 内置模板。

## 边界

- 不创建 active version、不修改 state.json、不创建或修改 PRD/spec/plan/DR、不关闭 DR、不生成 plan、不执行 code、不归档版本。
