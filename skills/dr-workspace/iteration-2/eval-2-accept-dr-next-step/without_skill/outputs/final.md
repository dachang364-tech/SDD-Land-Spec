系统需要找到对应的 DR 文档并确认它还处于可接受状态，然后把它标记为 `accepted`。

接受之后的下一步要看这个 DR 属于代码类还是文档类，以及是否还需要 spec、plan 或代码执行；也就是根据 `class`、`spec_change`、`plan_required`、`code_required` 决定继续走 `/sdd:spec`、`/sdd:plan` 或 `/sdd:code`。
