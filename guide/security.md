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

Rate-limit authentication. A starting point that has shipped: 5 attempts per 15 minutes per IP, counted in D1. For email codes, 3 sends per address per 10 minutes, counted in KV, is enough because a stale counter fails closed toward “try later”, not toward “you are still logged in”.

## Webhooks

HMAC-SHA256 over the raw body. Constant-time compare. Read the bytes before you parse JSON. Details and the header name: [brale-api.md](brale-api.md). Reference code: [webhook-verify.ts](https://github.com/superduperdot/brale-agent-kit/blob/main/reference/webhook-verify.ts).

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
const SENSITIVE_KEY =
  /ssn|ein|dob|tax_id|account_number|routing_number|phone_number|beneficial|controller|kyb|ubo|secret|token|password/i;

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

This catches accidental fields. It does not make it acceptable to log a KYB body. Do not log that body at all. See [managed-accounts.md](managed-accounts.md).

## Passwordless email codes

A reasonable default when the user population is small and you do not want passwords.

| Piece | Practice |
|-------|----------|
| Code | 6 digits from `crypto.getRandomValues()`, zero-padded |
| Storage | D1: email, code hash or code, expiry, used flag |
| TTL | 10 minutes |
| Use | Single update that sets `used` and checks the previous value |
| Compare | Constant-time XOR across characters, then check the accumulator. Not `===`. |
| Delivery | A transactional provider with a verified domain. Console output only in local dev. |
| Paths | The same code flow for login and signup. The verify step decides which one it was. |

Store a hash of the code if you can verify without the raw code. If you store the raw code for the TTL window, treat that table like a secret.

## Internal routes

Routes that the poller or another Worker calls (`/internal/poll`, `/internal/catch-up`) require a dedicated shared secret in a header. Do not reuse the user session cookie for that hop.

## Compliance-specific

Normalize EVM addresses to lowercase before you compare them to a sanctions list. A case mismatch is a false negative.

Commercial screening datasets have their own licenses. Check the license before production, not after the first match.

## Before you ship

- [ ] No Brale secret in client code (search the built assets)
- [ ] Webhook verification tested against a captured raw body, including a bad signature
- [ ] Session revocation tested
- [ ] Log line for a KYB-shaped payload contains `[REDACTED]` and not the value
- [ ] Security headers present on a production response
- [ ] OWASP-oriented tests for auth, CSRF where cookies exist, rate limits, and webhook integrity

## Related

- [managed-accounts.md](managed-accounts.md)
- [brale-api.md](brale-api.md)
- [testing.md](testing.md)
- [../templates/SECURITY.md](../templates/SECURITY.md)
