# Self-custody wallet

Field notes for a browser extension where the person holds the keys. Architecture: [concepts.md](../guide/concepts.md#self-custody-wallet).

### Gasless before EOA parity

- **What happened:** An ERC-4337 wallet with a paymaster shipped. Dapps broke. They expected an EOA (including EIP-7702 assumptions), not a counterfactual account.
- **Do this instead:** Prove ordinary EOA sends on the chains you support. Treat gasless as a later decision, with a written record if you reverse it.
- **Guide:** [Working with AI agents](../guide/ai-agents.md)

### Wallet creation fails with no error

- **What happened:** Argon2id through `hash-wasm` needed `wasm-unsafe-eval` in the extension content-security policy. Without it, creation failed silently. Unit tests never loaded the page.
- **Do this instead:** End-to-end test the built extension, including creating a wallet.
- **Guide:** [Security](../guide/security.md), [Testing](../guide/testing.md)

### Where key material lives

- **What happened:** A vault design had to survive extension storage, which content scripts and web pages can reach in different ways.
- **Do this instead:** Encrypted envelope in local storage. Session key in session storage, limited to trusted extension contexts. Decrypted bytes on the heap only, zero-filled after use. Never regenerate the KDF salt on re-seal.
- **Guide:** [Security](../guide/security.md)

### Balances and history lie if you trust one source

- **What happened:** Public Solana RPCs rate-limit or omit transaction data, so stables looked like a zero balance.
- **Do this instead:** Use a reliable RPC (and an indexer where needed). Pull the contract address and `decimals` from `brale.network/api/value-type/:id` so you query the right token and decode it correctly. Merge activity on `chain:txHash`. Paint a cached balance and refresh behind it. The Brale Network API is a registry and price source, not a wallet-history endpoint.
- **Guide:** [Brale API — read surfaces](../guide/brale-api.md), [Design](../guide/design-style.md)

### Content scripts reaching the vault

- **What happened:** A page-origin message could be confused with a user action inside the extension.
- **Do this instead:** Accept privileged messages only from extension pages. Take the dapp origin from the browser sender, not from the message body.
- **Guide:** [Security](../guide/security.md)

### The handoff docs

- **What happened:** The next session re-discovered architecture that lived only in chat.
- **Do this instead:** Keep `brain.md`, an append-only decision log, a status matrix, and `AGENTS.md`. Read `brain.md` first.
- **Guide:** [Working with AI agents](../guide/ai-agents.md)

### Explorer links

- **Do this instead:** Build explorer links from the chain's `explorer_url` in `brale.network/api/transfer-type/:id` plus the tx hash. Do not hardcode explorer domains per chain.
- **Guide:** [Brale API — read surfaces](../guide/brale-api.md)

### Indexed wallet history treated as authoritative balance
- **What happened:** A fallback balance was computed by summing amounts from an indexed `/wallet/{chain}/{address}` transaction-history endpoint. The sums drifted from actual on-chain balances.
- **Do this instead:** Treat indexed history as transaction history only, not as an authoritative balance. Read balances from chain RPC. Use the history for activity feeds and to seed the balance-discovery set, not as a balance source. (This endpoint is observed in production but not documented in any public OpenAPI spec.)
- **Guide:** [Brale API — read surfaces](../guide/brale-api.md)

### Side panel vs popup is a runtime decision
- **What happened:** The extension shipped with a popup only. Users on wide monitors wanted the extension docked.
- **Do this instead:** Default to `chrome.sidePanel` (Chrome 114+); set `openPanelOnActionClick: true`. Store the preference. Same React app detects panel mode.
- **Guide:** [Design](../guide/design-style.md)

### WebAuthn cannot run in a service worker
- **What happened:** The passkey PRF flow was called from the background service worker. It threw — `navigator.credentials` is not available in a SW context.
- **Do this instead:** Run WebAuthn / PRF in a popup or full-page tab. Proxy results back to the background via messages.
- **Guide:** [Security](../guide/security.md)

### Pending signing request lost on service-worker kill
- **What happened:** An in-memory promise map for pending dapp approval requests was lost when the MV3 service worker was killed.
- **Do this instead:** Persist pending requests in `chrome.storage.session`. Auto-reject after 5 minutes. Use `chrome.alarms` keepalive while an approval popup is open.
- **Guide:** [Security](../guide/security.md)
