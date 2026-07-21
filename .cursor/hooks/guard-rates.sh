#!/usr/bin/env bash
# beforeShellExecution hook: hard guardrail around the riskiest file in the repo.
# Exit 2 to deny. Parses JSON from stdin per Cursor hook protocol.
set -euo pipefail

input=$(cat)
command=""

if command -v python3 >/dev/null 2>&1; then
  command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || true)
elif command -v node >/dev/null 2>&1; then
  command=$(echo "$input" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).command||'')}catch{console.log('')}})" 2>/dev/null || true)
fi

# If a shell command tries to rewrite rates.js and there is still no rate test, block it.
if echo "$command" | grep -Eq "rates\.js"; then
  if ! ls src/legacy/*rates*.test.* >/dev/null 2>&1 && ! ls test/*rates* >/dev/null 2>&1; then
    echo '{"permission":"deny","user_message":"Refusing to touch rates.js with no characterization test present. Run the test-writer subagent first.","agent_message":"[guard] Run the test-writer subagent first, then retry."}'
    exit 2
  fi
fi

echo '{"permission":"allow"}'
exit 0
