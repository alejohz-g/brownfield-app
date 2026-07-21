#!/usr/bin/env bash
# Spin up git worktrees so several agents can work in parallel without stepping on
# each other. Each worktree is a separate working directory on its own branch, sharing
# one .git. You run one agent per worktree, review each diff, then merge.
#
# Usage: ./scripts/parallel-worktrees.sh
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PARENT="$(dirname "$ROOT")"

# One worktree per independent task from specs/001-stage-waitlist/tasks.md.
TASKS=("t1-rate-tests" "t2-waitlist-store" "t3-service-layer")

for t in "${TASKS[@]}"; do
  dir="$PARENT/wt-$t"
  if [ -d "$dir" ]; then
    echo "exists: $dir"
    continue
  fi
  git worktree add -b "$t" "$dir" >/dev/null
  echo "created worktree: $dir  (branch: $t)"
done

echo
echo "Now open one agent session per directory above and give each its task."
echo "When done, review and merge:"
echo "  git merge t1-rate-tests t2-waitlist-store t3-service-layer"
echo "Clean up with:"
echo "  git worktree remove ../wt-t1-rate-tests   # etc."
