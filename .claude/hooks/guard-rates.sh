#!/usr/bin/env bash
# PreToolUse hook on Bash: a hard guardrail around the riskiest file in the repo.
# Exit non-zero to block the command. This is a rule the model cannot talk its way past,
# because the harness enforces it, not the model.
set -euo pipefail

CMD="${1:-}"

# If a shell command tries to rewrite rates.js and there is still no rate test, block it.
if echo "$CMD" | grep -Eq "rates\.js"; then
  if ! ls src/legacy/*rates*.test.* >/dev/null 2>&1 && ! ls test/*rates* >/dev/null 2>&1; then
    echo "[guard] Refusing to touch rates.js with no characterization test present."
    echo "[guard] Run the test-writer subagent first, then retry."
    exit 1
  fi
fi

exit 0
