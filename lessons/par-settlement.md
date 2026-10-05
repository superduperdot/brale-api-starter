# Par settlement

Field notes for moving Brale-issued stablecoins across chains at par. Architecture: [concepts.md](../guide/concepts.md#par-settlement).

### Generic bridge stacks do not settle issuer tokens

- **What happened:** An oracle-and-bridge stack produced many transactions, many reverts, and no settlements for Brale-issued tokens.
- **Do this instead:** Brale is the issuer. Cross-chain movement is burn and mint at par (ION), not prove-and-release through an AMM.
- **Guide:** [Brale API](../guide/brale-api.md)

### Habits that belong in code

- **Do this instead:** A mined transaction is not a successful fill. Sleep is not verification. Bytecode beats docs for what a contract does. Read decimals from the chain, not from a config file you hope is current. Prefer events (or a poll of them) over a websocket. State that must survive a restart lives in D1 or a Durable Object. Simulate before broadcast. Set gas explicitly on transactions that depend on each other. Every fill leg comes from the order, not from ambient config.
- **Guide:** [Testing](../guide/testing.md), [Cloudflare](../guide/cloudflare-stack.md)

### `waitUntil` marked a fill that never finished

- **What happened:** Background work was assumed to complete before the order was marked filled.
- **Do this instead:** Await anything that gates `filled` or `claimed`.
- **Guide:** [Cloudflare — Queues and waitUntil](../guide/cloudflare-stack.md)

### Queues dropped the coordination path

- **What happened:** Using Queues to fan out work delivered about 0.9% of messages.
- **Do this instead:** Queues are write-behind (archives, drains). Coordinate with service bindings or by awaiting in the Worker.
- **Guide:** [Cloudflare — Queues](../guide/cloudflare-stack.md)

### Brale cannot source from an external solver key

- **What happened:** Transfers failed because `source` was an external EOA. Brale sources from internal custodial addresses only.
- **Do this instead:** Deposit on-chain, let Brale credit the custodial balance, convert or mint, deliver, then reimburse the claim so the custodial balance nets to zero.
- **Guide:** [Brale API — transfers](../guide/brale-api.md)

### Unprofitable fills reached settlement

- **Do this instead:** Throw in the settler when the quote is unprofitable, and fail CI with a gate script. Reject the quote when it is published, not when someone reads a dashboard.
- **Guide:** [Testing](../guide/testing.md)

### Contracts cannot check a Brale HMAC

- **What happened:** The webhook signature is HMAC. The on-chain verifier needed ECDSA / EIP-712.
- **Do this instead:** A Worker verifies the HMAC, re-reads the delivery on-chain, and re-signs for the verifier contract.
- **Guide:** [Brale API — webhooks](../guide/brale-api.md)

### The UI offered routes the solver could not fill

- **Do this instead:** Capabilities (layers, assets, chains) live in config, with an explicit env override. The UI refuses the order before the user locks funds.
- **Guide:** [Architectures — par settlement](../guide/concepts.md#par-settlement)

### Websocket subscriptions in Workers

- **Do this instead:** Poll. HTTP for EVM read-your-writes, and Solana `getSignatureStatuses` with `searchTransactionHistory: true`.
- **Guide:** [Cloudflare](../guide/cloudflare-stack.md)
