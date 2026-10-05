# Value Layer

Three primitives describe every movement of value. Use them in code even when the UI uses plainer words. This is not Brale-specific theory — it is the design the Brale API is built on, so understanding it makes the API obvious instead of surprising.

Field guide: [The Value Layer](https://benmilne.com/book/the-value-layer) (Ben Milne, 2026) — the grammar of `ValueType`, `TransferType`, and `Exchange`.

## Primitives

| Primitive | Meaning | Example | Brale API field |
|-----------|---------|---------|-----------------|
| **ValueType** | What moves | `USDC`, `SBC`, `usd` | `value_type` |
| **TransferType** | How it moves | `wire`, `ach_credit`, `base`, `solana` | `transfer_type` |
| **Exchange** | A conversion between two pairs | USD Wire → USDC Solana | implied by source ≠ destination |

The issuer sits inside the value type (SBC is Brale-issued; USDC is Circle's). The whole API is this model: a transfer carries a `value_type` and a `transfer_type` on each of `source` and `destination`, each leg points at an `address_id`, and the operation (onramp, offramp, swap, payout) is whatever the two endpoints imply. There is no `/swap` or `/onramp` endpoint.

## The two fields in the Brale API

The grammar maps directly onto two case-sensitive fields. Both are `snake_case`. There is no `valueType`/`transferType` camelCase anywhere in the API.

| | `value_type` | `transfer_type` |
|--|--------------|-----------------|
| Answers | What is it | What rail / chain |
| Onchain examples | `SBC`, `USDC`, `USDT`, `MXNe`, `RLUSD` (canonical tickers, mixed case) | `base`, `solana`, `ethereum`, `canton`, `tron`, `polygon` |
| Offchain examples | `usd`, `mxn` (fiat, **lowercase**) | `wire`, `ach_debit`, `ach_credit`, `same_day_ach_credit`, `rtp_credit` |
| Testnet | same ids | testnet rails: `base_sepolia`, `solana_devnet`, `sepolia`, `canton_testnet` |
| Rule | Copy the exact id from Coverage. Never hardcode a second spelling. | Lowercase chain/rail id. Use the testnet variant on testnet. |

Casing is a real trap: fiat value types are lowercase (`usd`), onchain tokens use their published ticker (`SBC`, `MXNe`, `cFtUSD` vs `CFUSD` are different ids). Treat the Coverage pages as the source of truth, not a display name:

- [Value Types](https://docs.brale.xyz/coverage/value-types.md) — ~40 stablecoins plus `usd`/`mxn`
- [Transfer Types](https://docs.brale.xyz/coverage/transfer-types.md) — chains, fiat rails, and testnet variants

Not every value type runs on every transfer type. USDC is on ~10 chains; USDT is Ethereum, Solana, Tron. Supported pairs for Brale-issued stablecoins are set during onboarding. The API will not enumerate the valid pairs for you — probe and skip errors (see [brale-api.md](brale-api.md)).

### Canonical transfer shape

`amount`, `source`, `destination`. No wrappers, no camelCase. `SBC` is Brale's placeholder stablecoin in docs — swap in yours.

```json
{
  "amount": { "value": "100", "currency": "USD" },
  "source":      { "value_type": "usd", "transfer_type": "wire" },
  "destination": { "address_id": "2VcUIonJeVQzFoBuC7LdFT0dRe4", "value_type": "SBC", "transfer_type": "solana" }
}
```

`amount.currency` is an ISO-4217 code (usually `USD`), and it is **separate from `value_type`** — a USD-denominated stablecoin moves with `currency: "USD"`, while a `MXNe` leg is denominated in MXN. `amount.value` is a decimal string. `address_id` is omitted on a leg only when Brale returns deposit instructions for funding (for example a wire onramp source).

## Two audiences, two word lists

Pick one and apply it everywhere in that product. Mixing them is how “swap” sneaks back into a screen that was supposed to be precise.

### Operator tools

Analytics, investigation, internal audit, and solver consoles show the grammar itself:

```
$1,000  USD Wire → USDC Solana
```

Rules:

1. Do not write onramp, offramp, swap, or payout. Name both legs.
2. Be specific: “ACH Credit”, not “ACH”. “Solana”, not “chain”.
3. Missing values render as `—`, not as an empty cell.
4. A fiat leg has no on-chain hash. A cross-chain leg may have two (burn and mint). Render however many the payload contains.
5. Filters match either leg, not only the source.

### End-user products

Treasury portals, wallets aimed at non-developers, and card programs do not teach the vocabulary. Map it.

| The person sees | The engine stores |
|-----------------|-------------------|
| Balance | Amount of a value type on a wallet |
| Send, receive, wire | A transfer, made of legs |
| Convert, fund | An exchange |
| USD, USDC, SBC | Value types, unlabeled as such |
| Solana, Base, a card network | Transfer types, unlabeled as such |

A public API for that product should accept `currency` and `chain`, then map to `value_type` and `transfer_type` at the boundary. Do not leak Brale’s field names through a bank-facing API unless the customer is an engineer integrating Brale directly.

## Exchange classification

When you have to label a cross-rail movement internally (compliance, routing, P&L):

| What changed | Internal name |
|--------------|---------------|
| Value type only, same transfer type | swap |
| Transfer type only, same value type | bridge |
| Both | cross-rail |

Those names stay in code and in investigator tools. They are not button labels in an end-user product.

## Money

1. Amounts are decimal strings. Two decimal places for money. Never a float. `0.1 + 0.2` is not `0.3`.
2. Brale’s `amount.value` is already a string. Do not parse it until the pixel where you render it.
3. Display with an explicit format at the edge (`toFixed(2)` after you have decided rounding). Do not format inside the ledger.
4. Validate at the boundary: `z.string().regex(/^\d+\.\d{2}$/)` or an equivalent that rejects exponents and extra precision.
5. Every POST or PATCH that creates or changes a financial resource sends `Idempotency-Key`.
6. Every exchange records the rate and the cost as their own fields. A “net amount” with the fee folded in is not reconstructable.

## Where the primitives show up

| Architecture | Use |
|--------------|-----|
| Analytics command center | KPIs, charts, feed, filters |
| Operations dashboard | Transfer review, history, audit log |
| Compliance monitoring | Screening legs, graph edge labels, CSF flows |
| Par settlement | Capability registry and quotes |
| Self-custody wallet | Activity, send review |
| Agent wallet | Audit log lines |
| Managed treasury | Internal ledger. The UI uses the end-user map above. |

## Related

- [csf-gsf.md](csf-gsf.md) — the same primitives as a sequence or a graph
- [brale-api.md](brale-api.md)
- [naming-conventions.md](naming-conventions.md)
- [managed-accounts.md](managed-accounts.md) — the status machine sits on top of these legs
