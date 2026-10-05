# Cloudflare stack

Which primitive to use, which shapes have held up, and the gotchas that show up on the first deploy. Not every Brale app needs Cloudflare. A self-custody wallet and an agent library should not grow a Worker just to match this page.

Recommended layouts per product type: [concepts.md](concepts.md).

## Decision guide

| You need | Use | Do not use |
|----------|-----|------------|
| HTTP API and static assets | **Workers** | A long-lived Node server for the same job |
| Relational data at the edge (sessions, transfers, audit) | **D1** | KV for rows you will query |
| A lock, a websocket hub, a per-key rate limit, a nonce sequence | **Durable Objects** | A Durable Object as a high-throughput fan-out bus |
| A loop that must survive the request ending | **DO alarms** or **Cron Triggers** | `setTimeout` in a Worker |
| A cache, a feature flag, an idempotency marker | **KV** | KV for sessions or authorization |
| Bulk or cold storage | **R2** | R2 on the user-facing path |
| Retried background work | **Queues** | Queues to coordinate a request or a fill |
| A few seconds of GET caching | **Cache API** | — |
| Hashing, HMAC, AES-GCM | **Web Crypto** | Node `crypto` |

## Shapes that have shipped

Start from one of these. Invent a fourth only when none fit.

| Shape | Layout | Fits |
|-------|--------|------|
| **Single Worker** | API, webhooks, auth, and the SPA in one Worker. D1. One Durable Object for websockets and alarms. Cache API on hot GETs. | Analytics command center |
| **Service-bound Workers** | Separate Workers for write path, solver, and UI. Service bindings between them. One Durable Object per order, plus one sender object for EVM nonces. D1 for state that must survive restart. | Par settlement |
| **API + processor** | API Worker stays on the request path. Processor Worker consumes Queues. D1 for records. KV for registry cache. R2 for cold logs. Durable Objects for per-tenant work and rate limits. | Compliance monitoring |
| **Next.js on Workers** | `@opennextjs/cloudflare`. Drizzle against D1 in prod and SQLite in dev. KV for the framework’s incremental cache only. | Operations dashboard |
| **Treasury Worker** | Hono + chanfana. D1. Cron every 60 seconds. KV for email-code counters only. | Managed treasury |

## Workers

Put routes, webhook verification, auth, security headers, and static assets on the Worker.

Split when one of these is true:

- A queue consumer on the same Worker as the live API has already caused latency spikes. Keep scoring and ingest off the request Worker.
- Roles have different trust boundaries (a solver that signs, a UI that does not). Use service bindings rather than public HTTP between your own Workers.

Poll chain confirmation with HTTP. Do not hold a websocket subscription to a public RPC inside a Worker.

## D1

SQLite at the edge. Sessions, transfers, analytics, audit logs, and rate-limit counters belong here.

**Patterns**

- `INSERT OR REPLACE` or `INSERT OR IGNORE` for idempotent sync. Webhooks and the poller will both deliver the same transfer.
- Pre-compute aggregates (`daily_stats` or the equivalent) so chart reads are not a scan.
- `"placement": { "mode": "smart" }` so the Worker runs near the database.
- One schema, two drivers, when you want a fast local loop: Drizzle on `better-sqlite3` in dev and D1 in production. Migrate both the wrangler state directory and the Vite plugin state directory. Local dev often has two D1 files, and migrating one of them looks like “the table is missing”.

## Durable Objects

One instance per key: an organization, an order, an API key. Use `blockConcurrencyWhile` during init. Use `alarm()` for a loop that must keep scheduling itself (re-screening, a fill watch). A cron plus alarms replaces a long-lived chain subscription.

Do not put high-throughput fan-out on a Durable Object. That is a queue, or it is work you await inside the request.

## Alarms and cron

Workers are ephemeral. Anything that must run every minute (transfer poll, balance poll, stuck-row recovery) is an alarm or a Cron Trigger.

| Job | Typical period |
|-----|----------------|
| Transfer safety-net poll | 60 seconds |
| Balance poll | 5 minutes |
| Continuous re-screen | Alarm on the per-tenant or global object |

The managed-treasury poller is specified in [managed-accounts.md](managed-accounts.md).

## KV

Eventually consistent. Good for a registry cache (about a 1 hour TTL), a kill switch, and short idempotency markers.

Bad for sessions, membership, and anything where a stale “allowed” is a security bug. Those rows go in D1.

## R2

Cold storage. Access-log archives, document blobs that are not KYB (KYB documents are transit-only — see [managed-accounts.md](managed-accounts.md)), ingest snapshots. Write asynchronously. Do not read R2 to render the primary screen.

## Queues

Async pipelines with retries and a dead-letter table in D1. Three retries is a reasonable start.

**Do not** use Queues to fan out or to coordinate a synchronous flow. That design has delivered well under 1% of messages (about 0.9% observed). Use a service binding, or await the call in the Worker.

`ctx.waitUntil()` has the same class of mistake. It is for work that can finish after the response (webhook ack, cache fill, a non-critical write). If the next state is “filled” or “settled”, await it. `waitUntil` is not a delivery guarantee.

## Cache API

Short TTL on analytics GETs (10–30 seconds) is enough to absorb dashboard refreshes. Store with `ctx.waitUntil(cache.put(...))`.

In Workers TypeScript, `caches.default` needs a cast. So does `Uint8Array` when you pass it to Web Crypto as a `BufferSource`.

## Web Crypto

AES-GCM, PBKDF2, and HMAC-SHA256 are available. Node’s `crypto` module is not the thing to import.

Ed25519 can go through Web Crypto. secp256k1 cannot; use `@noble` for that curve. Allowlist: `@noble/*`, `@scure/*`, `hash-wasm`, and Web Crypto. Leave `ethers` out.

## Hono + chanfana

For a Worker that is your public API, define each route as an `OpenAPIRoute` whose Zod schemas describe the body, the query, and the response. Chanfana serves `/openapi` from those schemas. You do not maintain a second spec.

Validation errors come back as `{ errors: [...] }` with field paths. Parse those on the client.

```typescript
import { OpenAPIRoute } from "chanfana";
import { z } from "zod";

const Body = z.object({
  amount: z.object({ value: z.string().regex(/^\d+\.\d{2}$/) }),
});
const TransferResponse = z.object({ id: z.string() });

export class CreateTransfer extends OpenAPIRoute {
  schema = {
    request: { body: { content: { "application/json": { schema: Body } } } },
    responses: {
      "201": {
        description: "Transfer created",
        content: { "application/json": { schema: TransferResponse } },
      },
    },
  };

  async handle(c) {
    // authenticate, then call Brale with an Idempotency-Key
  }
}
```

Use this on the [managed treasury](concepts.md#managed-treasury) shape. A single-purpose analytics Worker can stay with plain route handlers.

## Multi-workspace access

When one person operates several organizations:

- A `memberships` table: `(user_id, organization_id, role, created_at)`
- The session stores the active `organization_id`. Every query is scoped to it.
- `POST /session/switch` changes the active organization without a new login.
- Creating a workspace provisions the organization, the Brale account, the wallet, and the membership in one transaction.
- The UI is a switcher that lists memberships. Do not encode the organization only in a client-side global.

## Invite-gated signup

Use this when onboarding is controlled.

- Admin sessions are a different token and a different route prefix from user sessions.
- Invite codes are human-readable, single-use, and optionally expiring.
- The client checks the code before sending an email code. The server consumes it atomically:

```sql
UPDATE invite_codes
SET status = 'used', used_by_org_id = ?
WHERE id = ? AND status = 'active';
```

Treat a zero-row update as “code already used”. Do not check and then update in two statements.

## Gotchas

| What breaks | Fix |
|-------------|-----|
| Vite plugin ignores your wrangler config | Point `@cloudflare/vite-plugin` at the real `wrangler.jsonc`, including when the app root is not the config root |
| Migrations “did nothing” locally | Apply them to both local D1 state directories (wrangler CLI and the Vite plugin) |
| Content-security policy blocks fonts | Self-host the font files. `font-src 'self'` |
| Deploy serves the wrong files | Deploy the built asset directory, not the source tree |
| Chain confirmation never arrives | HTTP poll. Do not subscribe. |
| Frontend JSON parse error in dev | The Vite proxy target must be wrangler’s actual port (often `8788`, not `8787`). A wrong port returns an HTML error page. |
| `caches.default` or Web Crypto types fail | Cast. The runtime is fine; the types are narrower than the runtime. |

## Related

- [concepts.md](concepts.md)
- [brale-api.md](brale-api.md) — webhooks and the three-layer sync
- [security.md](security.md)
- [managed-accounts.md](managed-accounts.md)
