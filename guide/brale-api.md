# Brale API

How to call Brale without the usual first-week failures. This page is the map and the sharp edges. The canonical endpoint reference is the Brale docs: [docs.brale.xyz](https://docs.brale.xyz) (machine index at [llms.txt](https://docs.brale.xyz/llms.txt), spec at [api.brale.xyz/openapi](https://api.brale.xyz/openapi)). Reference TypeScript lives in the [Brale Agent Kit](https://github.com/superduperdot/brale-agent-kit).

| Surface | Auth | Use it for |
|---------|------|------------|
| `api.brale.xyz` | OAuth2 bearer token | Accounts, addresses, transfers, automations, webhooks, tokenization |
| `auth.brale.xyz` | Basic (client id and secret) | Minting the bearer token |
| `data.brale.xyz` | None | Stablecoin price-by-ticker and the Commons token index |
| `brale.network/api` | None | Open registry of value types, transfer types, and prices (OpenAPI 3.1 + MCP) |

If you only display balances or history, stay on the read surfaces. Orchestration is a different trust boundary and needs server-held credentials.

## Mental model

Everything on `api.brale.xyz` is a **transfer** between `(value_type × transfer_type)` endpoints, each addressed by an `address_id` inside an `account_id`. There is no separate swap, mint, onramp, or offramp endpoint. The operation is implied by the source and destination pair:

| What you call it | What it actually is |
|------------------|---------------------|
| Onramp | `USD` (`wire` / `ach_debit`) → stablecoin (`base`, `solana`, …) |
| Offramp | stablecoin → `USD` (`wire` / `ach_credit`) |
| Swap | stablecoin → stablecoin (burn and mint at par for Brale-issued tokens) |
| Payout | custodial stablecoin → external on-chain address |

See [transfers](https://docs.brale.xyz/key-concepts/transfers.md) and [value-layer.md](value-layer.md).

## Endpoint map

Grouped by resource. Exact paths and payloads are in the [API reference](https://docs.brale.xyz/llms.txt); this is the shape to hold in your head.

| Resource | Operations | Notes |
|----------|-----------|-------|
| **Accounts** | list, create, get | `account_id` identifies a KYB business or KYC individual, custodial or transactional. KYB/KYC details go in on create. There is **no** `/kyb` endpoint. |
| **Verification documents** | stage, list, link | Two steps: stage a document, then link it to the account. This is how supplemental KYB/KYC verification is submitted. |
| **Addresses** | list, get, create external, create internal, update, **balance** | `source` of a transfer must be an internal (custodial) address. Balance needs both `transfer_type` and `value_type` as query params. An EVM address (`0x…`) works on all EVM chains — register it with every EVM transfer type in one call. |
| **External bank addresses** | Plaid link token → register, or direct entry | Plaid is a two-call flow (link token, then exchange `public_token` for an `address_id`). |
| **Automations** | list, create, get, archive, simulate deposit | Mints to a destination when fiat is received. This is the wire/ACH auto-mint path. `simulate` drives the full testnet flow without real fiat. |
| **Transfers** | list, create, get | `POST` creates. Idempotency key required. See below. |
| **Webhooks** | list event types, create/list/get/update/archive subscription, list delivery attempts | HMAC-signed. See below. |
| **Tokenization** | mint, burn, transfer (list/get each) | Only for tokenization (self-attested) accounts. |

## Authentication

`POST https://auth.brale.xyz/oauth2/token` with `grant_type=client_credentials`. The `Authorization` header is **Basic**: `base64(client_id:client_secret)`. The response carries the bearer token and `expires_in`. Send the bearer token on every `api.brale.xyz` call.

| Do this | Why |
|---------|-----|
| Cache the token; refresh before `expires_in` (tokens last ~60 minutes) | Fetching a token per request adds latency and will rate-limit you |
| De-dupe concurrent refreshes | Parallel Worker requests will otherwise stampede the token endpoint |
| On `401`, request a fresh token and retry the original request once, idempotently | Covers expiry races |
| Keep separate applications for testnet and mainnet | The environment is a property of the credential, not a URL path |

The active environment (testnet vs mainnet) is determined by **which application minted the token**, not by a path prefix. A UI toggle must switch credentials and filter by transfer type, not just hide addresses.

Reference: [reference/auth.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/auth.ts). Docs: [authentication](https://docs.brale.xyz/key-concepts/authentication.md).

## Transfers and idempotency

Create a transfer under an account. Send an `Idempotency-Key` on **every** `POST` that creates a resource, not only transfers — Plaid registration and bank linking count too.

| Situation | Key |
|-----------|-----|
| A new operation | A fresh UUID |
| A logical retry (user or job repeats the same intent) | A deterministic key, such as an order id |
| A retry after a timeout or `5xx` | The **same** key you already sent |

**Rules**

- `source` must be an internal (custodial) address. External addresses are destination-only. (Only internal and Plaid-linked addresses expose balances.)
- Top-level shape is exactly `amount`, `source`, `destination`. Everything is `snake_case` — `value_type` and `transfer_type`, never camelCase. Canonical JSON: [value-layer.md](value-layer.md#canonical-transfer-shape).
- `amount.value` is a decimal string. `amount.currency` is an ISO-4217 code (usually `USD`) and is **separate from `value_type`** — a `MXNe` leg is denominated in MXN, not USD. Keep the value a string end to end.
- `value_type` and `transfer_type` are case-sensitive ids from Coverage: fiat value types are lowercase (`usd`, `mxn`), onchain tokens use their ticker (`SBC`, `USDC`, `MXNe`), rails are lowercase (`wire`, `base`). Use testnet rail ids (`base_sepolia`, `solana_devnet`) on testnet.
- A balance query needs both dimensions: `?transfer_type=base&value_type=SBC`. One without the other is not a balance.
- `api.brale.xyz` does not enumerate the valid `(value_type, transfer_type)` pairs for a specific address — probe the combinations you support and skip errors ([reference/balance-discovery.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/balance-discovery.ts)). For the *global* registry of which value types exist on which chains, read `brale.network/api` (see read surfaces below).
- List endpoints paginate with `page[size]` (1–100) and cursor-based paging. The response `pagination` object returns `next` and `prev` cursor values; pass them back as `page[after]` or `page[before]` query params. `page[cursor]` is also accepted. Send at most one cursor param per request. (Verified against `api.brale.xyz/openapi`, 2026-10-14.)

### Intent-first writes

When a person is waiting on money movement, write the intent to your database **before** calling Brale, then reconcile with exponential backoff, retrying with the original idempotency key. Reference: [reference/reconciler.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/reconciler.ts). This is the default for an [operations dashboard](concepts.md#operations-dashboard) and any [managed treasury](concepts.md#managed-treasury) send.

## Balances

`GET /accounts/{account_id}/addresses/{address_id}/balance?transfer_type=…&value_type=…` — the same endpoint for a custodial wallet and a Plaid-linked bank. Both params are required; a custodial address holds many `(value_type, transfer_type)` pairs, so one dimension is not an answer.

```jsonc
// GET .../balance?transfer_type=base&value_type=SBC
{ "address": { "id": "…", "address": "0x…" },
  "balance": { "value": "45314.07", "currency": "USD" },
  "value_type": "SBC", "transfer_type": "base" }
```

| You want | address | params |
|----------|---------|--------|
| Stablecoin balance of a custodial wallet | an internal (`type=internal`) address — list addresses and pick one | `transfer_type` = chain, `value_type` = token |
| USD balance behind a linked bank | a **Plaid-linked** bank address | `transfer_type=ach_debit`, `value_type=USD` (account number comes back masked) |

**What does not expose a balance:** external self-custody wallets and bank addresses created by Direct bank entry. Only internal custodial and Plaid-linked addresses do — for a self-custody address read the chain. Balance reads may be cached up to ~30s and are point-in-time (a bank balance does not guarantee an ACH debit will settle).

**Only Brale-listed value types are visible.** The balance API is keyed by a supported, case-sensitive `value_type` + `transfer_type` from [Coverage](https://docs.brale.xyz/coverage/value-types.md). There is no "list all tokens at this address" endpoint. An unlisted or arbitrary token sent on-chain to a custodial address has no `value_type` id to query, so it is invisible to the balance API — it exists only as a raw on-chain token transfer. (Observed; the docs do not explicitly document this consequence.)

**Which pairs to poll.** Rather than probing the full cross-product of registry-listed pairs every cycle (which burns Worker subrequests), maintain a **discovered set** of `(value_type, transfer_type)` pairs per address. Seed it from webhook events (`transfer.*`, `payment.completed` name the value types), on-chain/indexed history (map observed token contracts to value types via the [`brale.network/api` registry](#read-surfaces)), and anything the account has transacted. Keep the set current from webhooks; only ever expand it; cache it in D1 or DO storage. Demote the full cross-product probe to a cold-start or reconciliation step. See [sync-engine.md](sync-engine.md) for the full strategy. To show "one number" across chains, query each discovered pair (see [reference/balance-discovery.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/balance-discovery.ts)) and sum.

### Dedicated deposit addresses

When the user deposits before the outbound transfer is created, create one internal address per transfer. The balance on that address is the deposit for that transfer and nothing else. Checking `balance === instructed amount` is clean when the address is not shared.

The same visibility rule applies: only Brale-listed value types are detectable via the balance API. If the user deposits an unlisted token to the dedicated address, neither a webhook nor a balance poll will surface it.

## Webhooks

Subscribe with the webhook subscription API under an account. Verify HMAC-SHA256 over the **raw body bytes**. ([webhook docs](https://docs.brale.xyz/webhooks/overview.md), [signatures](https://docs.brale.xyz/webhooks/signatures.md).)

| Step | Detail |
|------|--------|
| Header | `x-request-signature-sha-256` — lowercase hex, no `v1=` prefix, no timestamp |
| Body | The exact raw bytes. No canonicalization. Read the body before any JSON parse. |
| Key | Base64URL-**decode** the subscription `sharedSecret`, then use the decoded bytes as the HMAC key. Do not HMAC the encoded string. |
| Secret scope | Each subscription has its own `sharedSecret`. Verify a delivery with the secret of the subscription that delivered it. **Do not** look the secret up by `data.account_id` — one managing-account subscription signs events for its managed accounts too. |
| Storage | The `sharedSecret` is returned **once**, at creation. Store it immediately, encrypted. |
| Compare | Constant time. |
| Handler | Deduplicate by event id. For analytics or idempotent writes (`INSERT OR IGNORE`), return `200` and process in `ctx.waitUntil()`. For transfer state transitions — confirming funds, posting a transfer, closing an order — await the write before returning `200`. |
| Scopes | The application needs webhook read and write permissions. |

Reference: [reference/webhook-verify.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/webhook-verify.ts).

### Webhook subscription management

Subscription endpoints live under `/accounts/{account_id}/webhooks`. The path split matters:

| Method | Path | Purpose |
|--------|------|---------|
| GET | `.../webhooks/event_types` | Discover supported event types |
| POST | `.../webhooks` | Create a subscription (returns `sharedSecret` once) |
| GET | `.../webhooks` | List subscriptions |
| GET | `.../webhooks/{subscription_id}` | Get one subscription |
| PATCH | `.../webhooks/subscriptions/{subscription_id}` | Update a subscription |
| DELETE | `.../webhooks/subscriptions/{subscription_id}` | Archive a subscription |
| GET | `.../webhooks/deliveries` | List delivery attempts |
| POST | `.../webhooks/events/{event_id}/resend` | Resend a delivery |

Note the path difference: GET uses `/webhooks/{id}`, but PATCH and DELETE use `/webhooks/subscriptions/{id}`. (Verified against [api.brale.xyz/openapi](https://api.brale.xyz/openapi) and the [webhooks overview](https://docs.brale.xyz/webhooks/overview.md), 2026-10-14.)

Subscribe with wildcard families (`transfer.*`, `payment.*`, `account.*`) to receive future events in a family automatically.

### Webhook event catalog

| Event | When it fires |
|-------|---------------|
| `transfer.created` | A Brale transfer is created |
| `transfer.completed` | A transfer reaches `complete` status |
| `transfer.canceled` | A transfer is canceled |
| `transfer.failed` | A transfer reaches `failed` status (includes ACH returns and wire returns) |
| `payment.completed` | A payment reaches `complete` status (inbound fiat deposits, including testnet Simulate Automation deposits) |
| `account.verification.documents_required` | KYB review needs documents — prompt the user to upload |
| `account.verification.completed` | Account verification passes |
| `account.verification.rejected` | Account verification is declined (terminal — no further events follow) |

An outbound domestic wire can go `transfer.completed` and then later `transfer.failed` if the bank returns the wire. Keep accepting `transfer.failed` for transfers you have already recorded as complete. Inspect `data.failure.type` (`ach_return` or `wire_return`) and `data.failure.retriable` (spelled `retriable`, not `retryable`). `data.failure` can be `null` even on a failed transfer — null-check before reading nested fields.

Use `data.account_id` from the payload to attribute an event to the correct managed account. A managing-account subscription receives events for all accounts it manages plus its own.

(Verified against [docs.brale.xyz/webhooks/webhook-events](https://docs.brale.xyz/webhooks/webhook-events.md), 2026-10-14.)

Contracts cannot verify this HMAC. If an on-chain verifier needs a signature, verify the webhook off-chain, re-read the delivery on-chain, and re-sign (EIP-712 is the pattern that has shipped). That hop belongs to [par settlement](concepts.md#par-settlement).

## Sync

Production integrations that mirror Brale locally use three layers. Webhooks alone will miss events.

| Layer | When | Interval that has worked |
|-------|------|--------------------------|
| Full backfill | Cold start, or any gap since `MAX(created_at)` | Once, then incremental |
| Webhooks | Real time | — |
| Safety-net poll | Missed events, stuck rows | 30–60 seconds |

Read your database in the UI after sync. Do not call Brale on every page view. For managed accounts the poll is four jobs (recover stuck rows, discover unseen deposits, balance sweep, preferred-hold reconciliation); see [managed-accounts.md](managed-accounts.md). For the full sync engine — backfill loop, catch-up cursors, aggregation, and balance-discovery strategy — see [sync-engine.md](sync-engine.md).

## Read surfaces

`brale.network/api` is the **Brale Network API**: a free, open, unauthenticated registry of value types, transfer types, and prices. No keys, no signup. 120 requests/minute per IP (watch the `X-RateLimit-*` headers; back off on `Retry-After`). It is a separate surface from the authenticated `api.brale.xyz` — it describes and prices the value layer, it does **not** move money. Full spec: [`brale.network/api/openapi.json`](https://brale.network/api/openapi.json) (OpenAPI 3.1), plus an MCP server at `brale.network/api/mcp`.

List endpoints return `{ "data": [...] }`; single-resource endpoints return `{ "data": { ... } }`. Errors are `{ "error": { "code", "message" }, "status" }` with codes like `NOT_FOUND` and `RATE_LIMITED`.

| Endpoint | Returns |
|----------|---------|
| `GET /value-type/list`, `/value-type/:id` | Value types. `:id` is a symbol (`sbc`, `usdc`). Each carries `symbol`, `display_name`, `decimals`, `logo_url`, `program`, `transfer_types[]`, `contract_addresses`. |
| `GET /value-type/:id/transfer-type/list` | Which chains carry a value type |
| `GET /transfer-type/list`, `/transfer-type/:id` | Transfer types (chains and rails). `slug`, `ecosystem_family`, `native_symbol`, `status`, `explorer_url`, `value_types[]`. |
| `GET /transfer-type/:id/value-type/list` | Which value types are available on a chain |
| `GET /price/list` | Reference price and 24h primary-market activity for every value type |
| `GET /price/:value_type` | Price with a per-chain `by_transfer_type` breakdown (confirmed live for `sbc`) |
| `GET /price/:value_type/:transfer_type` | Price scoped to one chain |
| `GET /tokenlist/brale.json`, `/tokenlist/:transfer_type` | Deployments in token-list format |
| `GET /llms/static-context.json` | The whole value layer as structured LLM context |

Use this surface for the registry (the authenticated API does not enumerate `(value_type × transfer_type)` pairs for you) and for prices. It **does** serve `logo_url` and `explorer_url` (verified against `brale.network/api/openapi.json`, 2026-10-14), so you may not need a local chain-logo map after all. There is no wallet-history or transaction-lookup endpoint here; for an address's on-chain history, read the chain directly.

`data.brale.xyz` is a simpler price surface: `GET data.brale.xyz/price/{ticker}` → `{ symbol, name, price, currency, details }` (confirmed for `USDC`, `SBC`; unknown tickers `404`, so `/price/list` is not valid there — use `brale.network/api/price/list` for the full set). `data.brale.xyz/data/{ticker}` returns a token list. To get a stablecoin indexed, submit a token list to [Brale-xyz/commons](https://github.com/Brale-xyz/commons) under `Data/` ([docs](https://docs.brale.xyz/documentation/add-your-stablecoin.md)).

## Agents that move money

Put a policy engine and an audit log **in front of** every send. Caps and allowlists reject the call before any network request, and the audit entry is part of the allow, not a log you hope to write later. The read API can fill in a balance when RPC fails; it is not the send path. Detail: [concepts.md](concepts.md#agent-wallet).

## Pitfalls

See the official [troubleshooting page](https://docs.brale.xyz/documentation/troubleshooting.md) too.

| What you will see | What to do |
|-------------------|------------|
| `GET` accounts returns objects **or** bare id strings | Parse both. Do not assume an envelope. |
| IDs look parseable | They are KSUIDs (account, address, transfer, automation alike). Treat them as opaque strings — do not parse, validate by length, or assume UUIDs. |
| `sharedSecret` is Base64URL and shown once | Decode before HMAC. Persist it encrypted at creation. |
| Status strings `complete` and `completed` both appear | The canonical transfer status enum is `pending`, `processing`, `complete`, `canceled`, `failed`, `compliance review`. The webhook event name uses `completed` (`transfer.completed`), the API status field uses `complete`. Accept both. Handle `processing` (in-flight, not stuck) and `compliance review` (held for review, not failed) in your UI — do not treat either as an error. The fail set includes `canceled` (single `l`) — do not test for `cancelled`. (Verified against `api.brale.xyz/openapi`, 2026-10-14.) |
| Value types are case-sensitive, and some collide (`CFUSD` vs `cFtUSD`, `usd` vs `USDC`) | Copy the exact id from Coverage. Do not hardcode a second spelling. |
| “sandbox” vs “testnet” | Brale calls the non-production environment **testnet**, never “sandbox.” |
| Errors follow a structured envelope | Surface the `detail` / message. “Request failed” is not operable. |
| Webhook routes return `401 invalid_signature` | Usually the wrong subscription secret, a parsed body, or a stale env. |
| Fiat legs have no transaction hash; cross-chain legs may have two (burn and mint) | Render 0, 1, or 2 hashes from the payload. Do not invent one. |
| Token expired mid-run | `401` means refresh and retry, not fail. |
| `listTransfers` returns ~25 results with no deeper paging | `page[size]` and `page[after]`/`page[before]` work within one page, but there is a ceiling (~25 items). Do not rely on transfer listing as a complete ledger. Read balances as the backstop. |
| Automation `PATCH`/`DELETE` returns 404 or 422 | Automations are immutable once created. Create a new one targeting the updated destination. The old one stays active until archived. |
| 403 "Incorrect API key for requested network" on a balance or transfer call | The address belongs to a different environment (testnet vs mainnet) than the token you are using. Filter addresses by environment before operating on them. |
| Cron Trigger exceeds subrequest limit | A poller that reads balances, submits sweeps, and sends emails across many accounts can exhaust the Worker subrequest budget. Process high-priority accounts first and stop early if the budget is low. |
| Unsolicited stablecoin deposit to a custodial address — no webhook fires | The dividing line is whether Brale originated the movement. A fiat inbound via automation is a **mint** (a Brale Transfer), so it fires `transfer.*` + `payment.completed`. On-chain legs of any Brale-originated transfer also fire `transfer.*`. The only case with **no** webhook is an unsolicited arrival of already-minted stablecoins sent directly on-chain to a custodial address — Brale neither minted nor moved them, so there is no Transfer or Payment object. Poll `GET .../addresses/{id}/balance` on an alarm to detect these. The alarm is the primary detection path for unsolicited arrivals, not a safety net. Additionally, only Brale-listed value types are queryable — an unlisted token sent to the custodial address is invisible to the balance API as well (see Balances above). |
| `POST .../addresses/internal` returns `address: null` | Internal address creation is asynchronous. The response may have `status: "pending"` with no on-chain address yet. Poll `GET .../addresses/{id}` until `status` is `"active"` and `address` is non-null. |
| `POST .../addresses/external` returns `409` | The address string is already registered on this account. List addresses to find the existing one. If it needs an additional chain, `PATCH .../addresses/{id}` with `additional_transfer_types`. |
| External address used as `source` returns `404` | `source` must be an internal (custodial) address. External addresses are destination-only. |
| Inbound ACH per-transaction cap | Inbound ACH is capped (re-verify the current limit against [docs.brale.xyz](https://docs.brale.xyz)). Wire and stablecoin inbound are uncapped. |
| `webhooks:read`/`write` scopes missing on older API keys | Webhook permissions are only available on API keys created after a certain date. If your key predates the cutoff, regenerate it. (Re-verify the cutoff date against docs.) |
| `Accept: application/json` on webhook management calls returns `500` | Do not send the `Accept` header on webhook subscription PATCH, DELETE, or delivery listing calls — it can produce a `500` with an empty body. |

## Managed accounts

Business onboarding, verification documents, automations, auto-sweep, and the user-facing status machine are a separate flow. Use [managed-accounts.md](managed-accounts.md). Do not bolt KYB fields onto a transfer schema, and do not store the KYB payload.

## Related

- [concepts.md](concepts.md) — which surface each architecture calls
- [managed-accounts.md](managed-accounts.md)
- [cloudflare-stack.md](cloudflare-stack.md)
- [durable-objects.md](durable-objects.md) — alarm-based deposit detection, nonce DOs
- [sync-engine.md](sync-engine.md) — backfill, aggregation, balance discovery
- [value-layer.md](value-layer.md)
- [security.md](security.md)
