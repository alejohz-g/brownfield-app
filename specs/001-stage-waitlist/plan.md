# Technical plan: stage slot waitlist

This is the plan. The agent generates it from `spec.md` and the repo's current
state. It is where implementation decisions get made and reviewed before any code is written.

## Approach

Introduce a thin service layer rather than growing the fat handler further. The waitlist is
the first feature that justifies splitting business logic out of `routes/bookings.ts`.

## Data model changes (in `src/db.ts`)

- Add a `WaitlistEntry` type: `id`, `production`, `stage`, `slot`, `crewSize`, `joinedAt`,
  `status` (`waiting` or `promoted` or `left`).
- Add an in-memory `waitlist` array and helpers: `enqueue`, `waitlistForSlot` (ordered by
  `joinedAt`), `markPromoted`, `markLeft`.

## Service layer (new `src/services/bookings.ts`)

- `book(input)`: existing capacity and rate logic moves here. On a full stage block, instead
  of rejecting, create a waitlist entry and return it.
- `cancel(bookingId)`: removes a booking, then calls `evaluateWaitlist` for the slot.
- `evaluateWaitlist(stage, slot)`: walks the slot's waitlist in join order, promotes the
  first entry whose full crew fits the freed capacity, repeats until the next entry does
  not fit or the list is empty. Never partially promotes.
- Promotion prices with the existing `rates.rateFor` at promotion time.

## Route changes (in `src/routes/bookings.ts`)

- `POST /bookings` delegates to `service.book`. Response is 201 for a confirmed booking
  or 202 with the waitlist entry when the stage block was full.
- `DELETE /bookings/:id` delegates to `service.cancel`.
- Normalize error shapes here as part of this work, since the spec touches the write path.

## Rate card

No change to `rates.js`. Surge-before-discount order stays. Promotion calls the existing
function. This keeps the rate-card contract intact while adding the feature.

## Risks

- Concurrency: the in-memory store has no locking. Document that promotion assumes a single
  process for now; flag it as a real issue for the Postgres migration.
- Behavior change: callers currently relying on the 409 will now see 202. Call this out.

## Testing

- Characterization tests for the current rate card land first (test-writer subagent).
- New tests: join full stage block, promote on cancel, no partial promotion, FIFO order,
  capacity never exceeded.
