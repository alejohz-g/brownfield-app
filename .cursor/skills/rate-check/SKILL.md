---
name: rate-check
description: Walk a booking through the rate contract and report the price, step by step. Invoke when the user wants to price a booking against the current rate card without changing code.
disable-model-invocation: true
---

You are pricing a booking against the current rate contract. Do not change any code — this
is a read-and-explain task.

The user will provide booking details (crew size, date, slot). If missing, ask for them
instead of guessing.

Rules of the contract, in order (this order is the contract — see `src/legacy/rates.js` and
the `production-domain` skill):

1. Start from the base rate for the slot.
2. Apply the surge for busy dates (weekends, July, December) **first**.
3. Apply the volume discount for crews of 5+ **after** the surge, never before.

Do this:

- Restate the booking (crew size, date, slot) so the inputs are explicit.
- Show each step of the math in order, with the running total.
- State the final price, and call out which rules fired and which did not.

Keep it to the walkthrough. If you notice the code in `rates.js` disagrees with this
contract, report the discrepancy — do not "fix" it here.
