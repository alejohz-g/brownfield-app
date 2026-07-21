# Tasks: stage slot waitlist

The tasks breakdown. The agent breaks the plan into ordered, reviewable units. Each is small
enough to do, verify, and commit on its own. Check them off as you go.

- [ ] T1. Add characterization tests for current rate-card behavior (peak, off-peak, crew of
  5, unknown stage floor rate). Use the test-writer subagent. No code changes outside tests.
- [ ] T2. Add `WaitlistEntry` type and the in-memory waitlist plus helpers in `src/db.ts`.
- [ ] T3. Create `src/services/bookings.ts` and move existing book and rate logic into
  `book`, with no behavior change. Add tests proving parity.
- [ ] T4. Implement waitlist-on-full inside `book`: return a waitlist entry instead of 409.
- [ ] T5. Implement `cancel` and `evaluateWaitlist` with FIFO promotion and no partial
  promotion. Add tests for the promotion rules.
- [ ] T6. Wire routes to the service. `POST` returns 201 or 202; add `DELETE /:id`.
- [ ] T7. Normalize error shapes on the write path to a single `{error, code}` form. Note
  the behavior change in the summary.
- [ ] T8. Update `AGENTS.md` known tech debt and the production-domain skill to reflect
  the new waitlist behavior.

## How to run this with parallelization

T2, T3, and T1 are largely independent and can run in separate git worktrees on separate
branches at the same time. See `scripts/parallel-worktrees.sh` and
`docs/11-parallelization-worktrees.md`.
