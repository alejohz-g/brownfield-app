# Feature spec: stage slot waitlist

Spec-driven development (SDD) means you write the intent first, agree on it,
then let the agent generate the plan and the tasks from it. The spec is the source of
truth. This file is the spec — what and why, no implementation detail.

## Problem

When a stage block reaches crew capacity, the service rejects the booking with a 409.
Productions have no way to hold a place, and the studio loses bookings when a production
cancels and frees space that nobody is told about.

## Goal

Let a production join a waitlist for a full stage block, and promote waitlisted productions
automatically, in order, when capacity frees up.

## User stories

1. As a production, when my chosen stage block is full, I can join its waitlist instead of
   being rejected, and I receive a waitlist position.
2. As a production on a waitlist, when enough capacity frees up for my whole crew, I am
   promoted to a confirmed booking and billed the rate at promotion time.
3. As a production, I can leave a waitlist before being promoted.

## Acceptance criteria

- Joining a full stage block returns a waitlist entry with a position, not a 409.
- Promotion is first-in, first-out by join time, and only happens when the freed capacity
  fits the whole crew. Partial promotion never happens.
- A cancellation that frees capacity triggers evaluation of the waitlist for that slot.
- The rate at promotion uses the current rate-card rules, including surge and volume
  discount, evaluated at promotion time, not join time.
- Capacity is never exceeded by promotion.

## Out of scope

- Notifications and email. Promotion updates state only.
- Payment capture. The service records `ratePaid`; it does not move money.
- Per-production waitlist limits.

## Open questions

- Should a production be allowed on more than one slot's waitlist at once? Assume yes for now.
- Does a promoted production get a hold window to confirm? Assume immediate confirmation for v1.
