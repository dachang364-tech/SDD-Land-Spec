#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/test-common.sh

run_hook() {
  local project_root="$1"
  local target="$2"
  (
    cd "$project_root"
    CLAUDE_PLUGIN_ROOT="$OLDPWD" \
    CLAUDE_PROJECT_DIR="$project_root" \
    printf '{"tool_input":{"file_path":"%s"}}' "$target" | "$OLDPWD/scripts/hooks/post-tool-use.sh"
  )
}

tmp_project="$(mktemp -d)"
trap 'rm -rf "$tmp_project" /tmp/sdd-post-hook.out /tmp/sdd-post-hook.err' EXIT

mkdir -p "$tmp_project/.sdd/templates/research" "$tmp_project/.sdd/templates/prd" "$tmp_project/.sdd/templates/spec" "$tmp_project/.sdd/templates/plan" "$tmp_project/.sdd/templates/dr"
printf '# research template\n' > "$tmp_project/.sdd/templates/research/template.md"
printf '# research quality\n' > "$tmp_project/.sdd/templates/research/quality.standard.md"
printf '# prd template\n' > "$tmp_project/.sdd/templates/prd/template.md"
printf '# prd quality\n' > "$tmp_project/.sdd/templates/prd/quality.standard.md"
printf '# spec template\n' > "$tmp_project/.sdd/templates/spec/template.md"
printf '# spec quality\n' > "$tmp_project/.sdd/templates/spec/quality.standard.md"
printf '# spec feasibility\n' > "$tmp_project/.sdd/templates/spec/feasibility.standard.md"
printf '# plan template\n' > "$tmp_project/.sdd/templates/plan/template.md"
printf '# plan quality\n' > "$tmp_project/.sdd/templates/plan/quality.standard.md"
printf '# plan feasibility\n' > "$tmp_project/.sdd/templates/plan/feasibility.standard.md"
printf '# dr template\n' > "$tmp_project/.sdd/templates/dr/template.md"
printf '# dr quality\n' > "$tmp_project/.sdd/templates/dr/quality.standard.md"

run_hook "$tmp_project" "docs/versions/v0.1.0/prd/prd.md" >/tmp/sdd-post-hook.out 2>/tmp/sdd-post-hook.err
[[ ! -s /tmp/sdd-post-hook.err ]] || fail "expected relative path success to keep stderr empty"

run_hook "$tmp_project" "$tmp_project/docs/versions/v0.1.0/spec/chat-agent-mvp-spec.md" >/tmp/sdd-post-hook.out 2>/tmp/sdd-post-hook.err
[[ ! -s /tmp/sdd-post-hook.err ]] || fail "expected absolute path success to keep stderr empty"

printf 'PASS: post-tool-use hook\n'
