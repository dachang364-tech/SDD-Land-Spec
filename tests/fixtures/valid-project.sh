#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/v0.1.0/specs" "$root/docs/v0.1.0/plans" "$root/docs/v0.1.0/decisions" "$root/docs/archive" "$root/docs/requirements"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '# PRD\n' > "$root/docs/v0.1.0/prd.md"
printf '# Functional Specification\n\n- 状态：approved\n' > "$root/docs/v0.1.0/specs/spec.md"
printf '# Plan\n\n- 状态：planned\n' > "$root/docs/v0.1.0/plans/001-feature-login.md"
printf '# DR\n\n- 状态：accepted\n- tag：fix\n- closed_reason: null\n' > "$root/docs/v0.1.0/decisions/fix-0001-login-null.md"
