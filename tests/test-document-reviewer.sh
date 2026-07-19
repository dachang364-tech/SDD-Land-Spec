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

assert_contains "skills/review/SKILL.md" 'doc Reviewer-Subagent'
assert_contains "skills/review/SKILL.md" '唯一的输入载荷'
assert_contains "skills/review/SKILL.md" '必须只返回一个 JSON 对象'
assert_contains "skills/review/SKILL.md" 'references/reviewer-result.schema.json'
assert_contains "skills/review/SKILL.md" '解析失败、schema 校验失败'
assert_contains "skills/review/SKILL.md" 'Review admission check'
assert_contains "skills/review/SKILL.md" '不进入 review loop、不写入目标文档'
assert_contains "skills/review/SKILL.md" 'iterations: 0'

python3 - <<'PY'
import json
from pathlib import Path

schema = json.loads(Path("skills/review/references/reviewer-result.schema.json").read_text())
properties = schema["properties"]
assert properties["document_type"]["enum"] == ["prd", "spec", "plan"]
assert properties["mode"]["enum"] == ["quality", "feasibility"]
assert schema["additionalProperties"] is False
receipt = properties["user_receipt"]
assert receipt["additionalProperties"] is False
assert receipt["required"] == [
    "document_type",
    "executed_modes",
    "iterations",
    "auto_repairs_summary",
    "remaining_or_confirmation_items",
    "blocked",
    "quality_summary",
]
assert receipt["properties"]["executed_modes"]["minItems"] == 1

valid = {
    "document_type": "spec",
    "mode": "quality",
    "passed": True,
    "blocked": False,
    "score_or_grade": 90,
    "blocking_items": [],
    "auto_repairs": [],
    "remaining_issues": [],
    "requires_user_confirmation": False,
    "candidate_rewrites": [],
    "iterations": 1,
    "reached_max_iterations": False,
    "stopped_for_no_improvement": False,
    "user_receipt": {
        "document_type": "spec",
        "executed_modes": ["quality"],
        "iterations": 1,
        "auto_repairs_summary": [],
        "remaining_or_confirmation_items": [],
        "blocked": False,
        "quality_summary": "passed",
    },
}
assert set(schema["required"]) <= valid.keys()
assert set(receipt["required"]) <= valid["user_receipt"].keys()
assert all(mode in properties["mode"]["enum"] for mode in valid["user_receipt"]["executed_modes"])
assert "summary" not in receipt["required"]
PY

printf 'PASS: document reviewer\n'
