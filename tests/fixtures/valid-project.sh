#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/versions/v0.1.0/research" "$root/docs/versions/v0.1.0/prd" "$root/docs/versions/v0.1.0/spec" "$root/docs/versions/v0.1.0/plan" "$root/docs/versions/v0.1.0/dr" "$root/docs/archive"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '# PRD\n' > "$root/docs/versions/v0.1.0/prd/prd.md"
printf '# Functional Specification\n\n- 状态：approved\n' > "$root/docs/versions/v0.1.0/spec/spec.md"
printf '# Plan\n\n- 状态：planned\n' > "$root/docs/versions/v0.1.0/plan/001-feature-login.md"
printf '# DR-001-fix：Login null\n\n- 状态：accepted\n- class：code\n- tag：fix\n- spec_change：no\n- plan_required：yes\n- code_required：yes\n- closed_reason: null\n' > "$root/docs/versions/v0.1.0/dr/001-fix-login-null.md"
