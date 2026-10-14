---
name: brale-security-review
description: >-
  Before-you-ship security and webhook-integrity checklist for Brale apps.
  Use when reviewing a Brale integration for security, when preparing to
  deploy to production, or when the user says "security review", "before
  ship", "production checklist", or "audit".
disable-model-invocation: true
---

# Brale security review

Run this checklist before any production deploy of a Brale integration. Items are grouped by category. A failing item blocks the deploy unless explicitly accepted by the team.

## Credentials and secrets

- [ ] Brale `client_id` and `client_secret` are in Worker secrets (`wrangler secret put`) or a secrets manager — never in code, config files, or client bundles
- [ ] `.dev.vars` is in `.gitignore`
- [ ] OAuth token is cached server-side; refresh ~5 minutes before expiry; one in-flight refresh at a time
- [ ] On 401, drop the cache and retry once — do not loop

## Webhook integrity

- [ ] Raw body is read before any JSON parse
- [ ] `sharedSecret` is Base64URL-decoded to raw bytes before HMAC — not UTF-8 encoded
- [ ] HMAC-SHA256 comparison is constant-time (`crypto.subtle.verify` or `timingSafeEqual`)
- [ ] Webhook handler returns 200 only after the state-transition write completes — `ctx.waitUntil()` is only for idempotent, non-critical work
- [ ] If operating both testnet and mainnet on one URL: try test secret, then live secret; set `verifiedEnvironment`

## Sessions and auth

- [ ] Sessions stored in D1 (or a Durable Object), never KV
- [ ] Session tokens are `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict`)
- [ ] Email/OTP codes stored as a hash, not plaintext; verify-attempt counter is rate-limited
- [ ] Admin sessions use a different token and route prefix from user sessions

## Data handling

- [ ] KYB payloads are forwarded to Brale and not stored — transit only
- [ ] Log redaction covers: `client_secret`, `sharedSecret`, `access_token`, `refresh_token`, `session_token`, and (if KYB) `ssn`, `tax_id`, `date_of_birth`, `bank_account_number`
- [ ] Amounts are decimal strings — never `parseFloat` a financial amount
- [ ] `Idempotency-Key` on every Brale POST that creates a resource; reconciler reuses the stored key on retry

## Encryption (if applicable)

- [ ] Password vault: Argon2id (64 MiB / t=3 / p=4 / 32-byte out) or PBKDF2-SHA256 ≥600k iterations
- [ ] AES-256-GCM with 12-byte IV, `tagLength: 128`
- [ ] Copy bytes into a fresh `ArrayBuffer` before `crypto.subtle.importKey`
- [ ] Deployment-pinned encryption: combine Worker `ENCRYPTION_KEY` with user passphrase so D1 ciphertext alone is insufficient

## Network and headers

- [ ] Security headers set on all responses (CSP, X-Content-Type-Options, etc.)
- [ ] `cache-control: no-store` on financial responses (balances, transfers)
- [ ] Non-GET/OPTIONS requests with mismatched `Origin` header → 403
- [ ] Internal routes (`/internal/*`) require `X-Internal-Secret` compared in constant time, or use a service binding
- [ ] `workers_dev = false` on internal Workers
- [ ] TLS/SSL verification is never disabled

## Extension-specific (if applicable)

- [ ] Gate WS upgrades on a session token — do not trust query-param identity
- [ ] Extension messages carry `id` + `timestamp`; reject if age > 30s or clock skew < −5s
- [ ] `chrome.storage.session.setAccessLevel({ accessLevel: 'TRUSTED_CONTEXTS' })` at service-worker boot
- [ ] WebAuthn/PRF runs in popup or tab, not the service worker
- [ ] Pending signing requests persisted in `chrome.storage.session`; auto-reject after 5 minutes

## Before you ship (final gate)

- [ ] `typecheck`, unit tests, and production build are all green
- [ ] A test runs against the built artifact, not only unit tests
- [ ] Mainnet check with a small real amount, documented in `brain.md`
- [ ] All items above are checked or explicitly accepted

## Reference

- `guide/security.md` — full security guide
- `guide/brale-api.md` — webhook verification, idempotency
- `guide/testing.md` — what "done" means
- `guide/getting-started.md` — before-production checklist
