---
description: Walk a booking through the rate contract and report the price, step by step.
argument-hint: <crew size> <date> [peak|off-peak]
---

You are pricing a booking against the current rate contract. Do not change any code — this
is a read-and-explain task.

The booking to price: **$ARGUMENTS**

Rules of the contract, in order (this order is the contract — see @src/legacy/rates.js and
the `production-domain` skill):

1. Start from the base rate for the slot.
2. Apply the surge for busy dates (weekends, July, December) **first**.
3. Apply the volume discount for crews of 5+ **after** the surge, never before.

Do this:

- Restate the booking (crew size, date, slot) so the inputs are explicit.
- Show each step of the math in order, with the running total.
- State the final price, and call out which rules fired and which did not.
- If the request is missing crew size or date, ask for it instead of guessing.

Keep it to the walkthrough. If you notice the code in `rates.js` disagrees with this
contract, report the discrepancy — do not "fix" it here.
