这个输入会先按完整 plan basename 解析。系统会在当前 active version 的 `docs/versions/vX.Y.Z/plan/` 中查找同名的 `007-001-fix-login-null.md`。

这项 basename lookup 发生在 DR-like 输入校验之前。因此，尽管该名称以三位数字和连字符开头，也不会先被当作 DR ID 拒绝。匹配成功后，进入 plan execution mode。
