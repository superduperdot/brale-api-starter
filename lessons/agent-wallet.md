# Agent wallet

Field notes for a library that lets software send stablecoins. Architecture: [concepts.md](../guide/concepts.md#agent-wallet).

### Nothing is watching a popup

- **What happened:** Agents cannot wait for a person to approve a transaction in a window.
- **Do this instead:** A policy engine (`maxPerSend`, `maxPerSession`, allowlists) and an audit record run before `send()`. Rejection happens before any network call.
- **Guide:** [Brale API](../guide/brale-api.md), [Security](../guide/security.md)

### Brale Network API is a registry, not a balance source

- **What happened:** Code assumed a `brale.network/api/wallet/{chain}/{address}` endpoint for balances. There is no such endpoint — the Brale Network API describes value types, transfer types, and prices, not wallets.
- **Do this instead:** Read balances from chain RPC. Use `brale.network/api/value-type/:id` to get the contract address and `decimals` so you decode correctly, and `/price/:value_type` for USD value. Do not send through that API.
- **Guide:** [Brale API — read surfaces](../guide/brale-api.md)

### Do not depend on the extension package

- **What happened:** A headless library could not import an extension package’s crypto module.
- **Do this instead:** Implement the same BIP-39 / BIP-44 / SLIP-0010 rules so one mnemonic yields the same addresses. Share test vectors. Do not share the extension runtime.
- **Guide:** [Architectures](../guide/concepts.md#agent-wallet)

### Token-2022

- **What happened:** A Brale-issued stable on Solana uses the Token-2022 program, so a classic SPL query missed it.
- **Do this instead:** Query both token programs when you discover balances.
- **Guide:** [Self-custody wallet](self-custody-wallet.md) (same RPC issue)

### Process lifetime

- **What happened:** A long-running agent kept key material after the caller was finished.
- **Do this instead:** `destroy()` zero-fills and throws on later calls.
- **Guide:** [Security](../guide/security.md)

### Float rounding in send amounts
- **What happened:** Token amounts were computed as `BigInt(Math.round(parseFloat(amount) * 10 ** decimals))`. Floating-point imprecision silently changed the amount.
- **Do this instead:** Use a decimal-string library or integer arithmetic on the raw string. Never `parseFloat` a financial amount.
- **Guide:** [Value Layer — money](../guide/value-layer.md)

### Zero-fill-after-copy regression
- **What happened:** After SLIP-0010 derivation, `seed.fill(0)` zeroed the seed — but the derived secret key bytes had already been copied by reference, not by value. The live key was zeroed.
- **Do this instead:** Copy secret-key bytes into a new buffer before zero-filling the source. Test: `secretKeyBytes is not zeroed after fromMnemonic`.
- **Guide:** [Security](../guide/security.md)

### No shared derivation test vectors
- **What happened:** The extension and the agent library derived different addresses from the same mnemonic because derivation paths diverged silently.
- **Do this instead:** Pin test vectors (e.g. `abandon…about` → known EVM and Solana addresses for `m/44'/60'/0'/0/0` and `m/44'/501'/0'/0'`). Run them in both packages.
- **Guide:** [Testing](../guide/testing.md)
