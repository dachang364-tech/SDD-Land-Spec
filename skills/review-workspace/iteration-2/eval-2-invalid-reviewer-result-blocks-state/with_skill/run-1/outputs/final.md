`/sdd:review` 在读取任何字段、生成用户回执或改变文档状态前，必须先校验 `doc-reviewer` 返回结果是否为合法 JSON、是否通过 schema 校验，以及 `document_type` / `mode` 是否与输入匹配。

只要其中任一项失败，本次 review 就必须视为 `blocked: true` 的执行失败；调用方必须保留 `draft` 或原有稳定状态，不能继续审批，也不能推进任何文档状态。
