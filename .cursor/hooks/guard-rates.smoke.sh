#!/usr/bin/env bash
# Local smoke tests for guard-rates.sh (not run by CI).
set -euo pipefail
cd "$(dirname "$0")/../.."
hook=".cursor/hooks/guard-rates.sh"

run_case() {
  local name="$1"
  local payload="$2"
  local expect="$3"
  local out exit_code
  set +e
  out=$(echo "$payload" | "$hook" 2>&1)
  exit_code=$?
  set -e
  if [[ "$expect" == "deny" && "$exit_code" -eq 2 ]]; then
    echo "PASS: $name"
  elif [[ "$expect" == "allow" && "$exit_code" -eq 0 ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expect, exit=$exit_code, out=$out)"
    exit 1
  fi
}

TARGET="src/legacy/rates.ts"
LEGACY="legacy/rates"

run_case "Write" \
  "{\"hook_event_name\":\"preToolUse\",\"tool_name\":\"Write\",\"tool_input\":{\"path\":\"$TARGET\"}}" \
  deny

run_case "StrReplace" \
  "{\"hook_event_name\":\"preToolUse\",\"tool_name\":\"StrReplace\",\"tool_input\":{\"path\":\"$TARGET\"}}" \
  deny

run_case "Delete" \
  "{\"hook_event_name\":\"preToolUse\",\"tool_name\":\"Delete\",\"tool_input\":{\"path\":\"$TARGET\"}}" \
  deny

run_case "Write unrelated" \
  '{"hook_event_name":"preToolUse","tool_name":"Write","tool_input":{"path":"src/routes/bookings.ts"}}' \
  allow

run_case "Shell tool" \
  "{\"hook_event_name\":\"preToolUse\",\"tool_name\":\"Shell\",\"tool_input\":{\"command\":\"sed -i x $TARGET\"}}" \
  deny

run_case "beforeShellExecution" \
  "{\"hook_event_name\":\"beforeShellExecution\",\"command\":\"rm src/$LEGACY.js\"}" \
  deny

run_case "npm test" \
  '{"hook_event_name":"beforeShellExecution","command":"npm test"}' \
  allow

echo "All guard-rates smoke tests passed."
