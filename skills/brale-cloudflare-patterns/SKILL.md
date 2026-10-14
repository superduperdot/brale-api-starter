---
name: brale-cloudflare-patterns
description: >-
  Choose the right Cloudflare primitive and avoid DO/queue/sync pitfalls for
  Brale apps. Use when deciding between Workers, D1, Durable Objects, KV, R2,
  Queues, or Cron, or when debugging a Cloudflare deployment issue in a Brale
  integration.
disable-model-invocation: true
---

# Brale Cloudflare patterns

Which primitive to use and the patterns that have held up across Brale integrations.

## Primitive decision table

| You need | Use | Do not use |
|----------|-----|------------|
| HTTP API and static assets | **Workers** | A long-lived Node server |
| Relational data at the edge | **D1** | KV for rows you will query |
| A lock, websocket hub, per-key rate limit, nonce sequence | **Durable Objects** | A DO as a high-throughput fan-out bus |
| A loop that must survive the request ending | **DO alarms** or **Cron Triggers** | `setTimeout` in a Worker |
| A cache, feature flag, idempotency marker | **KV** | KV for sessions or authorization |
| Bulk or cold storage | **R2** | R2 on the user-facing path |
| Retried background work | **Queues** | Queues to coordinate a request or a fill |
| Short GET caching | **Cache API** | — |
| Hashing, HMAC, AES-GCM | **Web Crypto** | Node `crypto` |

## Durable Object patterns

1. **One instance per key** — `blockConcurrencyWhile` during init.
2. **Alarm as primary loop, cron as watchdog** — alarm re-arms; `/ensureAlarm` sets only when `getAlarm()` is null.
3. **Deposit-first transfer DO** — alarm polls balance for unsolicited arrivals only (Brale-originated transfers fire webhooks). Write idempotency key before the POST.
4. **Nonce DO** — `max(stored, getTransactionCount('pending'))`. One sender DO per wallet; round-robin for parallelism.
5. **WebSocket hub** — `acceptWebSocket`; gate on a session token; internal `/broadcast` with `X-Internal-Secret`.
6. **Migration tags** — each new class gets its own `new_sqlite_classes` tag.

Full details: `guide/durable-objects.md`.

## Sync engine (three layers)

| Layer | When | Interval |
|-------|------|----------|
| Full backfill | Cold start or gap | Once, then incremental |
| Webhooks | Real time | — |
| Safety-net poll | Missed events, stuck rows | 30–60 s |

- Paginate with `page[after]` (not `page[next]`).
- Catch-up cursor = `MAX(created_at)` + re-import where `updated_at > cursor`.
- Idempotent aggregation: recompute `daily_stats` by re-selecting, not `+=`.
- Balance discovery: maintain a per-address discovered set, not a full cross-product probe.

Full details: `guide/sync-engine.md`.

## Queue pitfalls

- `send()` succeeds even when delivery is paused — messages silently accumulate.
- Exactly one consumer per queue. Two consumers → last deploy silently wins.
- Observed delivery rate under the wrong configuration: ~0.9%.

## Deploy checklist

- [ ] `workers_dev = false` on internal Workers
- [ ] Runtime hostname gate on the gateway Worker
- [ ] Resource-name prefixing on shared accounts
- [ ] Preflight script blocks prod deploy without required env flags
- [ ] CSP headers set; fonts self-hosted
- [ ] Financial responses: `cache-control: no-store`
- [ ] `tsconfig.worker.json` split for DO/Worker code

## Reference

- `guide/cloudflare-stack.md` — full primitive guide
- `guide/durable-objects.md` — DO patterns deep-dive
- `guide/sync-engine.md` — backfill, cursors, balance discovery
