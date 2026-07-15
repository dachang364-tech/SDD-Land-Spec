#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh
[[ -f scripts/lib/sdd-references.sh ]] || fail "missing scripts/lib/sdd-references.sh"
. scripts/lib/sdd-references.sh

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
root="$tmp/project"
mkdir -p "$root/docs/requirements" "$root/docs/versions/v0.1.0"/{specs,plans,decisions} "$root/docs/versions/v0.2.0/specs"
printf '{"version":"v0.1.0","state":"active","created_at":"2026-07-14T00:00:00Z","archived_at":null}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '{"version":"v0.2.0","state":"archived","created_at":"2026-06-01T00:00:00Z","archived_at":"2026-06-30T00:00:00Z"}\n' > "$root/docs/versions/v0.2.0/state.json"
printf '# Requirement\n' > "$root/docs/requirements/rules.md"
printf '# Old\n' > "$root/docs/versions/v0.2.0/specs/old.md"
printf '# PRD\n' > "$root/docs/versions/v0.1.0/prd.md"
cat > "$root/docs/versions/v0.1.0/specs/good.md" <<'DOC'
# Good
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| derives_from | 产品目标 | [prd.md](../prd.md) | - | 当前规格继承产品目标 |
| references | 历史规则 | [old.md](../../v0.2.0/specs/old.md) | v0.2.0:specs/old.md | 历史规格作为设计背景 |
| derives_from | 业务约束 | [rules.md](../../../requirements/rules.md) | project:requirements/rules.md | 项目规则约束当前行为 |
普通导航：[site](https://example.com)、[section](#local)、[code](../../../src/app.ts)。
DOC
scripts/lib/sdd-references.sh parse-table "$root/docs/versions/v0.1.0/specs/good.md" > "$tmp/rows"
[[ "$(wc -l < "$tmp/rows" | tr -d ' ')" == 3 ]] || fail "expected three rows"
assert_contains "$tmp/rows" '"resolved": "docs/versions/v0.1.0/prd.md"'
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/good.md" > "$tmp/good"
[[ ! -s "$tmp/good" ]] || fail "valid references emitted diagnostics"
cat > "$root/docs/versions/v0.1.0/specs/empty.md" <<'DOC'
# Empty
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| 未声明。 | - | - | - | - |
DOC
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/empty.md" > "$tmp/empty"
[[ ! -s "$tmp/empty" ]] || fail "exact empty row failed"
cat > "$root/docs/versions/v0.1.0/plans/001-bad.md" <<'DOC'
# Bad
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| changes | 非法关系 | [good.md](../specs/good.md) | - | 非法关系测试说明 |
| modifies | 实现范围 | [good.md](../specs/good.md) | - | plan 不得修改契约 |
| references | 错误历史 | [old.md](../../v0.2.0/specs/old.md) | v0.2.0:specs/other.md | 链接和 locator 不一致 |
| references | 越界路径 | [escape.md](../../../../outside.md) | - | 越过项目根目录测试 |
| references | 短说明 | [good.md](../specs/good.md) | - | 参考 |
实现依据见 [prd.md](../prd.md)。
DOC
if scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/plans/001-bad.md" > "$tmp/bad"; then fail "expected blocking failure"; fi
for code in invalid_relation plan_strong_relation locator_mismatch unsafe_path short_note body_link_not_declared; do assert_contains "$tmp/bad" "\"code\": \"$code\""; done
[[ "$(grep -c '"code": "plan_strong_relation"' "$tmp/bad")" == 1 ]] || fail "expected one plan strong diagnostic for a resolvable local Markdown target"
assert_contains "$tmp/bad" '"source": "docs/versions/v0.1.0/plans/001-bad.md"'
assert_contains "$tmp/bad" '"original": "../../v0.2.0/specs/old.md"'
assert_contains "$tmp/bad" '"resolved": "docs/versions/v0.2.0/specs/old.md"'
assert_contains "$tmp/bad" '"reason":'
cat > "$root/docs/versions/v0.1.0/prd.md" <<'DOC'
# PRD
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 实现背景 | [001-bad.md](./plans/001-bad.md) | - | PRD 对 plan 的矩阵外弱引用 |
DOC
scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/prd.md" > "$tmp/matrix"
assert_contains "$tmp/matrix" '"code": "direction_matrix_weak"'
assert_contains "$tmp/matrix" '"level": "warning"'
cat > "$root/docs/versions/v0.1.0/plans/strong-unresolvable.md" <<'DOC'
# Strong unresolvable references
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| modifies | 外链目标 | [site](https://example.com) | - | plan 不得修改外部目标 |
| replaces | 非 Markdown 目标 | [code](../../../src/app.ts) | - | plan 不得替代非文档目标 |
| deprecates | 越界目标 | [escape.md](../../../../outside.md) | - | plan 不得废弃越界目标 |
DOC
if scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/plans/strong-unresolvable.md" > "$tmp/strong-unresolvable"; then fail "expected unresolvable plan strong relations to block"; fi
[[ "$(grep -c '"code": "plan_strong_relation"' "$tmp/strong-unresolvable")" == 3 ]] || fail "expected every unresolvable plan strong relation to block"
for locator in \
  'v0.2.0:specs/../specs/old.md' \
  'v0.2.0:specs/./old.md' \
  'v0.2.0:specs//old.md' \
  'v0.2.0:../v0.1.0/specs/good.md'; do
  cat > "$root/docs/versions/v0.1.0/specs/invalid-locator.md" <<DOC
# Invalid locator
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| references | 历史规则 | [old.md](../../v0.2.0/specs/old.md) | $locator | locator 含有非规范路径段 |
DOC
  if scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/invalid-locator.md" > "$tmp/invalid-locator"; then fail "expected invalid version locator to block: $locator"; fi
  assert_contains "$tmp/invalid-locator" '"code": "invalid_locator"'
done
for locator in \
  'project:requirements/../requirements/rules.md' \
  'project:requirements/./rules.md' \
  'project:requirements//rules.md' \
  'project:requirements/../../versions/v0.1.0/prd.md'; do
  cat > "$root/docs/versions/v0.1.0/specs/invalid-project-locator.md" <<DOC
# Invalid project locator
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 | 说明 |
| ---- | -------- | -------- | -------- | ---- |
| derives_from | 业务约束 | [rules.md](../../../requirements/rules.md) | $locator | locator 含有非规范 requirements 路径段 |
DOC
  if scripts/lib/sdd-references.sh validate "$root" "$root/docs/versions/v0.1.0/specs/invalid-project-locator.md" > "$tmp/invalid-project-locator"; then fail "expected invalid project locator to block: $locator"; fi
  assert_contains "$tmp/invalid-project-locator" '"code": "invalid_locator"'
done
scripts/lib/sdd-references.sh extract-archive "$root" "$root/docs/versions/v0.1.0" "$tmp/cross" "$tmp/strong"
assert_contains "$tmp/cross" 'v0.2.0:specs/old.md'
assert_contains "$tmp/cross" 'project:requirements/rules.md'
assert_contains "$tmp/strong" '| plans/001-bad.md | modifies | [good.md](../specs/good.md) | plan 不得修改契约 |'
cat > "$root/docs/versions/v0.1.0/specs/malformed.md" <<'DOC'
# Malformed
## 文档引用
| 关系 | 当前范围 | 目标文档 | 目标标识 |
| ---- | -------- | -------- | -------- |
| references | 缺失列 | [old.md](../../v0.2.0/specs/old.md) | v0.2.0:specs/old.md |
DOC
scripts/lib/sdd-references.sh extract-archive "$root" "$root/docs/versions/v0.1.0" "$tmp/mixed-cross" "$tmp/mixed-strong"
assert_contains "$tmp/mixed-cross" '| 未能机械提取；请查看原始文档。 | - | - | - | - |'
assert_contains "$tmp/mixed-strong" '| 未能机械提取；请查看原始文档。 | - | - | - |'
printf 'PASS: reference validation\n'
