# Value Layer

Three primitives describe every movement of value. Use them in code even when the UI uses plainer words.

Essays: [The Value Layer](https://benmilne.com/book/the-value-layer).

## Primitives

| Primitive | Meaning | Example |
|-----------|---------|---------|
| **ValueType** | What moves | `USD`, `USDC`, `SBC` |
| **TransferType** | How it moves | `wire`, `ach_credit`, `base`, `solana` |
| **Exchange** | A conversion between two pairs | USD Wire → USDC Solana |

The issuer sits inside the value type. SBC is Brale-issued. The Brale API uses the same model: `value_type` and `transfer_type` on each side, `address_id` as the endpoint, and `amount.currency` always `"USD"` (the unit of account, not the asset).

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
