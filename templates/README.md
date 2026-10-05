# {{App Name}}

One sentence: what this does for the customer.

**License:** [MIT](./LICENSE)

## Who this is for

Plain statement of the customer and the problem. No internal codename.

## Architecture

One of the Brale Playbook architectures: self-custody wallet, agent wallet, par settlement, analytics command center, operations dashboard, compliance monitoring, or managed treasury.

One paragraph on why that shape fits. Link the playbook’s `guide/concepts.md` if you vendor a copy of it.

## What it does

- 
- 
- 

## Brale API

| Surface | Endpoint or feature | Purpose |
|---------|---------------------|---------|
| `api.brale.xyz` | | |
| `data.brale.xyz` | | |
| `brale.network/api` | | |

Or: **None.** Say what you use instead (on-chain sends, a local ledger).

## Cloudflare

| Primitive | Usage |
|-----------|-------|
| Workers | |
| D1 | |

Or: **None.** Extension, library, or another runtime.

## Value Layer

How transfers are labeled. Operator grammar, end-user language, or both — and where the boundary is.

- [CSF](https://github.com/Brale-xyz/commons/blob/main/Commons%20Stablecoin%20Format/csf.json) if you render funds flows
- [GSF](https://github.com/benmilne-com/standards/blob/main/gsf/gsf-0.5.2.json) if you render relationship graphs

## Quick start

```bash
pnpm install
pnpm dev
```

## Documentation

- [brain.md](./brain.md) — what is built (**read first**)
- [AGENTS.md](./AGENTS.md) — commands and guardrails
- [architecture.md](./architecture.md) — runtime
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [SECURITY.md](./SECURITY.md)

## Playbook

Patterns, pitfalls, and the first-integration runbook live in the Brale Playbook (`guide/getting-started.md` in that repo).
