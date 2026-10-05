# AGENTS.md

Guidance for AI agents and contributors. Read [brain.md](./brain.md) first.

## Before you start

- Read [brain.md](./brain.md) and [architecture.md](./architecture.md).
- Read the Brale Playbook pages for **this** architecture only (`guide/concepts.md`, then the links in that section).
- If this app calls `api.brale.xyz`, read the [Brale Agent Kit AGENTS.md](https://github.com/superduperdot/brale-agent-kit/blob/main/AGENTS.md) and prefer its `reference/` clients.

## Build and verify

```bash
pnpm -r typecheck
pnpm test
pnpm build
```

A change is done when those are green. Add end-to-end tests when there is a UI or an extension.

## Conventions

- TypeScript strict. Avoid `any` without a reason written next to it.
- Crypto: `@noble/*`, `@scure/*`, `hash-wasm`, Web Crypto on Workers.
- Comments say why.
- Amounts stay decimal strings until the screen that formats them.
- New ids go through one prefixed `generateId`.

## Guardrails

- Do not commit unless asked.
- Update `brain.md` when behavior changes.
- Record unfixed bugs in `brain.md`.
- No Brale client credentials in client bundles.
- No sessions in KV.
- No KYB payloads in the database or in logs.
- Do not mark a transfer settled inside `ctx.waitUntil()`. Await that write.

## When you learn something

1. Add a dated note to `brain.md`.
2. If it would help a different Brale app, add a field note to the playbook under `lessons/` for this architecture and update the matching `guide/` page.
3. If it is a Brale API quirk, also consider the [Brale Agent Kit](https://github.com/superduperdot/brale-agent-kit).
