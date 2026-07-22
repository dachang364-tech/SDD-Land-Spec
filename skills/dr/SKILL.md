---
name: dr
description: 创建、接受或驳回 SDD Decision Record。用户执行 `/sdd:dr <tag> <title>`、`/sdd:dr accept <id>` 或 `/sdd:dr dismiss <id> <reason>` 时使用。
---

# /sdd:dr

在 `docs/versions/vX.Y.Z/dr/` 下管理 Decision Record。

## 标签

```text
fix | feat | chg | arch | spec | doc | typo
```

## 标签默认值

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

## 前置条件

1. 读取 `docs/CONSTITUTION.md`；如果缺失，停止并提示用户先运行 `/sdd:init`。
2. 要求 `docs/versions/` 存在；如果缺失，停止并提示用户先运行 `/sdd:init`。
3. 扫描 docs/versions/v*/state.json 发现唯一 active version。
4. 如果 0 active version，停止并提示用户先运行 `/sdd:new vX.Y.Z`。
5. 如果存在多个 active version 或状态不一致，停止并报告项目状态不一致。
6. 如果目标 version 已 archived，则直接失败。

## 分发

1. 如果第一个参数是 `accept`，进入 accept mode。
2. 如果第一个参数是 `dismiss`，进入 dismiss mode。
3. 如果第一个参数是合法 tag，进入 create mode。
4. 否则输出用法。

## Create 模式

输入：`/sdd:dr <tag> <title>`

步骤：

1. 扫描 `docs/versions/vX.Y.Z/dr/*.md`。
2. 生成版本内递增 DR 编号 `NNN`；如果还没有 DR，则使用 `001`。若下一个编号会超过 `999`，则直接失败。
3. 将标题 slugify 为非空 lowercase kebab-case，只允许 ASCII 小写字母、数字和连字符。
4. 基于 `skills/dr/references/dr.md.tmpl` 写出 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。
5. `DR ID` 指去掉 `.md` 后的完整 DR basename。
6. 标题标识格式固定为 `DR-NNN-<tag>`，slug 不进入标题标识。
7. 不兼容 `<tag>-NNNN-<slug>` 旧格式，不提供 alias、双写或模糊读取。
8. 从标签默认值表推导 `class`、`spec_change`、`plan_required`、`code_required`。
9. 初始状态为 `drafting`。
10. 如果用户选择 lightweight fix，则将 `plan_required` 设为 `no`，但保持 `class: code` 和 `code_required: yes`。
11. 写入 `## 文档引用` 表；如果没有正式引用，使用固定空集合行 `| 未声明。 | - | - | - | - |`。
   - DR 的正式文档引用只允许 `dr / plan / spec`。
   - 不允许 `prd / research`。
   - 引用 project-level requirements：同时写相对 Markdown link 和 `project:requirements/<file>.md` locator。
   - 引用跨版本文档：同时写相对 Markdown link 和版本 locator。
   - `## 文档引用` 是 DR 的正式关系来源；`## 影响资产` 只做摘要，不作为正式关系来源。
12. create mode 只创建新 DR 文件，因此本次写入结果恒为 create，不存在 update 分支。
13. create：文档生成仍由当前 Skill 负责；成功写入后由 `PostToolUse Hook` 触发 `scripts/lib/sdd-review-runner.sh` 这个共享 review runner。`dr` 的 runner mode 为 `quality`；review 结果若阻断、需要用户确认、无有效结果或项目模板资产缺失，则不得绕过 gate 推进后续流程。
14. 当前 Skill 不直接调用 `doc-reviewer`；自动 review 的触发责任下沉到 `PostToolUse Hook`，手工复审入口保留为 `/sdd:review`。
15. `dr` 的 runner mode 为 `quality`；机器结果必须先通过 schema 校验。
16. 输出下一步：
   - code-class DR：运行 `/sdd:dr accept <id>`；之后根据 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`。如果 `spec_change` 是 `yes` 或 `maybe`，先判断是否需要 `/sdd:spec`。
   - document-class DR：运行 `/sdd:dr accept <id>`，然后进入 `/sdd:spec` 或对应文档 Skill。

示例：`/sdd:dr accept 001-fix-login-null`

## Accept 模式

输入：`/sdd:dr accept <id>`

前置条件：`<id>` 必须是有效完整 `DR ID`：`001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>`，并且对应 active version 的 `dr/<id>.md` 精确存在且状态为 drafting。

查找与失败规则：只按完整 `DR ID` 精确查找 `docs/versions/vX.Y.Z/dr/<id>.md`，不使用 alias、部分编号、tag/slug 模糊匹配或自动补全。无效 DR ID、缺失 DR 或旧格式 `<tag>-NNNN-<slug>` 均必须显式失败，不得修改任何文件。

步骤：

1. 将 `drafting → accepted`。
2. 不写 `closed_reason`。
3. 不写 `closed_at`。
4. 不更新 supersede chain。
5. 读取 `class`、`spec_change`、`plan_required`、`code_required`。
6. 这属于 update：修改已有 DR 时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。
7. 输出下一步：
   - `class: code` 且 `spec_change: yes`：先运行 `/sdd:spec`，然后根据 `plan_required` 运行 `/sdd:plan <id>` 或 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: yes`：运行 `/sdd:plan <id>`。
   - `class: code` 且 `spec_change: no`、`plan_required: no`：运行 `/sdd:code <id>`。
   - `class: code` 且 `spec_change: maybe`：说明是否需要修订 spec；如需要先 `/sdd:spec`，再按 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`；如不需要直接按 `plan_required` 进入。
   - `class: document`：运行 `/sdd:spec` 或对应文档 Skill，不进入 `/sdd:plan` 或 `/sdd:code`。

## Dismiss 模式

输入：`/sdd:dr dismiss <id> <reason>`

前置条件：`<id>` 必须是有效完整 `DR ID`：`001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>`，并且对应 active version 的 `dr/<id>.md` 精确存在且状态为 drafting。

查找与失败规则：只按完整 `DR ID` 精确查找 `docs/versions/vX.Y.Z/dr/<id>.md`，不使用 alias、部分编号、tag/slug 模糊匹配或自动补全。无效 DR ID、缺失 DR 或旧格式 `<tag>-NNNN-<slug>` 均必须显式失败，不得修改任何文件。

示例：`/sdd:dr dismiss 001-fix-login-null <reason>`

步骤：

1. 将 `drafting → closed`。
2. 设置 `closed_reason: dismissed`。
3. 将 `dismissed_reason` 设为用户提供的原因。
4. 将 `closed_at` 设为当前 UTC 时间戳。
5. 这属于 update：修改已有 DR 时，不自动执行 review。回执统一为“文档已更新；如需复审，请执行 `/sdd:review <doc-path>`”。

## Supersede 规则

- accepted 或 closed DR 需要替代时，应新建 DR，并通过 `supersedes` 和 `## 文档引用` 引用被替代 DR。
- 若同名 `DR` 已终态，不能回写，必须新建新的 `DR`。
- 跨版本替代不回写旧版本文档；closed DR 不重新打开；`superseded` 不作为 DR status，只能通过 `superseded_by` 或新 DR 的 `supersedes` 表达。

## 边界

- 不创建 active version、不修改 state.json、不创建 spec/plan、不修改 code、不归档版本。
- `/sdd:dr accept` 不关闭 DR；`/sdd:dr dismiss` 不允许作用于 accepted 或 closed DR。
- DR 的正式关系以 `## 文档引用` 为准，`## 影响资产` 只做摘要。
