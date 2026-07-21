该输入以三位数字和连字符开头，属于 DR-like 输入，但 `001-fix-login` 不是完整有效 DR ID，因为缺少符合 lowercase kebab-case 的完整 slug 结构要求。系统必须直接失败并提示：`无效 DR ID；必须使用 001..999-<fix|feat|chg|arch|spec|doc|typo>-<lowercase-kebab-slug>。`

这种 DR-like 但无效的输入不能继续回退到 plan lookup，也不能回退到 feature-name lookup，因此不会进入 plan execution mode、lightweight fix DR mode 或任何 execution mode。
