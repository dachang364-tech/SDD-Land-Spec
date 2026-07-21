系统会生成一个新的 DR 文件，编号按当前版本里的已有 DR 顺序递增，标题 `login null` 会整理成 `login-null` 这样的 kebab-case。

输出位置在 `docs/versions/vX.Y.Z/dr/` 目录下，文件名类似 `NNN-fix-login-null.md`。正式文档引用应限定在决策与实施相关文档范围内，例如 DR、plan、spec，不应把 PRD 或 research 当作正式关系来源。
