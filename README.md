# Brale API Starter

A runbook for building on the **Brale API**. It is the short version of what already works: which API surface to call, which Cloudflare primitive to use, and the failure modes worth skipping.

Read the page for the job in front of you. You do not need the rest.

## Two core references

Everything else in this repo supports these two pages. If you read nothing else, read these.

| Reference | What it carves out |
|-----------|--------------------|
| **[Brale API](guide/brale-api.md)** | The endpoint map, OAuth, transfers and idempotency, webhook verification, sync, read surfaces, and the pitfalls — checked against [docs.brale.xyz](https://docs.brale.xyz). |
| **[Cloudflare stack](guide/cloudflare-stack.md)** | Which primitive to use (Workers, D1, Durable Objects, KV, R2, Queues, Cron), the layouts that have shipped, and the first-deploy gotchas. |

The architectures below tell you *which* parts of those two pages a given product needs.

## How to use this

1. Pick the closest architecture in [guide/concepts.md](guide/concepts.md).
2. Follow only the pages that architecture lists.
3. Copy [templates/](templates/) when you open a new repo.
4. Paste [templates/SEED-PROMPT.md](templates/SEED-PROMPT.md) into an agent session so it follows the same rules.
5. When something breaks, check the pitfall tables in [guide/brale-api.md](guide/brale-api.md) and the field notes in [lessons/](lessons/).

## If you only have 20 minutes

| You are about to… | Read |
|-------------------|------|
| Call Brale | [guide/brale-api.md](guide/brale-api.md) |
| Deploy on Cloudflare | [guide/cloudflare-stack.md](guide/cloudflare-stack.md) |
| Onboard a business | [guide/managed-accounts.md](guide/managed-accounts.md) |
| Show money in a UI | [guide/value-layer.md](guide/value-layer.md) |
| Start a repository | [guide/getting-started.md](guide/getting-started.md) |

## Architectures

These are jobs, not products. Pick the row that matches what you are shipping.

| If you are building… | Runtime | Brale surface | Start here |
|----------------------|---------|---------------|------------|
| A self-custody wallet | Browser extension | Read API only | [Self-custody wallet](guide/concepts.md#self-custody-wallet) |
| An agent or bot that sends stablecoins | npm library | Read API as a balance fallback; policy gates every send | [Agent wallet](guide/concepts.md#agent-wallet) |
| Cross-chain movement of Brale-issued stables at par | Cloudflare Workers | `api.brale.xyz` (ION, convert, attestation) | [Par settlement](guide/concepts.md#par-settlement) |
| A real-time analytics view of an account | Cloudflare Workers | Full orchestration, webhooks, backfill | [Analytics](guide/concepts.md#analytics-command-center) |
| A self-hosted operations dashboard | Workers + Next.js | Full orchestration, local-first sync | [Operations dashboard](guide/concepts.md#operations-dashboard) |
| Transaction monitoring and investigation | Cloudflare Workers | Registry on the read API; your own screening API | [Compliance monitoring](guide/concepts.md#compliance-monitoring) |
| Business onboarding, treasury, or card settlement | Cloudflare Workers | Managed accounts, KYB, transfers | [Managed treasury](guide/concepts.md#managed-treasury) |

## Reference pages

| Page | What it decides |
|------|-----------------|
| [Getting started](guide/getting-started.md) | First-integration runbook and repo checklist |
| [Naming](guide/naming-conventions.md) | Repo, package, UI copy, and entity IDs |
| [Brale API](guide/brale-api.md) | Auth, transfers, webhooks, sync, pitfalls |
| [Cloudflare stack](guide/cloudflare-stack.md) | Which primitive, and the shapes that have held up |
| [Managed accounts](guide/managed-accounts.md) | Onboarding, KYB, auto-sweep, status machine, poller |
| [Value Layer](guide/value-layer.md) | How to name money in code and in the UI |
| [CSF and GSF](guide/csf-gsf.md) | Funds-flow diagrams and relationship graphs |
| [Security](guide/security.md) | Secrets, sessions, custody, log redaction |
| [Testing](guide/testing.md) | What “done” means before you ship |
| [Design](guide/design-style.md) | Two visual systems that have shipped |
| [AI agents](guide/ai-agents.md) | `brain.md`, `AGENTS.md`, and how agents should use this playbook |
| [Lessons](lessons/README.md) | Field notes by architecture |

Procedural API reference lives in the [Brale Agent Kit](https://github.com/superduperdot/brale-agent-kit). This playbook tells you which pattern to apply. It does not duplicate that TypeScript.

## External references

| Reference | Location | Last verified |
|-----------|----------|---------------|
| Brale API docs index | [docs.brale.xyz/llms.txt](https://docs.brale.xyz/llms.txt) | 2026-10-05 |
| Value types (enums) | [docs.brale.xyz/coverage/value-types](https://docs.brale.xyz/coverage/value-types.md) | 2026-10-05 |
| Transfer types (enums) | [docs.brale.xyz/coverage/transfer-types](https://docs.brale.xyz/coverage/transfer-types.md) | 2026-10-05 |
| The Value Layer (design basis for `value_type`/`transfer_type`) | [benmilne.com/book/the-value-layer](https://benmilne.com/book/the-value-layer) | 2026-10-05 |
| Brale Agent Kit | [superduperdot/brale-agent-kit](https://github.com/superduperdot/brale-agent-kit) | 2026-10-05 |
| CSF spec | [Brale-xyz/commons/csf.json](https://github.com/Brale-xyz/commons/blob/main/Commons%20Stablecoin%20Format/csf.json) | 2026-06-24 |
| GSF spec | [benmilne-com/standards/gsf-0.5.2.json](https://github.com/benmilne-com/standards/blob/main/gsf/gsf-0.5.2.json) | 2026-06-24 |
| Brale OpenAPI | [api.brale.xyz/openapi](https://api.brale.xyz/openapi) | 2026-06-24 |

Verify these before you treat an endpoint shape as current.

## Templates

Copy from [templates/](templates/) when starting an app:

- [README.md](templates/README.md) — README skeleton
- [SEED-PROMPT.md](templates/SEED-PROMPT.md) — bootstrap prompt for an agent session
- [brain.md](templates/brain.md) — project source of truth
- [AGENTS.md](templates/AGENTS.md) — working agreement
- [architecture.md](templates/architecture.md) — as-built architecture
- [CONTRIBUTING.md](templates/CONTRIBUTING.md) — setup and pull requests
- [SECURITY.md](templates/SECURITY.md) — vulnerability reporting

## License

MIT — see [LICENSE](LICENSE).

Organized by the job you are doing, not by any one application, so a new Brale integration can reuse the patterns directly.
