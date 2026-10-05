# Agent wallet

Field notes for a library that lets software send stablecoins. Architecture: [concepts.md](../guide/concepts.md#agent-wallet).

### Nothing is watching a popup

- **What happened:** Agents cannot wait for a person to approve a transaction in a window.
- **Do this instead:** A policy engine (`maxPerSend`, `maxPerSession`, allowlists) and an audit record run before `send()`. Rejection happens before any network call.
- **Guide:** [Brale API](../guide/brale-api.md), [Security](../guide/security.md)

### Brale is the fallback, not the sender

- **What happened:** Solana RPC rate limits reported a zero stablecoin balance.
- **Do this instead:** `GET brale.network/api/wallet/solana/{address}` and sum in and out by `value_type` when RPC fails. Do not send through that API.
- **Guide:** [Brale API — read APIs](../guide/brale-api.md)

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
