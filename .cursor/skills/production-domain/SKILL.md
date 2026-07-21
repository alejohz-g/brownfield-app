---
name: production-domain
description: Domain rules for soundstage shoot scheduling: crew capacity, stage slots, rate-card order of operations (surge before volume discount), and error conventions. Load for any task that asks about, explains, or changes booking, capacity, or pricing/rate logic — including why a booking is priced a certain way.
---

# Production scheduling domain

A skill is reusable, on-demand knowledge. Cursor reads the short description above to decide
whether a task is relevant, and only then loads this body. That keeps the domain detail out
of the default context window until a booking task actually needs it. This is the difference
between a skill and `AGENTS.md`: `AGENTS.md` is always loaded, a skill is loaded when relevant.

## Stage slots

A slot is a stage plus a shoot day plus a call-time band, encoded as `stage` and a `slot`
string like `2026-07-04T09`. Capacity is per slot, per stage, and lives in `CAPACITY` in
`src/db.ts`. Capacity counts crew, not bookings: a crew of 4 uses 4 of the stage's
capacity for that block.

## Rate-card order of operations (contract)

Pricing is in `src/legacy/rates.js`. The current, intended order is:

1. Base rate per stage, multiplied by crew size.
2. Surge multiplier of 1.25 on peak slots (weekends, plus all of July and December).
3. Volume discount of 0.92 for crews of 5 or more, applied after surge.

Steps 2 and 3 do not commute. Surge then discount is the contract. If a task changes this,
it must say so explicitly and update the tests.

## Error conventions (current, inconsistent)

The POST handler currently returns mixed shapes: a plain string for a missing production
name, a 200 with `{error}` for a missing stage, and a 409 with `{error, capacity, taken}`
for a full stage. A standing cleanup task is to make these consistent. Do not silently
"fix" one shape in passing; that breaks any caller relying on the current behavior. Flag
it instead.

## When you add capacity or rate logic

- Write or update characterization tests first if none cover the path you touch.
- Keep crew-count semantics: capacity is crew, not bookings.
- Leave the surge-before-discount order intact unless the task is to change it.
