# Managed treasury

Field notes for business onboarding, a single preferred balance, and settlement. Card issuing builds on this. Architecture: [concepts.md](../guide/concepts.md#managed-treasury).

### KYB stored “just in case”

- **What happened:** Mainnet activation needs EIN, SSN, date of birth, and beneficial owners. Writing that to D1 creates a data store you now have to secure and disclose.
- **Do this instead:** Build the Brale payload in memory, forward it, return status only. Never insert it. Never log it. On failure, the user submits again.
- **Guide:** [Managed accounts](../guide/managed-accounts.md), [Security](../guide/security.md)

### PII in structured logs

- **Do this instead:** Redact by field name (`ssn`, `ein`, `dob`, `tax_id`, `account_number`, `routing_number`, `phone_number`, `beneficial`, `controller`, `kyb`, `ubo`) inside the logger, on every call.
- **Guide:** [Security — log redaction](../guide/security.md)

### One balance across rails

- **What happened:** Deposits landed on several chains. The product needed one number.
- **Do this instead:** On inbound `transfer.completed`, if the pair is not the preferred hold, create one Brale transfer into that hold. Set `note` to `sweep:{original_transfer_id}`. Ignore webhooks whose note already has the prefix. Keep the preference in a config table editable by the owner role.
- **Guide:** [Managed accounts — auto-sweep](../guide/managed-accounts.md)

### Brale’s status is not the treasurer’s status

- **Do this instead:** `pending` (outbound submitted), `settling` (sweep in flight), `settled`, `failed`. Deposits already in the preferred hold are `settled` immediately. The client polls about every 5 seconds while anything is `settling`.
- **Guide:** [Managed accounts — status machine](../guide/managed-accounts.md)

### A poller that only retried known rows

- **What happened:** Deposits with no webhook never appeared, because recovery only looked at rows you already had.
- **Do this instead:** Every 60 seconds, recover stuck rows **and** list recent Brale transfers per active account to insert ones you have never seen.
- **Guide:** [Managed accounts — poller](../guide/managed-accounts.md)

### Passwords for a small, invited user base

- **Do this instead:** 6-digit codes from `crypto.getRandomValues()`, 10-minute TTL, single use, constant-time compare, at most 3 sends per email per 10 minutes. The same flow covers login and signup.
- **Guide:** [Security — email codes](../guide/security.md)

### Opaque ids in support tickets

- **Do this instead:** Prefix ids you mint (`org_`, `usr_`, `mem_`, `wlt_`, `tr_`, …). Keep Brale and card-network ids internal.
- **Guide:** [Naming — entity IDs](../guide/naming-conventions.md)

### Two requests consuming one invite

- **Do this instead:** Admin auth is a separate session. Consume the code with a conditional update (`WHERE status = 'active'`). The client may pre-check the code; the database is the lock.
- **Guide:** [Cloudflare — invite-gated signup](../guide/cloudflare-stack.md)

### One person, several organizations

- **Do this instead:** A membership table with a role. The session holds the active organization. Switching is a POST, not a new login. Creating a workspace provisions the org, the Brale account, the wallet, and the membership together.
- **Guide:** [Cloudflare — multi-workspace](../guide/cloudflare-stack.md)

### Floats in the ledger

- **Do this instead:** Decimal strings, two places. Brale already sends `amount.value` as a string. Format only at the screen.
- **Guide:** [Value Layer — money](../guide/value-layer.md)

### Engineers’ words in a bank UI

- **Do this instead:** The person sees USD, USDC, Solana, wire. The service maps `currency` and `chain` to `value_type` and `transfer_type`. Do not render the primitive names.
- **Guide:** [Value Layer — audiences](../guide/value-layer.md)

### No record of legal acceptance

- **Do this instead:** `terms_accepted_at` on the user, set from a required checkbox that links to your terms, your privacy policy, and the Brale end-user agreement.
- **Guide:** [Managed accounts — legal](../guide/managed-accounts.md)

### A second OpenAPI document

- **Do this instead:** Hono and chanfana. Zod schemas on the route are the contract and the `/openapi` output.
- **Guide:** [Cloudflare — Hono and chanfana](../guide/cloudflare-stack.md)

### Dev API calls returned HTML

- **What happened:** JSON parsing failed because the Vite proxy targeted the wrong wrangler port and received an error page.
- **Do this instead:** Match the proxy target to the port wrangler actually prints (often 8788, not 8787).
- **Guide:** [Cloudflare — gotchas](../guide/cloudflare-stack.md)
