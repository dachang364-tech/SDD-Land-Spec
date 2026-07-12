#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/v0.1.0/specs" "$root/docs/v0.2.0/specs" "$root/docs/archive/v0.0.1"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '# Functional Specification\n\n- 状态：draft\n' > "$root/docs/v0.1.0/specs/spec.md"
