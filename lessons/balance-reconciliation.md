# Balance reconciliation

Field notes for deposits that land on the preferred hold and disappear. Architecture: [concepts.md](../guide/concepts.md#managed-treasury).

### Deposit arrived, balance grew, no record

- **What happened:** A $20 stablecoin deposit landed directly on the preferred hold (Canton). The webhook never fired. Discovery (`listTransfers`) did not find it because the transfer had aged past the ~25-item ceiling. The balance sweep correctly skipped it — the preferred hold is the destination, not a source. Result: the Brale balance was correct, but the local ledger, activity feed, and email notifications had no trace of it.
- **Do this instead:** Add a fourth poller job that compares the actual Brale balance on the preferred hold to the ledger's expected balance. When the actual exceeds expected by more than dust, query `listTransfers` to find the specific transfer. If found, record it with its Brale transfer ID and source. If a gap remains after matching all listed transfers, record a generic inbound deposit. This two-step approach preserves real transfer metadata when possible and still catches truly untracked credits.
- **Guide:** [Managed accounts — poller](../guide/managed-accounts.md#preferred-hold-reconciliation-details)

### Sweep hit the wrong environment

- **What happened:** An org had both testnet and mainnet Brale accounts. The poller's balance sweep iterated every row in `brale_addresses` without filtering by environment. A testnet account tried to read balances and sweep a mainnet Canton address using a testnet bearer token. Brale returned `403 Incorrect API key for requested network`. The Worker logged errors on every 60-second cycle and eventually exceeded the CPU time limit.
- **Do this instead:** Before iterating addresses for an account, filter to only those whose `transfer_type` maps to the same environment as the account (`networkEnvironment(transfer_type) === account.environment`). This is a one-line filter, and without it the poller is broken for any org that touches both environments.
- **Guide:** [Managed accounts — cross-environment address filter](../guide/managed-accounts.md#cross-environment-address-filter)

### Automation pointed at the old chain

- **What happened:** The preferred hold changed from Base to Canton. The Brale Automation for wire deposits still pointed at Base. `PATCH` and `DELETE` on the automation both failed — automations are immutable. Wire deposits kept minting on Base. The balance sweep eventually converted them, but there was a delay and the extra hop was confusing in the activity feed.
- **Do this instead:** Create a new automation targeting the new chain. Accept that the old automation stays active. Rely on the balance sweep as the backstop for any deposits that still land on the old destination. Document that automation retargeting is a create-new, not an update.
- **Guide:** [Managed accounts — automations](../guide/managed-accounts.md#automations)

### `listTransfers` ceiling

- **What happened:** Brale's `listTransfers` returns only the ~25 most recent transfers per account. All pagination parameters (`page[next]`, `page[size]` > 25) either return the same page or error. Transfers older than this window are permanently invisible to any polling job that relies on transfer listing.
- **Do this instead:** Do not treat `listTransfers` as a complete history. Use it for recent-deposit discovery (Job 2), but rely on balance reads (Jobs 3–4) to catch anything it misses. For analytics or full history, build from webhook events and reconciliation records, not from repeated `listTransfers` calls.
- **Guide:** [Brale API — pitfalls](../guide/brale-api.md#pitfalls)
