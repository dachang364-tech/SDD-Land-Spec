执行 `/sdd:dr accept 001-fix-login-null` 时，先只按完整 `DR ID` 精确查找 `docs/versions/vX.Y.Z/dr/001-fix-login-null.md`，不允许部分编号、别名或模糊匹配。目标文档必须精确存在于 active version，且当前状态必须是 `drafting`。

校验通过后，将状态从 `drafting → accepted`。随后读取 `class`、`spec_change`、`plan_required`、`code_required` 来决定下一步：如果是 code-class 且需要 spec 变更，先 `/sdd:spec`，再根据 `plan_required` 进入 `/sdd:plan <id>` 或 `/sdd:code <id>`；如果 `spec_change: no`，则直接按 `plan_required` 决定走 `/sdd:plan <id>` 还是 `/sdd:code <id>`。
