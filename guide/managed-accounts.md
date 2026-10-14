# Managed accounts

Onboard a business onto a Brale managed account and operate it after KYB. Read [brale-api.md](brale-api.md) first if you only send transfers or only read history. This page is the extra machinery: identity data, sweeps, and a status model a treasurer can understand.

Architecture context: [concepts.md](concepts.md#managed-treasury).

## What a managed account is

A **managed account** is a verified customer account your platform creates and operates through Brale, identified by its own `account_id`. It is not a wallet — a *custodial* managed account *has* one or more internal wallet addresses. You own the product and the customer relationship; Brale runs verification, custody, and compliance. ([Brale docs](https://docs.brale.xyz/guides/managed-accounts.md).)

Reach for managed accounts when you are onboarding **other people or businesses** onto stablecoin rails (a treasury product, a payouts platform, a neobank) rather than just moving your own funds. If you only operate your own balance, you need your own account, not managed accounts.

## Account types

`POST /accounts` takes three optional discriminator fields. Omit all three and you get today's default: a KYB business, custodial, standard verification.

| Field | Values | Default | Decides |
|-------|--------|---------|---------|
| `entity_type` | `business`, `individual` | `business` | KYB vs KYC |
| `account_type` | `custodial`, `transactional` | `custodial` | Brale holds a balance vs self-custody destination only |
| `verification_mode` | `standard`, `reliance` | `standard` | `reliance` is not self-serve; Brale enables it per managing account |

The split that matters most:

| Model | Has internal wallets & balances | Can originate on-chain transfers | Use it for |
|-------|-------------------------------|----------------------------------|------------|
| **Custodial** (business or individual) | Yes — Brale-managed addresses on supported chains | Yes | A customer who holds a Brale-custodied balance and sends/receives |
| **Transactional** (business or individual) | No | No — external destinations are destination-only | A customer who receives value on-chain to their *own* self-custody address, with no Brale-held balance |

An unsupported combination returns `422 unsupported_account_combination`; the rejection is permanent, so it is safe to cache against the idempotency key. `verification_mode: "bypass"` is never supported. Before `POST /accounts`, your onboarding flow must present the current Brale End User Agreement and capture consent — see the [Accounts resource](https://docs.brale.xyz/key-concepts/accounts.md) and [Legal](#legal).

Which to build:

- **Business custodial** — a business that holds a Brale-custodied balance and uses Brale as its record of funds. The default. This is the [managed treasury](concepts.md#managed-treasury) shape.
- **Individual custodial** — a person who holds a Brale-custodied balance. U.S.-only, narrower state list.
- **Business / individual transactional** — KYB/KYC-verified but non-custodial: register external self-custody destinations (e.g. the on-ramp target in a [self-custody wallet](concepts.md#self-custody-wallet) product). No Brale balance, no origination.

Availability depends on entity type, account type, and jurisdiction — see [Account availability](https://docs.brale.xyz/coverage/account-availability.md).

### Individual transactional for consumer transfers

A consumer transfer product — where a person deposits stablecoins and receives a different stablecoin or a payout — uses **individual transactional** accounts. The transactional account carries the person's KYC verification. Brale executes user instructions under it. The managing (parent) account provides API authentication but is not in the funds flow and does not custody user funds.

| Piece | Role |
|-------|------|
| Individual transactional account | KYC-verified. Brale executes the user's transfer instructions under this account. External destination addresses are registered here. |
| Internal deposit address | Created per transfer under the API credentials. Brale holds the address; the user sends tokens to it. See [dedicated deposit addresses](brale-api.md#dedicated-deposit-addresses). |
| Managing account | API auth only. Creates addresses, reads balances, posts transfers. Not a custodian, not an intermediary. |

KYC details (name, date of birth, identity number) are sent to Brale on account creation and not stored — the same transit-only rule as KYB. Identity types depend on jurisdiction: SSN for U.S. residents, passport or national ID outside the U.S. Check [account availability](https://docs.brale.xyz/coverage/account-availability.md) before collecting identity data.

## Onboarding

```
Signup → testnet activation → mainnet KYB (when you need live money) → live operations
```

| Phase | What you do | Brale | What you store |
|-------|-------------|-------|----------------|
| Signup | Create your org, user, and wallet rows. Open a managed account with testnet credentials. | Create account (testnet application) | No KYB fields |
| Testnet activation | Create the managed account with a testnet business profile so it can transact in test. | Create account with testnet KYC/KYB details | Testnet data only, if you store anything |
| Mainnet KYB | Collect real identity data and forward it on account creation (and as staged documents). | Create account with live details; stage and link verification documents | **Nothing.** Transit only. |
| Documents | Stage a verification document, then link it to the account, when Brale asks for more. | Stage verification document → link verification documents | **Nothing.** Transit only. |
| Live operations | Transfers, deposits, sweeps | Orchestration API | Operational rows only |

There is no standalone `/kyb` endpoint. KYB and KYC details are submitted when you create the account, and supplemental verification is a two-step document flow: **stage** the document, then **link** it. Expose this behind your own routes (`/account/activate`, `/account/activate/live`, `/account/documents`). Do not proxy the Brale KYB body back to the client, and do not write it on the way through.

## KYB is transit-only

EIN, SSN, date of birth, beneficial owners, and controller data are collected in the authenticated activation form, sent to Brale, and discarded.

1. Build the Brale body in memory. The builder returns a payload. It does not accept a database handle.
2. The route forwards that payload and returns only status (accepted, pending, rejected).
3. Redact identity field names in logs before you ship the line. The regex is in [security.md](security.md).
4. There is no draft. A failed request means the user submits again.

Compensating controls that have to exist together:

- Signup itself collects no KYB data.
- Testnet activation uses testnet values (Brale's term; do not call it "sandbox").
- Mainnet activation requires an authenticated session and an already-active testnet account.
- The redaction regex runs on every log call, not only on the KYB route.

## Auto-sweep

Deposits arrive on whatever rail the sender used. Treasurers want one balance in a preferred `(value_type, transfer_type)`.

```
Webhook: transfer.completed (inbound)
  → note starts with "sweep:"?
      → yes: mark the original transfer settled, stop
  → already the preferred hold?
      → yes: mark settled, stop
      → no:  mark settling, create one sweep transfer

Sweep
  source:      the deposit's (value_type, transfer_type)
  destination: the platform preferred (value_type, transfer_type)
  note:        "sweep:{original_transfer_id}"
```

Store the preference in a `platform_config` table (`sweep.value_type`, `sweep.transfer_type`) and change it through an admin route limited to the owner role.

The `sweep:` prefix is the loop break. Without it, the sweep’s own `transfer.completed` starts another sweep.

Wire and ACH can skip the sweep if Brale automation destinations already point at the preferred hold. Do not sweep those deposits a second time in your Worker.

For Brale-issued stablecoins this conversion is burn and mint at par. Do not model it as an AMM swap, and do not add a slippage field.

## Status machine

Brale’s `pending` / `completed` / `failed` is not what you show. Map it.

| Your status | Meaning | Show |
|-------------|---------|------|
| `pending` | Outbound send submitted | Waiting |
| `settling` | Inbound deposit received, sweep in flight | Converting |
| `settled` | In the preferred form, or a completed outbound | Done |
| `failed` | Brale reported failure | Failed |

Transitions:

- Deposit already in the preferred hold → `settled` immediately
- Deposit that needs a sweep → `settling`, then `settled` when the sweep completes
- Outbound → `pending`, then `settled` on completion
- Any `transfer.failed` → `failed`
- Accept both `complete` and `completed` from Brale when you read status

While any row is `settling`, the client polls about every 5 seconds and shows a single in-progress indicator. Stop when every row is terminal.

## Poller

Webhooks are the fast path. They are not guaranteed. Run a Cron Trigger every 60 seconds with four jobs:

| Job | Work | Cost |
|-----|------|------|
| Recovery | Rows stuck in `settling` or `pending`. Read Brale. Move them to `settled` or `failed`. | Proportional to stuck rows |
| Discovery | List recent transfers for each active account. Insert inbound deposits you have never seen. Start sweeps. | Proportional to active accounts |
| Balance sweep | Read balances on every known custodial address. Sweep any non-preferred hold above dust (`0.01`) to the preferred hold. | Proportional to active addresses × sweepable value types |
| Preferred-hold reconciliation | Compare actual Brale balance on the preferred hold against the ledger's expected balance. If actual > expected, query `listTransfers` for the specific transfer first, then record any remaining gap. | 1 balance read + 1 list call per active account |

Together, a missed webhook still shows up within a minute.

**Why four jobs, not two.** Discovery relies on `listTransfers`, which returns only the ~25 most recent transfers with no way to page deeper. Deposits older than that window are invisible to discovery. The balance sweep catches funds that landed on a non-preferred chain and were never listed. The reconciliation catches funds that landed directly on the preferred hold — there is nothing to sweep, and nothing to discover once the transfer falls off the list window.

### Balance sweep details

For each active org, iterate every custodial address that matches the account's environment. Skip the preferred hold (that is the destination, not a source). For each `(address, value_type)` pair above dust, create one Brale transfer into the preferred hold. Tag the note as `sweep:balance:{address}:{transfer_type}:{value_type}` and check for in-flight sweeps with that prefix before submitting.

### Preferred-hold reconciliation details

```
actual  = Brale getBalance on the preferred-hold address
expected = SUM(credits to preferred hold, settled) - SUM(debits from preferred hold, settled)
gap     = actual - expected

if gap < dust → skip
if gap ≥ dust:
  1. Query listTransfers. Match any completed inbound transfers we have not recorded.
     Record each with its Brale transfer ID, real source, and amount.
  2. Recompute the remaining gap. If still ≥ dust, record a generic inbound deposit.
```

Step 1 pre-empts the webhook: the deposit gets full Brale metadata instead of a bare gap record. Step 2 is the last resort for on-chain credits that never appear in the transfer list at all.

### Cross-environment address filter

When an org has both testnet and mainnet Brale accounts, the `brale_addresses` table contains addresses for **all** environments under the same `organization_id`. The balance sweep and any per-address job must filter addresses to match the account's environment:

```ts
const filtered = allAddresses.filter(
  (a) => networkEnvironment(a.transfer_type) === account.environment,
);
```

Without this, a testnet account will try to read and sweep mainnet addresses (and vice versa), producing Brale `403 Incorrect API key for requested network` errors. This also wastes subrequests and can push the Worker over its subrequest limit.

### Subrequest budget

A Cron Trigger that processes many accounts, reads balances, submits sweeps, and sends email notifications can exhaust the Worker subrequest limit (50 on the free plan, 1000 on paid). Guard against this by:

- Processing accounts in priority order (live before test, stuck before healthy).
- Counting subrequests and stopping early if the budget is low.
- Deferring non-critical work (e.g. testnet sweeps) to the next cycle.

Analytics-style sync (backfill + webhook + alarm, no sweep) is the lighter version in [brale-api.md](brale-api.md). Use that when you are not converting deposits to a preferred hold.

### Webhook deduplication

Two patterns that work:

| Pattern | Store | Trade-off |
|---------|-------|-----------|
| KV key `webhook:{event.id}` with 7-day TTL | KV | Fast; eventually consistent (a race during KV propagation can reprocess once) |
| `INSERT OR IGNORE INTO brale_events (event_id, event_type)` | D1 | Strong; the write is the dedup |

If you operate both testnet and mainnet, verify the webhook with the correct environment's subscription secret. Try the test secret, then the live secret; set `verifiedEnvironment` for downstream Brale client selection.

### Transfer event tracking

A `transfer_events` table records the source (webhook, poller, API) and timestamp for each transfer state change. Query it for settlement-latency SLOs per transfer type.

### Wire instructions may lag automation

When KYB completes and you create an automation, `funding_instructions` (the bank coordinates to share with the depositor) may not be immediately present on the automation response. Lazy-poll: on the `/me` or funding-instructions route, list automations for the account and cache the first one that carries `source.funding_instructions` as JSON in D1.

### Per-environment managed-account rows

Store managed accounts in a table with an `environment` column (`org_brale_accounts (organization_id, environment, brale_account_id, kyb_status, ...)`). A live activation always creates a new Brale account — never reuse the testnet one. Resolution must never fall back from live to test.

## Automations

Brale Automations mint stablecoins to a destination when fiat (wire/ACH) is received. Key operational facts:

- **Automations are immutable.** `PATCH` and `DELETE` both return 404 or 422. To change the destination chain, create a new automation. The old one stays active until archived.
- **Retargeting the preferred hold.** If you change the preferred hold from one chain to another, create a new automation pointing at the new chain. Any deposits that still hit the old automation's destination will be caught by the balance sweep and converted to the preferred hold.
- **One automation per deposit rail per account.** A single automation covers all wire deposits for an account. You do not need one per chain.

## Verification documents

When Brale's KYB review requests additional documents (`account.verification.documents_required` webhook or polling), the flow is:

1. **Stage** the document: `POST /accounts/{account_id}/documents` with multipart form data — `file` (the document), `document_kind`, and optionally `person_label` for individual (KYC) documents.
2. **Link** staged submissions to the account: `PATCH /accounts/{account_id}` with `{ doc_submission_ids: [...] }`.

Known document kinds: `articles_of_incorporation`, `certificate_of_good_standing`, `ein_letter`, `government_photo_id`. Gate the upload behind `kyb_status === 'documents_required'` — return 400 otherwise.

## Legal

A production onboarding flow needs all four:

1. Terms of service that describe your role, digital-asset risk, and the limits of deposit insurance.
2. A privacy policy that names Brale as a recipient and states that KYB data is not stored by you.
3. A link to the [Brale End User Agreement](https://brale.xyz/legal/end-user-agreement) at signup.
4. A `terms_accepted_at` timestamp on the user, set from the signup request, visible to admins.

The checkbox sits above the continue button and lists those three documents. The button stays disabled until it is checked. Store the timestamp. Do not infer acceptance from “they created an account”.

## Related

- [brale-api.md](brale-api.md)
- [security.md](security.md)
- [cloudflare-stack.md](cloudflare-stack.md)
- [value-layer.md](value-layer.md)
- [concepts.md](concepts.md#managed-treasury)
