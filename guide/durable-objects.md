# Durable Objects

Cross-cutting patterns for Durable Objects in apps that talk to the Brale API on Cloudflare. Each section is a pattern you will reuse across architectures.

## One instance per key

A Durable Object is a lock, a websocket hub, a per-key rate limit, or a nonce sequence. Name it by the key it owns (an organization, an order, an API key).

| Rule | Why |
|------|-----|
| Call `blockConcurrencyWhile` during `constructor` or first access | Guarantees storage is loaded before any request handler runs |
| Never share a DO id across unrelated concerns | One DO = one coordination boundary. Mixing order state and rate limits in the same object couples their lifecycles. |

## Alarm as primary loop, cron as watchdog

`alarm()` re-arms itself with `storage.setAlarm(Date.now() + pollMs)`. A Cron Trigger keeps the DO alive after isolate eviction — it does not do the work.

| Component | Responsibility |
|-----------|----------------|
| `alarm()` | Run the poll / sweep / reconciliation. Re-arm at the end. |
| Cron Trigger | Hit an idempotent `/ensureAlarm` route on the DO |
| `/ensureAlarm` handler | `if ((await this.storage.getAlarm()) === null) await this.storage.setAlarm(Date.now() + pollMs)` |

The `/ensureAlarm` check prevents every cron tick from duplicating the alarm. Cron is the heartbeat; the alarm is the loop.

## Deposit-first transfers

When a transfer starts with a user deposit to a custodial address, one DO per transfer owns the full lifecycle.

### Lifecycle

| Step | Actor | Detail |
|------|-------|--------|
| 1. Detect deposit | Alarm | Poll `GET .../addresses/{id}/balance` on a timer |
| 2. Write idempotency key | DO storage | `await storage.put('idempotencyKey', key)` **before** the API call, so a crash mid-flight retries safely |
| 3. Post transfer | DO | `POST /transfers` with the stored key |
| 4. Receive webhook | Worker → DO | The webhook wakes the DO, but the DO reads the API to confirm status before transitioning |
| 5. Terminal state | DO | Mark complete or failed. Stop the alarm. |

The alarm is the safety net if the webhook never arrives.

### What webhooks do and do not cover

| Scenario | Webhook fires? | Detection path |
|----------|---------------|----------------|
| Brale-originated transfer (mint, swap, payout) | **Yes** — `transfer.*` events | Webhook (alarm as backup) |
| Fiat inbound via automation (ACH, wire) | **Yes** — `payment.completed` | Webhook (alarm as backup) |
| Unsolicited arrival of an already-minted, Brale-listed stablecoin | **No** | Alarm-driven balance poll is the **primary** path |
| Unlisted token sent to the custodial address | **No** — invisible to both webhooks and the balance API (no `value_type` to query) | Not detectable via the API; read the chain directly |

The alarm is only needed as primary detection for unsolicited arrivals of tokens that are already minted and listed. Everything Brale originates fires a webhook.

## Nonce reconciliation

One sender DO per hot wallet. The DO owns the nonce.

```typescript
await this.blockConcurrencyWhile(async () => {
  const stored = (await this.storage.get<number>("nonce")) ?? 0;
  const pending = await provider.getTransactionCount(wallet, "pending");
  this.nonce = Math.max(stored, pending);
});
```

| Problem | Cause | Fix |
|---------|-------|-----|
| `nonce too low` | An out-of-band send made the stored counter stale | `max(stored, getTransactionCount('pending'))` on init |
| Parallel sends collide | Two requests hit the same nonce | One sender DO per wallet; `blockConcurrencyWhile` serializes |
| Need parallelism | One wallet is a bottleneck | Round-robin across a wallet pool. Each wallet gets its own sender DO. |

### Scope caveat

A submit-safe nonce DO is not a full confirmation tracker. Do not assume transaction lifecycle (confirmation, retry, stuck-nonce self-transfer) lives in the DO unless you have built that layer explicitly.

## Bigint-safe JSON across DO RPC

`uint256` contract arguments exceed `Number.MAX_SAFE_INTEGER`. Plain `JSON.stringify` loses precision or throws.

| Direction | Pattern |
|-----------|---------|
| POST body into a DO | Wrap bigints: `{ __bigint__: '115792089237316195423570985008687907853269984665640564039457584007913129639935' }` |
| DO storage | Store as string or use a reviver/replacer pair |
| Response from DO | Unwrap on the caller side |

Do not rely on native `JSON.parse` for values above `2^53 - 1`. A round-trip through plain JSON will silently corrupt a token amount.

## WebSocket hub

Use `acceptWebSocket` in the DO. Other handlers fan out by POSTing JSON to an internal `/broadcast` route on the same DO.

| Concern | Pattern |
|---------|---------|
| Upgrade gate | Verify a session token **before** calling `acceptWebSocket`. Do not pass user identity as a query param that the DO trusts without re-verification. |
| Fan-out | Any handler (webhook processor, alarm) POSTs to the DO's internal `/broadcast` route with a shared secret in the `X-Internal-Secret` header |
| Heartbeat | The alarm self-POSTs to an internal `/poll` route (same shared secret), then broadcasts the result |
| Stale connections | `alarm()` iterates `getWebSockets()` and closes any that missed the last heartbeat |

Keep the internal secret in a Worker secret (`env.INTERNAL_SECRET`). Do not hardcode it.

## DO migrations

Adding a new Durable Object class requires its own `new_sqlite_classes` migration tag in `wrangler.jsonc`.

| Mistake | Consequence |
|---------|-------------|
| Sharing a migration tag with an existing class | Can break the existing class's storage or prevent the new class from initializing |
| Forgetting the migration entry entirely | The runtime does not recognize the class; requests to the DO return an error |

```jsonc
// wrangler.jsonc
{
  "migrations": [
    { "tag": "v1", "new_sqlite_classes": ["TransferDO"] },
    { "tag": "v2", "new_sqlite_classes": ["SenderDO"] }
  ]
}
```

Each class gets its own tag. Order matters — append new tags, do not rewrite old ones.

## Quick-reference table

| Pattern | Key construct | When to use |
|---------|--------------|-------------|
| One instance per key | `blockConcurrencyWhile` | Any per-entity coordination |
| Alarm loop + cron watchdog | `setAlarm` / `/ensureAlarm` | Polling, sweeping, reconciliation |
| Deposit-first transfer DO | Alarm poll → idempotent POST | User deposits before the outbound transfer |
| Nonce sender DO | `max(stored, pending)` | EVM sends from a hot wallet |
| Bigint wrapper | `{ __bigint__: '...' }` | `uint256` args across DO RPC |
| WebSocket hub | `acceptWebSocket` + `/broadcast` | Live feeds, dashboards |
| Migration tag per class | `new_sqlite_classes` | Every new DO class in `wrangler.jsonc` |

## Related

- [cloudflare-stack.md](cloudflare-stack.md) — primitives decision guide, shapes that have shipped
- [brale-api.md](brale-api.md) — webhooks, sync, idempotency
- [sync-engine.md](sync-engine.md) — backfill, catch-up cursors, balance discovery
- [concepts.md](concepts.md) — par settlement, analytics command center
