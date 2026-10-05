# Seed prompt — start a Brale app

Copy everything below the line into an agent session when you start a repository. Fill the table first. Do not let the agent pick names or an architecture for you.

---

You are building an application on the Brale API. Follow the Brale Playbook. Do not invent a second set of conventions.

## Read first

1. `guide/concepts.md` — choose the architecture that matches the table below. Read only that section’s “read next” links.
2. `guide/naming-conventions.md` — names are already decided. Do not rename them.
3. `guide/getting-started.md` — scaffold and the first-integration runbook.
4. The Brale Agent Kit `AGENTS.md` (https://github.com/superduperdot/brale-agent-kit/blob/main/AGENTS.md) if the app calls `api.brale.xyz`.
5. The lesson file named in the table.

## Decisions (already made)

| Field | Value |
|-------|--------|
| Architecture | ____________ (one of: self-custody wallet, agent wallet, par settlement, analytics command center, operations dashboard, compliance monitoring, managed treasury) |
| Repo slug | ____________ |
| Display name | ____________ |
| Package name | ____________ |
| Customer | One sentence: who this is for |
| Brale surface | `api.brale.xyz` / read API / none |
| Cloudflare | Workers + (D1, DO, KV, R2, Queues, Cron) / none |

UI rule: operator tools show Value Layer legs (`USD Wire → USDC Base`). End-user products show plain words (USDC, Base, wire) and do not say “value type” or “transfer type”.

## Scaffold

Copy from the playbook `templates/` directory:

- `README.md`
- `brain.md`
- `AGENTS.md`
- `architecture.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `LICENSE` (MIT, unless the maintainer said otherwise)

Write the architecture name and the customer sentence into `brain.md` and the README before any other code.

## Non-negotiables

- TypeScript strict and pnpm
- `brain.md`, `AGENTS.md`, and `architecture.md` at the repo root
- Brale client credentials never ship to the browser
- `Idempotency-Key` on every Brale POST that creates a resource
- Amounts are decimal strings
- Sessions in D1 or a server store, never KV
- KYB payloads are forwarded and not stored, if this app onboards businesses
- Do not commit unless asked
- A change is done only when typecheck, unit tests, and the production build are green

## Stack

Use the stack from the architecture section in `guide/concepts.md`. Do not add Cloudflare to an extension or a library. Do not put queue consumers on the same Worker as a latency-sensitive API.

## When you learn something reusable

Add a dated note to this repo’s `brain.md`. If it would save a different Brale app, add a field note to the playbook’s `lessons/` file for this architecture and update the matching `guide/` page.

---

*Maintained in the Brale Playbook `templates/SEED-PROMPT.md`.*
