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

Webhooks are the fast path. They are not guaranteed. Run a Cron Trigger every 60 seconds with two jobs:

| Job | Work | Cost |
|-----|------|------|
| Recovery | Rows stuck in `settling` or `pending`. Read Brale. Move them to `settled` or `failed`. | Proportional to stuck rows |
| Discovery | List recent transfers for each active account. Insert inbound deposits you have never seen. Start sweeps. | Proportional to active accounts |

Together, a missed webhook still shows up within a minute. A poller that only retries known rows will never see a deposit that never arrived as a webhook.

Analytics-style sync (backfill + webhook + alarm, no sweep) is the lighter version in [brale-api.md](brale-api.md). Use that when you are not converting deposits to a preferred hold.

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
