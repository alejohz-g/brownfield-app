# Cursor capstone prompts — stage slot waitlist

Copy-paste prompts for implementing the waitlist feature (T1–T8) in Cursor. Claude Code
participants can work from `specs/001-stage-waitlist/tasks.md` directly — subagents delegate
automatically from their `description` fields.

Read `specs/constitution.md` and `specs/001-stage-waitlist/spec.md` before starting.

## T1 — Rate card characterization tests

```
Use the test-writer agent to add characterization tests for src/legacy/rates.js.
Cover: peak slot, off-peak slot, crew of 5 (volume discount), unknown stage floor rate.
Pin current behavior including surge-before-discount order. No production code changes.
```

## T2 — Waitlist store

```
Implement T2 from specs/001-stage-waitlist/tasks.md: add WaitlistEntry type and
in-memory waitlist helpers in src/db.ts. No route changes yet.
```

## T3 — Service layer extraction

```
Implement T3 from specs/001-stage-waitlist/tasks.md: create src/services/bookings.ts,
move existing book and rate logic into a book function with no behavior change.
Add parity tests proving the handler and service produce the same results.
```

## T4 — Waitlist on full

```
Implement T4 from specs/001-stage-waitlist/tasks.md: when a stage slot is full,
return a waitlist entry (202) instead of 409. Depends on T2 and T3 being merged.
```

## T5 — Cancel and FIFO promotion

```
Implement T5 from specs/001-stage-waitlist/tasks.md: add cancel and evaluateWaitlist
with FIFO promotion. No partial promotion. Add tests for promotion rules.
```

## T6 — Route wiring

```
Implement T6 from specs/001-stage-waitlist/tasks.md: wire routes to the service layer.
POST returns 201 for booked, 202 for waitlisted. Add DELETE /:id for cancellation.
```

## T7 — Normalize error shapes

```
Implement T7 from specs/001-stage-waitlist/tasks.md: normalize write-path errors to
{error, code}. Note every behavior change in your summary.
```

## T8 — Update docs and skill

```
Implement T8 from specs/001-stage-waitlist/tasks.md: update AGENTS.md, CLAUDE.md,
.cursor/skills/production-domain/SKILL.md, and .claude/skills/production-domain/SKILL.md
to reflect the new waitlist behavior. Remove resolved tech-debt items.
```

## Parallel fan-out (T1, T2, T3)

```bash
./scripts/parallel-worktrees.sh
```

Open each worktree directory in a separate Cursor window, then run the T1/T2/T3 prompts
above in each. Review branches, merge, then continue T4–T8 sequentially.

## Pre-merge check

Invoke the `ship-check` skill (Skills picker) or ask:

```
Run the ship-check skill: execute npm test, npm run build, review git diff against
specs/constitution.md, and give a ship/hold verdict.
```

## Security review

```
Use the security-reviewer agent to review the current diff for input validation,
injection, and data-exposure issues. Report findings only — do not edit code.
```
