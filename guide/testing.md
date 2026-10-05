# Testing

Tests are part of the change. A feature is done when the gates below are green, not when the UI looks right.

## What to run

| Layer | Tool | Covers |
|-------|------|--------|
| Unit | Vitest | Pure logic: amounts, policy, redaction, status transitions, id prefixes. No network. |
| End to end | Playwright, against the **build** | The path a person takes, including content-security policy |
| Gates | Scripts that exit non-zero | Invariants you refuse to “monitor” (unprofitable settlement, quote parity) |

Order for a TypeScript app:

```bash
pnpm -r typecheck
pnpm test
pnpm build
pnpm test:e2e   # when a UI or extension exists
```

Extension end-to-end tests should run headed and single-threaded. Parallel headed browsers flake. Wallet-creation tests belong here: a missing `wasm-unsafe-eval` directive fails silently and unit tests never load the extension page.

## What each architecture must pin down

| Architecture | Do not ship without |
|--------------|----------------------|
| Self-custody wallet | Unit tests for vault crypto and derivation. E2E on the built extension. A small mainnet send recorded in `brain.md`. |
| Agent wallet | Policy rejects over-cap sends with no network call. `destroy()` zero-fills and then throws. |
| Par settlement | A gate that fails CI when a fill would be unprofitable. Quote checks. Confirmation via HTTP poll, asserted in tests with a fake RPC. |
| Analytics | Security tests: auth, webhook integrity, headers, rate limits. Responsive checks if you claim a command-center layout. |
| Operations dashboard | Idempotency key present on create calls. Reconciler retries the same key. Error `detail` from Brale surfaces in the action result. |
| Compliance monitoring | Address normalization. Exchange classification (swap / bridge / cross-rail). API tests stay fast with the processor mocked. |
| Managed treasury | KYB builder has no database import. Sweep note prevents a second sweep. Poller recovery and discovery are separate tests. Money regex rejects floats and exponents. |

## Mainnet

“Works on mainnet” means you sent a small real amount and wrote down the transfer id, the rails, and the result in `brain.md`. Simulation is not that sentence.

For settlement, include at least one path in each direction you claim (for example Base to Solana and Solana to Base) and a same-chain buy or redeem if you offer it.

## Regressions

A bug fix adds a test that failed on the old code. If you cannot fix it now, write it in `brain.md` and in `docs/status.md`. An unwritten bug gets rediscovered by the next agent.

## Related

- [security.md](security.md)
- [ai-agents.md](ai-agents.md)
- [getting-started.md](getting-started.md)
