在 plan execution mode 中，执行失败时不能推进完成状态。失败行为必须保持为：`plan remains coding`，并且 associated DR remains accepted。

因此失败时不能把 plan 从 `coding` 切到 `done`，也不能把关联 code-class DR 从 `accepted` 切到 `closed`，更不能提前写入成功关闭语义。只有执行成功且 verification 通过后，才允许推进这些状态。
