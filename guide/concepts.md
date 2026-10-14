# Architectures

Pick the closest job. Each section is a recommended shape: runtime, Brale surface, and the rules that have already paid for themselves. Combine two when the product needs both. Do not copy all seven.

Then follow the linked pages. That is the whole method.

## Self-custody wallet

A person holds their own keys and sends stablecoins. The app is a browser extension, not a Cloudflare app.

| | |
|--|--|
| **Runtime** | Browser extension (WXT + React). Playwright against the **built** extension. |
| **Brale** | Read API only. Prices and the token registry (contract addresses, decimals, explorer URLs) from `brale.network/api`. Sends and balances go on-chain. |
| **Custody** | The *user* holds their own keys, so their balance is not Brale-custodied. Sign and broadcast user sends on-chain — do not create them as `api.brale.xyz` transfers, whose `source` is always a Brale-custodied internal address. (`api.brale.xyz` is the custodial/managed surface; using it to move the user's funds would make the wallet custodial.) |
| **Still fine to use `api.brale.xyz` for** | Your own (parent) account, and fiat on/off-ramps that land on the user's self-custody address as an **external destination** — that is a *transactional* managed account, not a Brale-held balance. See [Brale's self-custody wallet pattern](https://docs.brale.xyz/guides/self-custody-wallets.md). |

**Do this**

- Encrypt the vault in extension local storage. Keep the session key in session storage. Decrypted key material stays on the heap and is zero-filled after use.
- Never regenerate the KDF salt when re-sealing. A new salt bricks unlock.
- Read balances and history on-chain (RPC / an indexer). Use `brale.network/api/value-type/:id` to know which contract and `decimals` to decode. Merge activity on `chain:txHash`. Serve cached balances and refresh in the background.
- On Solana, query both the classic token program and Token-2022. Some Brale-issued stables use Token-2022.
- Build explorer links from the chain's `explorer_url` in `brale.network/api/transfer-type/:id` plus the tx hash.
- Gate privileged messages to extension pages. Take the dapp origin from the browser sender, never from the page.
- Ship with EOA sends first. Gasless smart accounts (ERC-4337) can come later — dapps assume an EOA.
- Default to the side panel (Chrome 114+); toggle persists. See [durable-objects.md](durable-objects.md) only when the extension has a backend Worker.
- Stale-while-revalidate balances: paint cached, refresh behind; skip refresh if last fetch < 30s.
- On Solana, batch `getTokenAccountsByOwner` for both `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` and `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb` (Token-2022) in one RPC call.

**Skip this**

- Gasless smart accounts before plain EOA sends work. Dapps often assume an EOA. Prove that path first.
- Unit tests as the only check for content-security policy. A missing `wasm-unsafe-eval` directive has silently broken wallet creation when Argon2id runs through WebAssembly.

**Read next:** [lessons/self-custody-wallet.md](../lessons/self-custody-wallet.md), [security.md](security.md), [brale-api.md](brale-api.md) (read APIs), [testing.md](testing.md), [durable-objects.md](durable-objects.md)

## Agent wallet

A bot or agent sends stablecoins with no human approval popup. Ship it as a library. Keep browser APIs out of the core package.

| | |
|--|--|
| **Runtime** | TypeScript library. Vitest. Explicit `destroy()` that zero-fills and then throws. |
| **Brale** | `brale.network/api` for the token registry and prices (which contract, which `decimals`, current price). Balances come from chain RPC. Not used to send. |
| **Control** | A policy engine in front of every send: per-send cap, session cap, allowlists. Write the audit log, then reject, before any network call. |

Derive addresses with the same BIP-39 / BIP-44 / SLIP-0010 rules a self-custody wallet would use, so the same mnemonic yields the same addresses. The library can reimplement that crypto. It should not depend on an extension package.

**Do this**

- Policy engine config shape: `{ maxPerSend?, maxPerSession?, allowedRecipients?, allowedTokens?, allowedChains? }`. `check('send', params)` before any network call; `recordSpend` after success. Caps use decimal-string comparison, never `parseFloat`.
- Audit log records happen before the network call, not after. On block: record then throw.
- Pinned derivation test vectors: share them between the extension and the agent library so one mnemonic yields the same addresses.

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
- Reconcile the nonce: `nonce = max(stored, getTransactionCount({blockTag: 'pending'}))` inside `blockConcurrencyWhile`. One sender DO per hot wallet; round-robin for parallelism. See [durable-objects.md](durable-objects.md).
- Use two verifier DOs (primary/secondary RPC) and proceed only when fields match. A single RPC can lag or return stale state.
- Cap `eth_getLogs` block range (e.g. 9 blocks). Advance the cursor only over scanned blocks — do not skip ahead on a backlog.
- Enroll pending orders in DO storage (`p:${orderId}`) before advancing the `getLogs` cursor. A mid-scan crash cannot orphan intents.
- Recompute `orderId(order)` on-chain before issuing a refund. A mismatch → mark `error`, refuse the transaction.
- Set exposure caps in env vars (`MAX_FILL_NOTIONAL_USD`, `MAX_DAILY_NOTIONAL_USD`, `MIN_SENDER_WEI`). Back the daily cap with a D1 `sumNotionalSince` query.
- After an on-chain deposit, poll the Brale custodial **balance** API before calling convert. On-chain confirmation does not mean the balance is credited — there is a crediting lag (~15–20 seconds observed).
- Never use one global `decimals` constant across chains. The same token symbol can have different decimals per chain/VM.

**Read next:** [lessons/par-settlement.md](../lessons/par-settlement.md), [cloudflare-stack.md](cloudflare-stack.md), [brale-api.md](brale-api.md), [testing.md](testing.md), [durable-objects.md](durable-objects.md), [sync-engine.md](sync-engine.md)

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
- Use a Durable Object as the WebSocket hub. Other handlers POST to an internal `/broadcast` route. The alarm sends heartbeats and triggers a self-POST to the internal poll route. See [durable-objects.md](durable-objects.md).
- Pre-compute `daily_stats` by re-selecting, not by `+=` increment. An idempotent recompute means a replayed webhook cannot corrupt charts. See [sync-engine.md](sync-engine.md).
- Read `daily_stats` in chart queries, not raw transfers.
- Use `page[after]` for sync pagination (not `page[next]`). See [sync-engine.md](sync-engine.md).

**Read next:** [lessons/analytics.md](../lessons/analytics.md), [brale-api.md](brale-api.md), [cloudflare-stack.md](cloudflare-stack.md), [value-layer.md](value-layer.md), [durable-objects.md](durable-objects.md), [sync-engine.md](sync-engine.md)

## Operations dashboard

A self-hosted dashboard for people who already have Brale API credentials: transfers, contacts, history.

| | |
|--|--|
| **Runtime** | Next.js on Cloudflare (`@opennextjs/cloudflare`). |
| **State** | One Drizzle schema. `better-sqlite3` in dev, D1 in production. KV only for the Next.js incremental cache. |
| **Brale** | Full orchestration. Token cached in server actions, never in the browser. Write the transfer intent locally before the API call, then reconcile with backoff. A 60-second poll covers missed webhooks. |
| **UI** | Recipient first: person, then payment method, then amount. Contact records live in your database. They are not a Brale object. |

Pages read the database, not Brale, after the first sync. That is what makes the UI fast and what lets it work offline once synced.

**Do this**

- The reconciler must reuse the stored idempotency key on retry. A fresh UUID per attempt creates duplicate transfers.
- A transfer lifecycle Durable Object with alarm-based backoff can manage multi-step settle flows. See [durable-objects.md](durable-objects.md).

**Read next:** [lessons/operations-dashboard.md](../lessons/operations-dashboard.md), [brale-api.md](brale-api.md), [cloudflare-stack.md](cloudflare-stack.md), [design-style.md](design-style.md), [durable-objects.md](durable-objects.md)

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
- Use a Durable Object per organization for screening state, a global DO (or small set) for scheduled re-screening via alarms, and one DO per API key for rate limits. Fan-out stays on Queues (or HTTP POST). See [durable-objects.md](durable-objects.md).
- Cache the value-type/transfer-type registry map in KV with a ~1-hour TTL. The registry response includes a `deployments` object mapping per-network contract addresses.

**Read next:** [lessons/compliance.md](../lessons/compliance.md), [cloudflare-stack.md](cloudflare-stack.md), [csf-gsf.md](csf-gsf.md), [value-layer.md](value-layer.md), [durable-objects.md](durable-objects.md)

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

**Do this**

- Cap expensive poller work: `MAX_ACCOUNTS_PER_CYCLE` (e.g. 5 live + rotating testnet slice). Process live before testnet, stuck before healthy.
- Deduplicate in-flight balance sweeps: skip if `transfers` has `status='settling'` and `note LIKE 'sweep:balance:…'`.
- Store the preferred hold in a `platform_config` table per environment, not env vars.
- The balance-sweep job iterates the address’s discovered value-type set (seeded from webhooks + on-chain history, per [sync-engine.md](sync-engine.md)), not the full registry cross-product.

**Read next:** [managed-accounts.md](managed-accounts.md), [lessons/managed-treasury.md](../lessons/managed-treasury.md), [security.md](security.md), [cloudflare-stack.md](cloudflare-stack.md), [sync-engine.md](sync-engine.md)

## Choosing Cloudflare when you are between shapes

| Pressure | Choose |
|----------|--------|
| One product surface, moderate traffic | Single Worker + D1 (analytics) |
| A step must be single-threaded (order, nonce, per-org screen) | Durable Object for that key only |
| Investigators must stay fast while scoring runs | Split API and processor Workers |
| The page must be fast after the first load | Sync into D1 or SQLite; read locally |
| You do not custody and you do not orchestrate | No Cloudflare. Extension or library is enough. |

Detail and gotchas: [cloudflare-stack.md](cloudflare-stack.md).
