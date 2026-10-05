# Brale API

How to call Brale without the usual first-week failures. This page is the map and the sharp edges. The canonical endpoint reference is the Brale docs: [docs.brale.xyz](https://docs.brale.xyz) (machine index at [llms.txt](https://docs.brale.xyz/llms.txt), spec at [api.brale.xyz/openapi](https://api.brale.xyz/openapi)). Reference TypeScript lives in the [Brale Agent Kit](https://github.com/superduperdot/brale-agent-kit).

| Surface | Auth | Use it for |
|---------|------|------------|
| `api.brale.xyz` | OAuth2 bearer token | Accounts, addresses, transfers, automations, webhooks, tokenization |
| `auth.brale.xyz` | Basic (client id and secret) | Minting the bearer token |
| `data.brale.xyz` | None | Stablecoin price-by-ticker and the Commons token index |
| `brale.network/api` | None | Free read API: prices, transaction lookup, wallet history (separate surface) |

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
| **Addresses** | list, get, create external, create internal, update, **balance** | `source` of a transfer must be an internal (custodial) address. Balance needs both `transfer_type` and `value_type` as query params. |
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

- `source` must be an internal (custodial) address. External addresses are destination-only.
- `amount.currency` is always `"USD"` (the unit of account). `amount.value` is a decimal string. Keep it a string end to end. See [value-layer.md](value-layer.md).
- A balance query needs both dimensions: `?transfer_type=base&value_type=SBC`. One without the other is not a balance.
- The API does not enumerate valid `(value_type, transfer_type)` pairs for an address. Probe the combinations you support and skip errors. Reference: [reference/balance-discovery.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/balance-discovery.ts).

### Intent-first writes

When a person is waiting on money movement, write the intent to your database **before** calling Brale, then reconcile with exponential backoff, retrying with the original idempotency key. Reference: [reference/reconciler.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/reconciler.ts). This is the default for an [operations dashboard](concepts.md#operations-dashboard) and any [managed treasury](concepts.md#managed-treasury) send.

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
| Handler | Return `200` immediately. Deduplicate by event id before side effects. Do the write in `ctx.waitUntil()`. |
| Scopes | The application needs webhook read and write permissions. |

Reference: [reference/webhook-verify.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/webhook-verify.ts).

Contracts cannot verify this HMAC. If an on-chain verifier needs a signature, verify the webhook off-chain, re-read the delivery on-chain, and re-sign (EIP-712 is the pattern that has shipped). That hop belongs to [par settlement](concepts.md#par-settlement).

## Sync

Production integrations that mirror Brale locally use three layers. Webhooks alone will miss events.

| Layer | When | Interval that has worked |
|-------|------|--------------------------|
| Full backfill | Cold start, or any gap since `MAX(created_at)` | Once, then incremental |
| Webhooks | Real time | — |
| Safety-net poll | Missed events, stuck rows | 30–60 seconds |

Read your database in the UI after sync. Do not call Brale on every page view. For managed accounts the poll is two jobs (recover stuck rows, discover unseen deposits); see [managed-accounts.md](managed-accounts.md).

## Read surfaces

`brale.network/api` is the free, unauthenticated read API (prices, transaction lookup, wallet history). It is a separate surface from the authenticated `api.brale.xyz`, and it is not covered by the [api.brale.xyz docs](https://docs.brale.xyz). Treat it as a convenience and a fallback, not a dependency — it can be slow, and the exact response shape is not formally specced.

| Surface | Verified shape | Use |
|---------|----------------|-----|
| `data.brale.xyz/price/{ticker}` | `{ symbol, name, price, currency, details }` — confirmed for `USDC`, `SBC`; unknown tickers return `404 {"error":"No price found..."}` | USD price for one stablecoin. The ticker is a symbol indexed through Brale Commons, not `list`. |
| `data.brale.xyz/data/{ticker}` | A token-list JSON (`name`, `tokens[]` with `chainId`, `address`, `decimals`, `logoURI`) | Token metadata for an indexed stablecoin |
| `brale.network/api/wallet/{chain}/{address}` | Not formally specced; can be slow | Decoded stablecoin history, and a balance fallback when RPC returns nothing (sum in and out by `value_type`) |
| `brale.network/api` | Display names and explorer URLs per chain | Chain metadata. It does **not** serve logo URLs — keep a local logo map. |

To add a stablecoin to the `data.brale.xyz` index, submit a token list to [Brale-xyz/commons](https://github.com/Brale-xyz/commons) under `Data/` ([docs](https://docs.brale.xyz/documentation/add-your-stablecoin.md)).

## Agents that move money

Put a policy engine and an audit log **in front of** every send. Caps and allowlists reject the call before any network request, and the audit entry is part of the allow, not a log you hope to write later. The read API can fill in a balance when RPC fails; it is not the send path. Detail: [concepts.md](concepts.md#agent-wallet).

## Pitfalls

See the official [troubleshooting page](https://docs.brale.xyz/documentation/troubleshooting.md) too.

| What you will see | What to do |
|-------------------|------------|
| `GET` accounts returns objects **or** bare id strings | Parse both. Do not assume an envelope. |
| IDs are not one format (transfers are UUIDs; other resources use KSUIDs) | Do not write one id parser for everything. |
| `sharedSecret` is Base64URL and shown once | Decode before HMAC. Persist it encrypted at creation. |
| Status strings `complete` and `completed` both appear | Accept both. |
| Value types are case-sensitive (`SBC`, `cfUSD`) | Drive them from the registry. Do not hardcode a second spelling. |
| Errors follow a structured envelope | Surface the `detail` / message. “Request failed” is not operable. |
| Webhook routes return `401 invalid_signature` | Usually the wrong subscription secret, a parsed body, or a stale env. |
| Fiat legs have no transaction hash; cross-chain legs may have two (burn and mint) | Render 0, 1, or 2 hashes from the payload. Do not invent one. |
| Token expired mid-run | `401` means refresh and retry, not fail. |

## Managed accounts

Business onboarding, verification documents, automations, auto-sweep, and the user-facing status machine are a separate flow. Use [managed-accounts.md](managed-accounts.md). Do not bolt KYB fields onto a transfer schema, and do not store the KYB payload.

## Related

- [concepts.md](concepts.md) — which surface each architecture calls
- [managed-accounts.md](managed-accounts.md)
- [cloudflare-stack.md](cloudflare-stack.md)
- [value-layer.md](value-layer.md)
- [security.md](security.md)
