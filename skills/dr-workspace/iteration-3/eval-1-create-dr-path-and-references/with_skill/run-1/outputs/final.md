创建 `/sdd:dr fix login null` 时，先扫描 `docs/versions/vX.Y.Z/dr/*.md`，从现有文件中生成版本内递增的三位编号 `NNN`；没有既有 DR 时从 `001` 开始。标题会转换为只含 ASCII 小写字母、数字和连字符的 lowercase kebab-case slug，因此 `login null` 变为 `login-null`。

新文件路径为 `docs/versions/vX.Y.Z/dr/NNN-fix-login-null.md`，通用格式是 `docs/versions/vX.Y.Z/dr/NNN-<tag>-<slug>.md`。正式关系只写入 `## 文档引用`：允许的引用类型仅为 `dr`、`plan`、`spec`；`prd` 和 `research` 不能作为正式文档引用。`## 影响资产` 仅用于摘要，不构成正式关系来源。
