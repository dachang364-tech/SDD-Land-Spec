#!/usr/bin/env bash
set -euo pipefail
root="$1"
mkdir -p "$root/docs/versions/v0.1.0/spec" "$root/docs/versions/v0.2.0/spec" "$root/docs/archive"
printf '# CONSTITUTION\n' > "$root/docs/CONSTITUTION.md"
printf '{\n  "version": "v0.1.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.1.0/state.json"
printf '{\n  "version": "v0.2.0",\n  "state": "active",\n  "created_at": "2026-07-14T00:00:00Z",\n  "archived_at": null\n}\n' > "$root/docs/versions/v0.2.0/state.json"
printf '# Functional Specification\n\n- 状态：draft\n' > "$root/docs/versions/v0.1.0/spec/spec.md"
