# Security

Controls that should exist before a Brale app takes real credentials or real identity data. Map them to your architecture. A library and a Worker do not share a session design, and they do share the rules about key material and logs.

## Secrets

| Control | Practice |
|---------|----------|
| Brale client secret | Worker secret or server env. AES-GCM-256 at rest if you must store it in D1. `ENCRYPTION_KEY` is itself a Worker secret. |
| Webhook `sharedSecret` | Base64URL-decode once, encrypt, store. Never log the raw value. |
| Browser | No Brale client credentials in extension pages, Next.js client components, or a Vite bundle |
| Logs | Redact `client_secret`, tokens, and raw keys on every log line |
| Key generation | `openssl rand -hex 32` for symmetric keys |

Generate a new encryption key per environment. Do not reuse the test key in production.

## Sessions

Store sessions in D1 (revocable, with a TTL) or in a server-side session. A 24-hour bearer token stored as a row you can delete is a fine default.

Do not store auth state in KV. KV is eventually consistent, and a revoked session that still works is the bug.

Rate-limit authentication. A starting point that has shipped: 5 attempts per 15 minutes per IP, counted in D1. For email codes or SMS, limit sends per address (3 per 10 minutes), sends per IP (10 per hour), **and** verification attempts (burn the code after ~5 wrong guesses). Throttling sends per address alone does not stop code guessing, and it does not stop an attacker from burning your delivery budget across many addresses from one IP. See [Passwordless email codes](#passwordless-email-codes). KV is acceptable for these counters because a stale counter fails closed toward “try later,” not toward “you are still logged in.”

## Webhooks

HMAC-SHA256 over the raw body. Base64URL-decode the `sharedSecret` to get the key ([per Brale's signature docs](https://docs.brale.xyz/webhooks/signatures.md)) — do not feed the encoded string in as the key. Read the bytes before you parse JSON.

Compare in constant time. A plain `hex === signature` (or `==`) on the digest is a timing side channel — use `crypto.timingSafeEqual` over equal-length buffers, after a length check. This is an easy one to get wrong; verify it in a test with a near-miss signature. Header name and full table: [brale-api.md](brale-api.md). Reference code: [webhook-verify.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/webhook-verify.ts).

## Headers

Send HSTS, a content-security policy, and `X-Frame-Options: DENY` from the Worker. Financial responses get `cache-control: no-store`.

Self-host fonts and scripts so the policy can say `'self'`.

## Crypto

Allow `@noble/*`, `@scure/*`, `hash-wasm`, and Web Crypto. Do not add `ethers`. In an extension service worker, import `viem` lazily if you need it at all.

In a browser extension:

- The encrypted envelope is the only key material in persistent storage.
- The unlocked session key lives in session storage, readable only by trusted extension contexts.
- Zero-fill decrypted bytes after use.
- Keep the KDF salt stable across re-seals.
- Privileged messages come from extension pages only. The dapp origin is `sender.origin`.

Argon2id via `hash-wasm` needs `wasm-unsafe-eval` in a Manifest V3 content-security policy. If it is missing, wallet creation fails with no useful error. Cover that with an end-to-end test against the built extension.

An agent library exposes `destroy()` that zero-fills and then makes later calls throw. A policy check (caps, allowlists) and an audit record run before every send.

## Log redaction

If you touch KYB or bank details, redact by **field name** before the log line is serialized. Apply it in the logger, not in individual routes.

```typescript
// Match credentials, auth material, card data, and KYB/PII field *names*.
// Extend for your schema. Add wallet terms (mnemonic, seed, private_key) if
// this app holds keys. Err toward over-redaction.
const SENSITIVE_KEY =
  /(pass(word)?|secret|token|authorization|api[_-]?key|cookie|ssn|ein|dob|tax[_-]?id|account[_-]?number|routing[_-]?number|card[_-]?number|cvv|cvc|pan|phone|beneficial|controller|kyb|ubo|mnemonic|seed|private[_-]?key)/i;

function redact(obj: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_KEY.test(key)) {
      result[key] = "[REDACTED]";
    } else if (typeof value === "object" && value !== null) {
      result[key] = redact(value as Record<string, unknown>);
    } else {
      result[key] = value;
    }
  }
  return result;
}
```

Match on the **key name**, not the value, and err toward over-redaction (`pan` will also hit a field named `company` — that is fine; a leaked PAN is not). This catches accidental fields. It does **not** make it acceptable to log a KYB body, a card PAN/CVV, a bearer token, or an `Authorization` header — do not pass those in at all. See [managed-accounts.md](managed-accounts.md).

Route your audit log through the same redaction. An append-only audit of every API call is only safe if request and response bodies are scrubbed first — otherwise the audit table becomes the PII store you were trying to avoid.

## Passwordless email codes

A reasonable default when the user population is small and you do not want passwords.

| Piece | Practice |
|-------|----------|
| Code | 6 digits (or more) from `crypto.getRandomValues()`, zero-padded |
| Storage | D1: email, code hash (preferred) or code, expiry, used flag, **attempt counter** |
| TTL | 10 minutes |
| Use | Single update that sets `used` and checks the previous value |
| Compare | Constant-time XOR across characters, then check the accumulator. Not `===`. |
| **Verify attempts** | **Cap them.** Count failures per code; invalidate the code after ~5 wrong guesses. Also rate-limit the verify endpoint per email and per IP. |
| Delivery | A transactional provider with a verified domain. Console output only in local dev. |
| Paths | The same code flow for login and signup. The verify step decides which one it was. |

**Rate-limiting the *send* does not protect the code.** A 6-digit code is one of a million values; if an attacker can call verify without limit for the 10-minute window, it is guessable. The send limit (3 per 10 minutes) only throttles emails — it does nothing against guessing. You must separately cap verification attempts and burn the code after a few failures. This is the one control most email-code implementations miss, so build it in from the start.

Store a hash of the code (e.g. SHA-256) and compare hashes, so a leaked `email_codes` table does not hand over live codes. If you store the raw code for the TTL window, treat that table like a secret.

## Internal routes

Routes that the poller or another Worker calls (`/internal/poll`, `/internal/catch-up`) require a dedicated shared secret in a header, compared in constant time. Do not reuse the user session cookie for that hop. Prefer a **service binding** between your own Workers over a publicly routable `/internal/*` path — a binding is not reachable from the internet at all, so there is no secret to leak or brute-force.

## Compliance-specific

Normalize EVM addresses to lowercase before you compare them to a sanctions list. A case mismatch is a false negative.

Commercial screening datasets have their own licenses. Check the license before production, not after the first match.

## Before you ship

- [ ] No Brale secret in client code (search the built assets)
- [ ] Webhook verification uses a constant-time compare, tested against a captured raw body and a near-miss signature
- [ ] Email-code (or OTP) verification is attempt-capped and the code burns after a few failures — not just send-rate-limited
- [ ] Session revocation tested
- [ ] Log line for a KYB-shaped payload (and a card PAN/CVV, if you issue cards) contains `[REDACTED]` and not the value
- [ ] Audit-log entries are redacted the same way as logs
- [ ] Security headers present on a production response
- [ ] OWASP-oriented tests for auth, CSRF where cookies exist, rate limits, and webhook integrity

## Related

- [managed-accounts.md](managed-accounts.md)
- [brale-api.md](brale-api.md)
- [testing.md](testing.md)
- [../templates/SECURITY.md](../templates/SECURITY.md)
