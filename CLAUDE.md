# CLAUDE.md

Primary config and context file for this repo. Claude Code loads this automatically at
the start of every session, so it is the cheapest, highest-leverage place to put the
things you would otherwise repeat in every prompt.

> **Also using Cursor?** See [AGENTS.md](AGENTS.md) — same content, Cursor-native entry point.

## What this service is

A legacy scheduling API for booking soundstages for shoots. A production reserves a stage
for a shoot block (a day plus a call-time band) for a crew, the service checks the stage's
crew capacity, prices the booking against a rate card, and stores it. The codebase carries
real tech debt on purpose, so the team can practice driving a coding agent against a
brownfield repo.

## Architecture, in one paragraph

`src/server.ts` wires Express and mounts one router. `src/routes/bookings.ts` holds a
single fat handler that validates input, checks capacity, prices, and persists, all in
one place. `src/db.ts` is an in-memory store with no persistence or concurrency control.
`src/legacy/rates.js` is untyped JavaScript with surge and volume-discount rules that
depend on order of operations. Treat the rate card as a contract: add types and tests
around it before you change it.

## Known tech debt (read before editing)

- The POST handler returns three different error shapes with three different status codes.
- There are no tests. `npm test` fails on purpose.
- `capacityFor` returns `undefined` for unknown stages instead of throwing.
- The rate card applies surge before the volume discount. That order is the current contract.

## Conventions

- TypeScript is in loose mode (`strict: false`). Do not flip strict on in passing; it is
  a tracked migration, not a side effect of another change.
- Keep handlers thin once you start refactoring. Push business logic into a service layer.
- Do not introduce a new dependency without calling it out in your summary.

## Specs and the constitution

Standing rules and planned work live in `specs/`:

- `specs/constitution.md` — the durable, project-wide principles every spec, plan, and
  task must respect (behavior is a contract, tests before refactors of untested code,
  thin handlers, etc.). Check work against it.
- `specs/<NNN-feature>/` — the spec, plan, and tasks for a given feature
  (e.g. `specs/001-stage-waitlist/`). Read the relevant one before working on that feature.

## How to work in this repo

- Run `npm run dev` to start the API on port 3000.
- Before changing `rates.js`, ask for or write characterization tests first.
- When you finish a change, state what you changed, why, and what you did not touch.

## Credentials and environment

Credentials (the Mongo connection string, the GitHub token) live in `.env`, which is
gitignored. They are NOT hardcoded in `.mcp.json` or `.cursor/mcp.json` — those files only
hold `${...}` references that Claude Code expands from the shell environment at launch. So
to be loaded into the shell before starting the agent:

    set -a; source .env; set +a

If an MCP server does not connect, check the variable is in the environment first:
`echo $MDB_MCP_CONNECTION_STRING`. Never ask for or invent these secrets — if they are
missing, say the `.env` needs to be loaded.

## Context hygiene

This file should stay short. Detailed, situational knowledge lives in `.claude/steering/`
(and `.cursor/rules/` for Cursor) and `specs/`, and is pulled in only when relevant. If this file grows past roughly one
screen, move the situational parts into a steering doc or spec and link to it. See
`docs/01-context-management.md`.
