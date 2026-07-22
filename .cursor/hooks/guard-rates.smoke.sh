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

run_case "Shell tool with rates.ts path" \
  "{\"hook_event_name\":\"preToolUse\",\"tool_name\":\"Shell\",\"tool_input\":{\"command\":\"sed -i x $TARGET\"}}" \
  deny

run_case "beforeShellExecution rates.js" \
  "{\"hook_event_name\":\"beforeShellExecution\",\"command\":\"rm src/$LEGACY.js\"}" \
  deny

run_case "beforeShellExecution extensionless dist path" \
  '{"hook_event_name":"beforeShellExecution","command":"node -e \"require('"'"'./dist/legacy/rates'"'"')\""}' \
  deny

run_case "beforeShellExecution concatenation bypass" \
  '{"hook_event_name":"beforeShellExecution","command":"node -e \"require('"'"'./dist/legacy/'"'"' + '"'"'rates'"'"')\""}' \
  deny

run_case "beforeShellExecution split-string bypass" \
  '{"hook_event_name":"beforeShellExecution","command":"node -e \"require('"'"'./dist/legacy/'"'"' + '"'"'ra'"'"' + '"'"'tes'"'"')\""}' \
  deny

run_case "beforeShellExecution rateFor call" \
  '{"hook_event_name":"beforeShellExecution","command":"node -e \"const f=require('"'"'./dist/legacy/rates'"'"').rateFor; console.log(f('"'"'stage-a'"'"','"'"'2026-07-04T09'"'"',5))\""}' \
  deny

run_case "beforeShellExecution shell redirect write" \
  "{\"hook_event_name\":\"beforeShellExecution\",\"command\":\"cat > $TARGET <<'EOF'\"}" \
  deny

run_case "beforeShellExecution build verify command" \
  "$(python3 - <<'PY'
import json
cmd = """cd /Users/omar.henao/Documents/Globant/brownfield-app && npm run build && node -e "
const { rateFor } = require('./dist/legacy/rates');
console.log(rateFor('stage-a', '2026-07-04T09', 5));
"
"""
print(json.dumps({"hook_event_name": "beforeShellExecution", "command": cmd}))
PY
)" \
  deny

run_case "preToolUse Read unrelated" \
  '{"hook_event_name":"preToolUse","tool_name":"Read","tool_input":{"path":"src/server.ts"}}' \
  allow

run_case "npm test" \
  '{"hook_event_name":"beforeShellExecution","command":"npm test"}' \
  allow

run_case "npm run build alone" \
  '{"hook_event_name":"beforeShellExecution","command":"npm run build"}' \
  allow

run_case "npm run dev alone" \
  '{"hook_event_name":"beforeShellExecution","command":"npm run dev"}' \
  allow

run_case "curl POST booking bypass" \
  '{"hook_event_name":"beforeShellExecution","command":"curl -s -X POST http://localhost:3000/bookings -H \"Content-Type: application/json\" -d \"{\\\"production\\\":\\\"x\\\",\\\"stage\\\":\\\"stage-a\\\",\\\"slot\\\":\\\"2026-07-04T09\\\",\\\"crewSize\\\":5}\""}' \
  deny

run_case "curl GET bookings allowed" \
  '{"hook_event_name":"beforeShellExecution","command":"curl -s http://localhost:3000/bookings"}' \
  allow

echo "All guard-rates smoke tests passed."
