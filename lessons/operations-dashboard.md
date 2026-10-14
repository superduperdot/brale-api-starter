# Operations dashboard

Field notes for a self-hosted dashboard over Brale. Architecture: [concepts.md](../guide/concepts.md#operations-dashboard).

### Pages that call Brale on every view

- **What happened:** Live API calls made the UI slow.
- **Do this instead:** Sync into SQLite locally and D1 in production. Pages read the database. After the first sync the app still works offline.
- **Guide:** [Brale API — sync](../guide/brale-api.md)

### Transfer forms that start with the rail

- **Do this instead:** Person, then payment method, then amount. Contacts and their methods live in your database. Brale does not store that address book.
- **Guide:** [Design](../guide/design-style.md)

### Bank-link calls and missing idempotency keys

- **What happened:** POSTs that were not “transfers” still failed without `Idempotency-Key`.
- **Do this instead:** Send the header on every Brale POST that creates a resource, including bank linking.
- **Guide:** [Brale API — transfers](../guide/brale-api.md)

### Errors that say “request failed”

- **Do this instead:** Parse JSON:API `detail` and return that string from the server action.
- **Guide:** [Brale API — pitfalls](../guide/brale-api.md)

### Two databases, one schema

- **Do this instead:** The same Drizzle schema targets `better-sqlite3` in dev and D1 in production.
- **Guide:** [Cloudflare — D1](../guide/cloudflare-stack.md)

### Chain logos

- **Do this instead:** Pull `logo_url`, `display_name`, and `explorer_url` from the open [Brale Network API](https://brale.network/api) (`/transfer-type/:id`, `/value-type/:id`) instead of hand-maintaining a chain map. Cache it (it is free but rate-limited to 120 req/min).
- **Guide:** [Design](../guide/design-style.md)

### Environment toggle hid the wrong things

- **What happened:** A mainnet/testnet switch filtered addresses and still showed the other environment’s transfer types.
- **Do this instead:** Apply the environment at the transfer-type level, globally. Remember the environment is whichever OAuth client minted the token.
- **Guide:** [Brale API — authentication](../guide/brale-api.md)

### Lost creates on a timeout

- **Do this instead:** Write the intent first. Retry with the same idempotency key and exponential backoff. Sync status in the background.
- **Guide:** [Brale API — intent-first](../guide/brale-api.md)

### No record of who did what

- **Do this instead:** Append-only audit log for API calls and user actions, formatted with Value Layer labels. Run every entry through the same log redaction so request/response bodies do not turn the audit table into a PII or secrets store.
- **Guide:** [Value Layer](../guide/value-layer.md), [Security](../guide/security.md)

### Reconciler generated a new idempotency key per retry
- **What happened:** The reconciler called createTransfer with `Idempotency-Key: crypto.randomUUID()` on each attempt. Retries created duplicate transfers instead of replaying.
- **Do this instead:** Store the idempotency key with the intent row when you first create it. Pass that same key on every retry.
- **Guide:** [Brale API — idempotency](../guide/brale-api.md), [Sync engine](../guide/sync-engine.md)
