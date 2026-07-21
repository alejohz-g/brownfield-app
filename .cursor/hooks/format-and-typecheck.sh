#!/usr/bin/env bash
# afterFileEdit hook: runs after the agent edits a file.
# Output is fed back to the agent so type errors get fixed in the same turn.
set -euo pipefail

echo "[hook] formatting and type-checking after edit..."

# Format (no-op if prettier is absent; the hook should never block on tooling gaps).
if command -v npx >/dev/null 2>&1; then
  npx --no-install prettier --write . >/dev/null 2>&1 || true
fi

# Type check. A non-zero exit here is intentional: it tells the agent it broke types.
if command -v npx >/dev/null 2>&1; then
  npx --no-install tsc --noEmit -p tsconfig.json
fi

echo "[hook] ok"
