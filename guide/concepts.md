# Architectures

Pick the closest job. Each section is a recommended shape: runtime, Brale surface, and the rules that have already paid for themselves. Combine two when the product needs both. Do not copy all seven.

Then follow the linked pages. That is the whole method.

## Self-custody wallet

A person holds their own keys and sends stablecoins. The app is a browser extension, not a Cloudflare app.

| | |
|--|--|
| **Runtime** | Browser extension (WXT + React). Playwright against the **built** extension. |
| **Brale** | Read API only. Prices from `data.brale.xyz/price/{ticker}`. Decoded history from `brale.network/api`. Sends go on-chain. |
| **Do not call** | `api.brale.xyz` for user sends. This architecture is not custodial. |

**Do this**

- Encrypt the vault in extension local storage. Keep the session key in session storage. Decrypted key material stays on the heap and is zero-filled after use.
- Never regenerate the KDF salt when re-sealing. A new salt bricks unlock.
- Race public RPC against the Brale wallet history endpoint. Merge activity on `chain:txHash`. Serve cached balances and refresh in the background.
- On Solana, query both the classic token program and Token-2022. Some Brale-issued stables use Token-2022.
- Link tracked stablecoins to `brale.network/tx/<transferType>/<valueType>/<hash>`.
- Gate privileged messages to extension pages. Take the dapp origin from the browser sender, never from the page.

**Skip this**

- Gasless smart accounts before plain EOA sends work. Dapps often assume an EOA. Prove that path first.
- Unit tests as the only check for content-security policy. A missing `wasm-unsafe-eval` directive has silently broken wallet creation when Argon2id runs through WebAssembly.

**Read next:** [lessons/self-custody-wallet.md](../lessons/self-custody-wallet.md), [security.md](security.md), [brale-api.md](brale-api.md) (read APIs), [testing.md](testing.md)

## Agent wallet

A bot or agent sends stablecoins with no human approval popup. Ship it as a library. Keep browser APIs out of the core package.

| | |
|--|--|
| **Runtime** | TypeScript library. Vitest. Explicit `destroy()` that zero-fills and then throws. |
| **Brale** | Read API as a **balance fallback only** (`brale.network/api/wallet/{chain}/{address}`). Not used to send. |
| **Control** | A policy engine in front of every send: per-send cap, session cap, allowlists. Write the audit log, then reject, before any network call. |

Derive addresses with the same BIP-39 / BIP-44 / SLIP-0010 rules a self-custody wallet would use, so the same mnemonic yields the same addresses. The library can reimplement that crypto. It should not depend on an extension package.

**Read next:** [lessons/agent-wallet.md](../lessons/agent-wallet.md), [brale-api.md](brale-api.md), [security.md](security.md)

## Par settlement

Move Brale-issued stablecoins across chains at par. Liquidity is mint and burn, not AMM depth. A generic bridge stack is the wrong design.

| | |
|--|--|
| **Runtime** | Several Workers split by role (write path, solver, UI), connected with **service bindings**. One Durable Object per order for the lock and the fill loop. A separate sender object so EVM nonces stay serial. |
| **Storage** | D1 for order state, P&L, and anything that must survive a restart. KV for a hot config or kill switch only. |
| **Brale** | `api.brale.xyz`: ION, convert, attestor. `source` must be an **internal custodial** address. External addresses are destinations only. |
| **On-chain** | HTTP-poll confirmations. Workers are a poor place for websocket subscriptions against public RPCs. |

**Do this**

- Deposit on-chain first so Brale can credit a custodial balance, convert or mint, deliver, then reimburse the claim. Custodial balance should net back to zero.
- Verify the Brale HMAC webhook off-chain. Contracts cannot check that HMAC. Re-read the delivery on-chain and re-sign EIP-712 for the verifier.
- Await any step that flips a critical state (`filled`, `claimed`). `ctx.waitUntil()` does not promise the work finished.
- Put revenue rules in code. An unprofitable fill should throw, and CI should fail. Dashboards are not a control.
- Publish capabilities (assets, chains, layers) from config. The UI must refuse an order the solver cannot fill before the user locks funds.
- Use Queues for write-behind archives only. Using them to coordinate the fill path has dropped the large majority of messages.

**Read next:** [lessons/par-settlement.md](../lessons/par-settlement.md), [cloudflare-stack.md](cloudflare-stack.md), [brale-api.md](brale-api.md), [testing.md](testing.md)

## Analytics command center

A real-time view of one account’s transfers: KPIs, charts, and a live feed.

| | |
|--|--|
| **Runtime** | One Worker for the API, webhooks, auth, and the SPA. |
| **State** | D1 for transfers, pre-aggregated daily stats, sessions, and the audit log. A Durable Object as the WebSocket hub, with alarms for polling. Cache API for 10–30s GETs. |
| **Brale** | Full orchestration. OAuth on the Worker. Webhooks plus a 60-second alarm plus a cold-start backfill from `MAX(created_at)`. |
| **UI** | Dollar-first. Every row is `ValueType TransferType Amount`. Filters apply to either leg. |

**Do this**

- `INSERT OR REPLACE` / `INSERT OR IGNORE` so a replayed webhook cannot double-count.
- Pre-compute `daily_stats`. Chart reads should be O(1), not a scan of every transfer.
- Return 200 from the webhook immediately, then do D1 work in `ctx.waitUntil()`.
- Smart Placement so the Worker sits near D1.
- Self-host fonts. A font CDN fights a strict content-security policy.

**Read next:** [lessons/analytics.md](../lessons/analytics.md), [brale-api.md](brale-api.md), [cloudflare-stack.md](cloudflare-stack.md), [value-layer.md](value-layer.md)

## Operations dashboard

A self-hosted dashboard for people who already have Brale API credentials: transfers, contacts, history.

| | |
|--|--|
| **Runtime** | Next.js on Cloudflare (`@opennextjs/cloudflare`). |
| **State** | One Drizzle schema. `better-sqlite3` in dev, D1 in production. KV only for the Next.js incremental cache. |
| **Brale** | Full orchestration. Token cached in server actions, never in the browser. Write the transfer intent locally before the API call, then reconcile with backoff. A 60-second poll covers missed webhooks. |
| **UI** | Recipient first: person, then payment method, then amount. Contact records live in your database. They are not a Brale object. |

Pages read the database, not Brale, after the first sync. That is what makes the UI fast and what lets it work offline once synced.

**Read next:** [lessons/operations-dashboard.md](../lessons/operations-dashboard.md), [brale-api.md](brale-api.md), [cloudflare-stack.md](cloudflare-stack.md), [design-style.md](design-style.md)

## Compliance monitoring

Screen transfers and investigate subjects. Throughput and request latency are different jobs, so they do not share a Worker.

| | |
|--|--|
| **Runtime** | **Two Workers.** The API Worker serves investigators. The processor Worker consumes queues. |
| **State** | D1 for org-scoped records and global intelligence tables. KV for the value-type / transfer-type registry (about a 1 hour TTL) and idempotency keys. R2 for cold access logs and ingest snapshots. |
| **Durable Objects** | Per-org screening, a global re-screen loop via alarms, and per-key rate limits. Not for high-throughput fan-out. That belongs on Queues. |
| **Brale** | Read API for the registry. Screening itself is your API. Map vendor `{network, asset}` pairs onto `{transferType, valueType}`. |
| **Model** | A movement is a leg: `(ValueType, TransferType, Amount)`. CSF for the ordered funds flow. A relationship graph (GSF-shaped) for who connects to whom. |

**Do this**

- Normalize EVM addresses to lowercase before sanctions matching. A case mismatch is a false negative.
- Classify an exchange by what changed: value type only (swap), transfer type only (bridge), or both (cross-rail).
- Keep auth state in D1 or a Durable Object. KV is eventually consistent.

**Read next:** [lessons/compliance.md](../lessons/compliance.md), [cloudflare-stack.md](cloudflare-stack.md), [csf-gsf.md](csf-gsf.md), [value-layer.md](value-layer.md)

## Managed treasury

Onboard businesses onto Brale managed accounts, show one balance, and settle. Card issuing sits on top of this shape. It does not replace it.

| | |
|--|--|
| **Runtime** | Workers + D1 + Cron. Hono and chanfana so Zod schemas are the OpenAPI contract. Vite SPA on Workers Assets. |
| **KV** | Email-code rate limits only. Sessions live in D1. |
| **Brale** | Managed accounts, KYB, documents, transfers, webhooks. |
| **Access** | Invite-gated signup. Admin auth is a separate session and a separate `/admin` surface. One user can belong to many organizations and switch the active one without signing in again. |

**Hard rules**

- Real KYB data is forwarded to Brale and then dropped. Never write it to D1. Never log it. If the call fails, the user submits again.
- Inbound deposits that are not already in the preferred `(value_type, transfer_type)` get one sweep transfer, tagged `sweep:{original_id}` so the webhook does not sweep the sweep.
- Webhooks are primary. A 60-second cron does two jobs: recover stuck local rows, and discover deposits the webhook never mentioned.
- Amounts are decimal strings. Public IDs are prefixed (`org_`, `tr_`, …). Provider IDs stay internal.
- Bank users see “USDC on Base”, not the words ValueType and TransferType. Your API can say `currency` and `chain` and map inward.

**Read next:** [managed-accounts.md](managed-accounts.md), [lessons/managed-treasury.md](../lessons/managed-treasury.md), [security.md](security.md), [cloudflare-stack.md](cloudflare-stack.md)

## Choosing Cloudflare when you are between shapes

| Pressure | Choose |
|----------|--------|
| One product surface, moderate traffic | Single Worker + D1 (analytics) |
| A step must be single-threaded (order, nonce, per-org screen) | Durable Object for that key only |
| Investigators must stay fast while scoring runs | Split API and processor Workers |
| The page must be fast after the first load | Sync into D1 or SQLite; read locally |
| You do not custody and you do not orchestrate | No Cloudflare. Extension or library is enough. |

Detail and gotchas: [cloudflare-stack.md](cloudflare-stack.md).
