---
name: ship-check
description: Run the pre-merge gates and check the current diff against the constitution. Invoke before merging or shipping a change.
disable-model-invocation: true
---

Pre-merge check before this change goes anywhere. Run the gates, then judge the diff.

Run these commands and use their output:

- Tests: `npm test`
- Type-check / build: `npm run build`
- Diff under review: `git diff --stat`

Now check the change against `specs/constitution.md`, gate by gate:

1. Observable behavior preserved unless a spec changes it (rate math, crew capacity).
2. Tests come before refactors of untested code — no exceptions for the rate card.
3. Handlers stay thin; business logic lives in a service layer.
4. Every behavior change is named — including changed status codes and error shapes.
5. No new runtime dependency without an explicit note and reason.

Report a short verdict: **ship** or **hold**. For a hold, list exactly which gate failed
and the smallest change that would clear it. Do not edit anything — this command only
reports.
