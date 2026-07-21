# shoot-scheduling-api

A small, deliberately legacy scheduling service for booking soundstages for shoots. It
exists to give the team a realistic brownfield repo to practice driving a coding agent
against in Cursor.

## Run it

```
npm install
npm run dev      # API on http://localhost:3000
```

Try it:

```
curl -X POST localhost:3000/bookings \
  -H 'content-type: application/json' \
  -d '{"production":"stranger-things-s5","stage":"stage-a","slot":"2026-07-04T09","crewSize":3}'
```

## The tech debt is the point

This repo carries intentional debt: one fat route handler, no tests, an untyped legacy
rate-card module with order-dependent rules, and three inconsistent error shapes. That
gives the workshop something real to refactor.

## The agent tooling is the lesson

Open this folder in **Cursor** and look at how it is set up. Each file demonstrates one
concept from the workshop:

**Cursor:**
- `AGENTS.md`: always-loaded config and context.
- `.cursor/rules/`: always-applied and file-scoped rules.
- `.cursor/skills/`: on-demand and user-invoked skills (production-domain, rate-check, ship-check).
- `.cursor/agents/`: subagent prompts (test-writer, security-reviewer, task-worker).
- `.cursor/hooks.json` and `.cursor/hooks/`: lifecycle hooks.
- `.cursor/mcp.json`: external tools over MCP.

**Shared:**
- `specs/`: spec-driven development (spec, plan, tasks, constitution).
- `scripts/parallel-worktrees.sh`: parallel work with git worktrees.
- `docs/cursor-capstone-prompts.md`: copy-paste Cursor prompts for the waitlist capstone.

Each of these maps to one building block from the coding-agents workshop. Open the repo in
Cursor and look at how each file is written — that wiring is the lesson.

## MCP servers (optional)

`.cursor/mcp.json` wires two MCP servers the agent can use:

- **github** — the official GitHub MCP server, run via Docker, to read issues, PRs and repos.
- **miro-mcp** — the Miro MCP server for board and diagram access.

To enable github, set the credentials in your environment (referenced from
`.cursor/mcp.json`, never hardcoded):

```
cp .env.example .env      # then edit .env with your values
set -a; source .env; set +a
```

`.env` is gitignored. You need Docker running for the github server.

## Open in Cursor

Open **`brownfield-app/`** as your workspace root — not the repo root. Cursor loads
`AGENTS.md` and `.cursor/rules/`. See `docs/00-cursor-setup.md` at the repo root for full
setup and troubleshooting.

## A good first exercise

Implement the waitlist in `specs/001-stage-waitlist/`. Start by running the test-writer
subagent on the rate card, then work the tasks in order. Use the worktree script if you
want to parallelize the independent ones.
