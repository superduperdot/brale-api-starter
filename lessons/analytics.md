# Analytics command center

Field notes for a real-time view of an account. Architecture: [concepts.md](../guide/concepts.md#analytics-command-center).

### Invented categories in the feed

- **Do this instead:** Never label a row onramp, offramp, or swap. Use `ValueType TransferType Amount`. Let filters match either leg.
- **Guide:** [Value Layer](../guide/value-layer.md)

### Every webhook signature failed

- **What happened:** HMAC verification failed on the first deploy.
- **Do this instead:** `sharedSecret` is Base64URL and is shown once. Decode it to raw bytes before you use it as the HMAC key. Store the decoded key encrypted.
- **Guide:** [Brale API — webhooks](../guide/brale-api.md)

### `GET /accounts` changed shape

- **What happened:** The same call returned full objects or bare KSUID strings.
- **Do this instead:** Parse both.
- **Guide:** [Brale API — pitfalls](../guide/brale-api.md)

### Webhooks were treated as complete

- **Do this instead:** Webhooks for speed, a 60-second alarm to poll, and a cold start from `MAX(created_at)`. Return 200, then write to D1 in `ctx.waitUntil()`.
- **Guide:** [Brale API — sync](../guide/brale-api.md), [Cloudflare](../guide/cloudflare-stack.md)

### Charts scanned the transfer table

- **Do this instead:** Maintain a daily aggregate and read that.
- **Guide:** [Cloudflare — D1](../guide/cloudflare-stack.md)

### First Cloudflare deploy

- **What happened:** The Vite plugin did not see wrangler config, only one of two local D1 databases was migrated, the deploy uploaded the wrong directory, and the content-security policy blocked the font CDN.
- **Do this instead:** Point the plugin at the real wrangler file. Migrate both local databases. Deploy the built asset directory. Self-host fonts.
- **Guide:** [Cloudflare — gotchas](../guide/cloudflare-stack.md)

### Security suite

- **Do this instead:** Test auth, CSRF if you use cookies, rate limits, websocket auth, security headers, and webhook integrity against the running app.
- **Guide:** [Security](../guide/security.md), [Testing](../guide/testing.md)

### Hashes

- **Do this instead:** A transfer may carry 0, 1, or 2 on-chain hashes. Cross-chain shows burn and mint. Fiat shows none.
- **Guide:** [Value Layer](../guide/value-layer.md)
