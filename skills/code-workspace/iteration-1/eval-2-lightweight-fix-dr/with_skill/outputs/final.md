这是 lightweight fix DR mode。先确认 DR 为 `accepted`、`class: code`、`tag: fix`、`spec_change: no`、`plan_required: no` 且 `code_required: yes`，然后使用选定的 Superpowers sub-skill 执行本地代码修复。

完成修复后必须运行 `superpowers:verification-before-completion`。只有执行成功且 verification 通过，才将 DR 从 `accepted` 关闭为 `closed`，并写入 `closed_reason: committed` 及当前 UTC 的 `closed_at`。因为该模式没有 plan，所以不会改变任何 plan 状态。
