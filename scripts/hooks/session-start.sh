#!/usr/bin/env bash
set -euo pipefail

missing=0
if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])superpowers([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 superpowers；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi

if ! claude plugin list 2>/dev/null | grep -Eq '(^|[[:space:]])spec-kit([[:space:]]|$)'; then
  printf 'SDD Plugin: 缺少依赖 spec-kit；请按 README 安装说明手动安装该插件。\n' >&2
  missing=1
fi

if [[ ! -f docs/CONSTITUTION.md ]]; then
  printf 'SDD Plugin: 当前项目尚未初始化；如需使用 SDD 工作流，请运行 /sdd:init。\n' >&2
fi

exit 0
