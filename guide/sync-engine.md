# Sync engine

Operate the three-layer sync pattern from [brale-api.md](brale-api.md#sync). This page covers the backfill loop, catch-up cursors, idempotent aggregation, balance discovery, and multi-account credential handling.

## Three layers

| Layer | When | Interval |
|-------|------|----------|
| Full backfill | Cold start or gap since `MAX(created_at)` | Once, then incremental |
| Webhooks | Real time | — |
| Safety-net poll | Missed events, stuck rows | 30–60 seconds |

Webhooks alone will miss events. The poll alone is too slow for UX. Run all three.

## Backfill

Loop `listTransfers` with cursor-based paging until the API returns an empty page:

```
cursor = null
do {
  page = listTransfers({ page[size]: 100, page[after]: cursor })
  upsert(page.data)
  cursor = page.pagination.next
  sleep(200ms)            // throttle — respect rate limits
} while (cursor && pages < MAX_PAGES)
```

| Rule | Detail |
|------|--------|
| Pagination param | `page[after]` (or `page[before]`). `page[next]` is **not** a valid query param. |
| Rate-limit handling | On `429` or `5xx`, exponential backoff capped at ~30 s. |
| Max-pages guard | Cap at ~50 pages per run. Resume from the last cursor on the next cycle. |
| `sync_status` | Set `syncing` before the loop, `complete` or `error` when it finishes. |
| User-triggered backfill | Run under `ctx.waitUntil` so the HTTP response returns immediately. |

## Catch-up cursor

The cursor is `MAX(created_at)` from your local table. But `created_at` alone misses status changes on older rows.

| Pass | What it catches |
|------|-----------------|
| Forward pass (`created_at > cursor`) | New transfers |
| Update pass (`updated_at > cursor`) | Status transitions on older rows (`complete` → `failed` from a wire return) |

Stop when a page yields zero new rows **and** zero updated rows. Advance the cursor to the highest `created_at` (or `updated_at`, whichever is later) you saw.

## Safety poll

A bounded recent window, not a deep scan.

| Parameter | Value |
|-----------|-------|
| Window | ~2 × 100 most recent transfers |
| Frequency | 30–60 s (Cron Trigger or DO alarm) |
| Work | Upsert any rows newer than your local copy. Reconcile ledger vs balance for anything the list window drops. |

For balance-vs-ledger reconciliation logic, see [lessons/balance-reconciliation.md](lessons/balance-reconciliation.md).

## Idempotent aggregation

Pre-compute `daily_stats` per `(account, date, network)`. Never mutate stats with `+= increment`. Recompute by re-selecting all transfers for that composite key.

| Step | Detail |
|------|--------|
| Key | `(account_id, date, transfer_type)` |
| Source | `SELECT` all transfers matching the key |
| Breakdown | Both source and destination legs increment counts and volume |
| Write | `INSERT OR REPLACE` the recomputed row |

An idempotent recompute means a replayed webhook cannot corrupt charts. A `+= 1` on a counter **can**.

## Reconciler key reuse

The reconciler **must** reuse the stored idempotency key on retry, not generate a fresh UUID.

| Wrong | Right |
|-------|-------|
| Generate a new UUID on each retry of `createTransfer` | Store the idempotency key with the intent row and resend it |

A real bug: a reconciler called `createTransfer` with a new UUID on each retry. Each call created a **separate** transfer instead of replaying idempotently. The fix is to generate the key once when the intent is written and pass it on every subsequent attempt.

Reference: reconciler.ts in the agent kit.

## Multi-account credentials

| Rule | Detail |
|------|--------|
| Credentials per account | Store `client_id` and `client_secret` per account row, encrypted in D1. |
| Environment is the credential | Testnet vs mainnet is determined by which application minted the token, not a URL path. |
| Explicit account pick | If `listAccounts` returns more than one account, force the user to choose. Do not assume the first. |

## Balance discovery — which pairs to poll

The balance API is keyed by `(value_type, transfer_type)`. There is no enumerate-all-tokens endpoint. Probing the full cross-product of registry-listed pairs every cycle burns Worker subrequests (50 on free, 1 000 on paid). Maintain a **per-address discovered set** instead.

### Seed the set

| Source | How | Coverage |
|--------|-----|----------|
| Webhook events | `transfer.*`, `payment.completed` name the value types | Cheap, real-time, but only fires for transfers originated through the API |
| On-chain / indexed history | Map observed token contracts to value types via the registry (`contract_addresses` / `deployments`) | Catches external inbound that the API did not originate |
| Account transaction history | Anything the account has transacted | Baseline |

### Why `listTransfers` is not enough

`listTransfers` returns only API-originated transfers and is capped at ~25 results. It misses unsolicited listed-token deposits sent directly on-chain.

### Rules

| # | Rule |
|---|------|
| 1 | Only ever **expand** the set. Never remove a pair. |
| 2 | Cache the set in D1 or DO storage. |
| 3 | Demote the full cross-product probe to a rare cold-start or reconciliation step. |

### The residual gap

An unsolicited deposit of a listed value type not yet in the discovered set produces no webhook and has not been discovered yet. Catch it with:

1. A periodic bounded probe of that chain's registry-listed pairs.
2. The balance-vs-ledger reconciliation job (see [lessons/balance-reconciliation.md](lessons/balance-reconciliation.md)).

These two together close the gap without burning the subrequest budget every cycle.

## Putting it together

```
Cold start
  → full backfill (cursor paging, backoff, max-pages guard)
  → seed discovered set from backfill + registry

Steady state
  → webhooks arrive, upsert transfers, expand discovered set
  → safety poll every 30–60 s (bounded window, reconcile ledger vs balance)
  → recompute daily_stats for any touched (account, date, network) key

Reconciliation (rare)
  → full cross-product balance probe
  → bounded registry-pair probe for the residual gap
```

## Related

- [brale-api.md](brale-api.md) — balances, sync, transfer mechanics
- [managed-accounts.md](managed-accounts.md) — poller jobs, sweep logic
- [cloudflare-stack.md](cloudflare-stack.md) — Worker primitives, subrequest budgets
- [lessons/balance-reconciliation.md](lessons/balance-reconciliation.md) — ledger-vs-balance reconciliation
