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

## Testnet (how to get tokens to test with)

Brale has one non-production environment: **testnet** (there is no separate "sandbox"). Create a testnet application in the dashboard, enable the resources you need, and use those credentials — the environment is a property of the credential, not a URL. Only testnets are reachable (`sepolia`, `base_sepolia`, `solana_devnet`, …); mainnets are not. No real fiat moves.

Getting test tokens — three documented patterns ([docs](https://docs.brale.xyz/overview/sandbox-and-testnet.md)):

| Pattern | How | What it gives you |
|---------|-----|-------------------|
| **Mint = faucet** | `POST /transfers` with `source: { value_type: "USD", transfer_type: "wire" }` → `destination: { address_id, value_type: "SBC", transfer_type: "solana_devnet" }` | On testnet the fiat leg is skipped and tokens mint on-chain. This is how you fund a custodial address to test payouts, swaps, etc. |
| **Burn = redeem** | The reverse: custodial stablecoin source → `{ value_type: "USD", transfer_type: "wire" }` destination | Exercises the off-ramp path; burns on-chain, skips the fiat payout. |
| **Simulated Automation deposit** | Create an Automation with a testnet destination, wait for `status: active`, then `POST .../automations/{id}/simulations/deposits` with `{ amount, transfer_type: "ach" \| "wire" }` | Runs the full Automation → Transfer → mint → webhook flow (emits `payment.completed`). The only way to exercise the inbound-deposit path, since testnet Automations return placeholder bank coordinates. Needs `automations:write` + `network:testnet` scopes. |

This "mint" is a standard transfer, not the tokenization mint/burn endpoints — those are a separate feature for tokenization (self-attested) accounts issuing their own token. Point your test suite at testnet rails and use the faucet mint in setup fixtures so tests start with a funded address.

### Playwright on a built extension

End-to-end tests for a browser extension should run against the **production build**, not the dev server.

| Setting | Value |
|---------|-------|
| Extension path | `../extension/.output/chrome-mv3` (the built output) |
| Workers | `workers: 1` (single-threaded) |
| Mode | Headed (not headless — extensions need a visible browser) |
| Context | `launchPersistentContext` (required for extensions) |
| Extension ID | Derive from the service-worker URL after launch |
| Content-script target | Start a local HTTP server (e.g. `python3 -m http.server 5599`) so content scripts match `http://localhost/*`, not `file://` |

The wallet-creation test belongs here: a missing `wasm-unsafe-eval` CSP directive fails silently and unit tests never load the extension page.

### Offline simulation gates

For settlement or treasury products, add offline sim files (e.g. `convert.sim.ts`, `pnl.sim.ts`) that assert:
- Idempotency: calling the same operation twice with the same key does not create a duplicate.
- Terminal poll: the poller correctly identifies `complete`, `canceled`, `failed` as terminal.
- Unprofitable fills throw (settlement) or unprofitable sweeps are skipped (treasury).

Wire these as CI gates — they run without network or secrets.

## Mainnet

“Works on mainnet” means you sent a small real amount and wrote down the transfer id, the rails, and the result in `brain.md`. Simulation is not that sentence.

For settlement, include at least one path in each direction you claim (for example Base to Solana and Solana to Base) and a same-chain buy or redeem if you offer it.

## Regressions

A bug fix adds a test that failed on the old code. If you cannot fix it now, write it in `brain.md` and in `docs/status.md`. An unwritten bug gets rediscovered by the next agent.

## Related

- [security.md](security.md)
- [ai-agents.md](ai-agents.md)
- [getting-started.md](getting-started.md)
