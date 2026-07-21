`001-doc-fix-typo` 是 document-class DR ID，因为 tag 为 `doc`。在 work item lookup 阶段，`/sdd:code` 必须直接拒绝并输出：`文档类 DR 不执行 /sdd:code。`

document-class DR 不允许进入代码执行流程，也不能进入 plan execution mode 或 lightweight fix DR mode。它应由文档相关流程处理，而不是由 `/sdd:code` 执行。
