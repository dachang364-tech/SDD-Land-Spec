#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

assert_file_exists "skills/review/SKILL.md"
assert_file_exists "skills/review/references/reviewer-result.schema.json"
assert_contains "skills/review/SKILL.md" '文档路径'
assert_contains "skills/review/SKILL.md" '文档类型'
assert_contains "skills/review/SKILL.md" '当前 mode'
assert_contains "skills/review/SKILL.md" '最大循环轮次'
assert_contains "skills/review/SKILL.md" '达到最大循环轮次'
assert_contains "skills/review/SKILL.md" '进入需要用户确认的状态'
assert_contains "skills/review/SKILL.md" '无法继续产生有效改进'
assert_contains "skills/review/SKILL.md" '默认只向用户返回 1 份聚合后的简洁回执'

python3 - <<'PY'
import json
from pathlib import Path

schema = json.loads(Path("skills/review/references/reviewer-result.schema.json").read_text())
properties = schema["properties"]
assert properties["document_type"]["enum"] == ["prd", "spec", "plan"]
assert properties["mode"]["enum"] == ["quality", "feasibility"]
assert "user_receipt" in schema["required"]
assert properties["user_receipt"]["required"] == ["summary", "blocked"]
PY

printf 'PASS: document reviewer\n'
