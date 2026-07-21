---
description: Run the pre-merge gates and check the current diff against the constitution.
allowed-tools: Bash(npm test), Bash(npm run build), Bash(git diff*), Bash(git status*)
---

Pre-merge check before this change goes anywhere. Run the gates, then judge the diff.

Current state:

- Tests: !`npm test`
- Type-check / build: !`npm run build`
- Diff under review: !`git diff --stat`

Now check the change against `specs/constitution.md`, gate by gate:

1. Observable behavior preserved unless a spec changes it (rate math, crew capacity).
2. Tests come before refactors of untested code — no exceptions for the rate card.
3. Handlers stay thin; business logic lives in a service layer.
4. Every behavior change is named — including changed status codes and error shapes.
5. No new runtime dependency without an explicit note and reason.

Report a short verdict: **ship** or **hold**. For a hold, list exactly which gate failed
and the smallest change that would clear it. Do not edit anything — this command only
reports.
