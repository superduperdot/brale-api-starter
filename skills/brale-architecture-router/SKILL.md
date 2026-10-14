---
name: brale-architecture-router
description: >-
  Route a new Brale integration to one of seven architectures and its
  read-next list. Use when starting a new project that calls the Brale API,
  when the user says "new app", "new repo", "which architecture", or when
  choosing between wallet, settlement, analytics, dashboard, compliance,
  or treasury patterns.
disable-model-invocation: true
---

# Brale architecture router

Pick the architecture before writing a Worker, a schema, or a wallet. Everything else follows from this choice.

## Architectures

| If you are building… | Architecture | Runtime | Brale surface |
|----------------------|-------------|---------|---------------|
| A self-custody wallet | **Self-custody wallet** | Browser extension | Read API only |
| An agent or bot that sends stablecoins | **Agent wallet** | npm library | Read API as balance fallback; policy gates every send |
| Cross-chain movement at par | **Par settlement** | Cloudflare Workers | `api.brale.xyz` (ION, convert, attestation) |
| A real-time analytics view | **Analytics command center** | Cloudflare Workers | Full orchestration, webhooks, backfill |
| A self-hosted operations dashboard | **Operations dashboard** | Workers + Next.js | Full orchestration, local-first sync |
| Transaction monitoring | **Compliance monitoring** | Cloudflare Workers | Registry on read API; your own screening API |
| Business onboarding, treasury, card settlement | **Managed treasury** | Cloudflare Workers | Managed accounts, KYB, transfers |

## Decision process

1. Ask: "What is the user shipping?" Match to the closest row above.
2. If the product spans two architectures, pick the primary and note the secondary in `brain.md`.
3. Write the architecture name into `brain.md` and the README before any code.

## Read-next by architecture

| Architecture | Read next |
|-------------|-----------|
| Self-custody wallet | `guide/concepts.md#self-custody-wallet`, `guide/security.md`, `guide/brale-api.md` (read APIs), `guide/testing.md`, `guide/durable-objects.md` |
| Agent wallet | `guide/concepts.md#agent-wallet`, `guide/security.md`, `guide/value-layer.md`, `guide/testing.md` |
| Par settlement | `guide/concepts.md#par-settlement`, `guide/cloudflare-stack.md`, `guide/brale-api.md`, `guide/durable-objects.md`, `guide/sync-engine.md`, `guide/testing.md` |
| Analytics command center | `guide/concepts.md#analytics-command-center`, `guide/brale-api.md`, `guide/cloudflare-stack.md`, `guide/value-layer.md`, `guide/durable-objects.md`, `guide/sync-engine.md` |
| Operations dashboard | `guide/concepts.md#operations-dashboard`, `guide/brale-api.md`, `guide/cloudflare-stack.md`, `guide/design-style.md`, `guide/durable-objects.md` |
| Compliance monitoring | `guide/concepts.md#compliance-monitoring`, `guide/cloudflare-stack.md`, `guide/csf-gsf.md`, `guide/value-layer.md`, `guide/durable-objects.md` |
| Managed treasury | `guide/concepts.md#managed-treasury`, `guide/managed-accounts.md`, `guide/security.md`, `guide/cloudflare-stack.md`, `guide/sync-engine.md` |

## Non-negotiables (all architectures)

- TypeScript strict, pnpm
- `brain.md`, `AGENTS.md`, `architecture.md` at the repo root
- Brale client credentials never ship to the browser
- `Idempotency-Key` on every Brale POST that creates a resource
- Amounts are decimal strings — never `parseFloat` a financial amount
- Sessions in D1 or a server store, never KV
- Do not commit unless the user asked

## After routing

1. Run the [brale-app-scaffold](../brale-app-scaffold/SKILL.md) skill to bootstrap the repo.
2. Follow only the read-next list for your architecture.
3. Do not import patterns from the other six unless the product actually spans them.
