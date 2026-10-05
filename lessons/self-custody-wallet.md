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
- **Do this instead:** Use a reliable RPC for the native asset. Race RPC against `brale.network/api` for stablecoin history. Merge on `chain:txHash`. Paint a cached balance and refresh behind it.
- **Guide:** [Brale API — read APIs](../guide/brale-api.md), [Design](../guide/design-style.md)

### Content scripts reaching the vault

- **What happened:** A page-origin message could be confused with a user action inside the extension.
- **Do this instead:** Accept privileged messages only from extension pages. Take the dapp origin from the browser sender, not from the message body.
- **Guide:** [Security](../guide/security.md)

### The handoff docs

- **What happened:** The next session re-discovered architecture that lived only in chat.
- **Do this instead:** Keep `brain.md`, an append-only decision log, a status matrix, and `AGENTS.md`. Read `brain.md` first.
- **Guide:** [Working with AI agents](../guide/ai-agents.md)

### Explorer links

- **Do this instead:** Link tracked stablecoins to `brale.network/tx/<transferType>/<valueType>/<hash>`.
- **Guide:** [CSF and GSF](../guide/csf-gsf.md)
