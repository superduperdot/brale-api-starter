# Getting started

How to start a Brale integration without re-learning the same lessons. Pick an architecture first. The rest of this page is the order of operations.

## 1. Pick the architecture

Open [concepts.md](concepts.md) and choose the closest row. Write it down. It fixes three decisions other pages assume:

- Whether you call `api.brale.xyz`, a read API, or neither
- Whether the runtime is an extension, a library, or Cloudflare
- Which field notes in [lessons/](../lessons/) are worth reading

If you are onboarding businesses, stop and read [managed-accounts.md](managed-accounts.md) before you design a schema.

## 2. Name it, then create the repo

Decide the repo slug, display name, and package name using [naming-conventions.md](naming-conventions.md). Names land in URLs, worker names, and UI copy, and they are expensive to change.

## 3. Scaffold the four docs

Copy from [templates/](../templates/):

| File | Role |
|------|------|
| `README.md` | Who it is for, what Brale surface it uses, what Cloudflare it uses |
| `brain.md` | As-built truth. Read this first, forever. |
| `AGENTS.md` | Commands, guardrails, and when to update this playbook |
| `architecture.md` | Runtime and file index |

Paste [templates/SEED-PROMPT.md](../templates/SEED-PROMPT.md) into the agent session that bootstraps the repo.

## 4. First integration runbook

Do these in order. Skip a step only when the architecture says you do not call that API.

### Before any authenticated call

- [ ] OAuth2 client credentials against `https://auth.brale.xyz/oauth2/token`
- [ ] Cache the token. Refresh about five minutes before expiry. One in-flight refresh at a time.
- [ ] On 401, drop the cache and retry the request once
- [ ] Credentials live in Worker secrets or a server session. Never in the browser.

Reference implementation: [brale-agent-kit/reference/auth.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/auth.ts)

### Before the first `POST` that creates something

- [ ] Send a fresh `Idempotency-Key` for a new operation. Reuse that same key when retrying a timeout or a 5xx.
- [ ] `amount.value` is a decimal string. `amount.currency` is `"USD"`.
- [ ] `source` is an internal custodial address. External addresses are destinations only.
- [ ] Write the intent to your database before the API call if a user is waiting on money movement. Reconcile after.

### Before you subscribe to webhooks

- [ ] Read the raw body, then verify HMAC-SHA256. Header: `x-request-signature-sha-256`.
- [ ] Base64URL-decode `sharedSecret`. Do not HMAC the encoded string. It is shown once.
- [ ] Compare in constant time. For transfer state transitions, await the write before returning `200`. `ctx.waitUntil()` is only safe for idempotent, non-critical writes ([details](brale-api.md#webhooks)).
- [ ] Add a poller. Webhook delivery is not a guarantee. 30–60 seconds is the range that has worked.

### Before production

- [ ] Sessions in D1 (or a Durable Object), not KV
- [ ] Log redaction for secrets and, if you touch KYB, for identity fields
- [ ] Security headers on the Worker. `cache-control: no-store` on financial responses
- [ ] A test against the built artifact, not only unit tests
- [ ] Mainnet check with a small real amount, written into `brain.md`

## Shared defaults

Use these unless the architecture says otherwise.

- TypeScript strict, pnpm, Vitest
- Playwright for anything with a UI, against the production build
- MIT license unless you have a reason not to
- Value Layer names in operator tools. Plain language (`USDC`, `Base`, `wire`) in end-user products. See [value-layer.md](value-layer.md).

## Repo checklist

- [ ] Architecture named in the README (one sentence, from [concepts.md](concepts.md))
- [ ] Customer named in the first screen of the README
- [ ] Brale API table filled in, or an explicit “none”
- [ ] Cloudflare table filled in, or an explicit “none”
- [ ] `brain.md`, `AGENTS.md`, and `architecture.md` present
- [ ] Entity IDs prefixed (`org_`, `tr_`, …) if you mint your own identifiers
- [ ] Link to this playbook from the README

## Related

- [concepts.md](concepts.md) — the seven architectures
- [naming-conventions.md](naming-conventions.md)
- [ai-agents.md](ai-agents.md) — how agents should use this playbook
- [../templates/SEED-PROMPT.md](../templates/SEED-PROMPT.md)
