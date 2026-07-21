执行 `/sdd:review` 时，命令层必须启动插件提供的 `doc-reviewer` agent，并且只能把 1 个唯一 JSON 对象作为结构化 handoff 载荷传给它，不能用自由文本替代。这个 JSON 至少包含 `document_path`、`document_type`、`mode`、`template_path`、`standard_path`、`repair_policy`、`upstream_paths`、`invocation_source`、`max_rounds`。

每次调用只评审 1 个 `mode`；如果需要多段 review 链路，也必须拆成多次单 mode 调用，再由命令层聚合最终用户回执。
