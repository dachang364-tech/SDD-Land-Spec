#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_executable() {
  local path="$1"
  [[ -x "$path" ]] || fail "expected file to be executable: $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

sdd_plugin_version() {
  local path="$1"
  awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$path"
}

sdd_json_name() {
  local path="$1"
  awk -F'"' '/"name"[[:space:]]*:/ { print $4; exit }' "$path"
}
