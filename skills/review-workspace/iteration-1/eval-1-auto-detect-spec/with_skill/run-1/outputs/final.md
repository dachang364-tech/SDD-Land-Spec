该路径 `docs/versions/v0.3.0/spec/login.md` 位于受支持的 SDD 文档路径矩阵 `docs/versions/vX.Y.Z/spec/*.md` 内，因此自动识别为 `spec` 文档。

`spec` 的默认 review mode 链路为先执行 `quality`，再执行 `feasibility`。每个 mode 分别调用一次 `doc-reviewer`；命令层仅能在已执行 mode 的有效结果基础上聚合最终用户回执。
