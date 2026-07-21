# Project constitution

This is the project constitution: the standing principles every spec, plan, and task
must respect. It is the rulebook the agent checks its own work against. Keep it short and
durable.

1. Preserve observable behavior unless a spec explicitly changes it. Rate math and
   crew-capacity semantics are contracts.
2. Tests come before refactors of untested code. No exceptions for the rate card.
3. Handlers stay thin. Business logic lives in a service layer.
4. Every behavior change is named in the change summary, including changed status codes and
   error shapes.
5. No new runtime dependency without an explicit note and a reason.
6. The always-loaded context (`AGENTS.md`, `.cursor/rules/`) stays small. Detail goes in
   skills and specs, loaded when relevant.
