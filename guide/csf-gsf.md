# CSF and GSF

Two open formats for the same Value Layer primitives. CSF is the ordered story of a payment. GSF is the map of who is connected, without time.

| Format | Spec | Use it when |
|--------|------|-------------|
| **CSF** (Commons Stablecoin Format) | [csf.json](https://github.com/Brale-xyz/commons/blob/main/Commons%20Stablecoin%20Format/csf.json) | You need the steps, in order, through named participants |
| **GSF** (Graph Standard Format) | [gsf-0.5.2.json](https://github.com/benmilne-com/standards/blob/main/gsf/gsf-0.5.2.json) | You need entities and relationships, and order does not matter |

Pinned here as of **2026-06-24**. Read the upstream file before you generate a diagram from an old copy.

## CSF

Answers: how did value move from A to B, step by step?

- Render as a Mermaid `sequenceDiagram`
- A leg reads `ValueType TransferType Amount` (example: `USDC Solana 5,000`)
- Density is Light, Medium, or Heavy
- Paste the current `csf.json` into the prompt when you ask a model to draw a flow. Do not paraphrase the spec into the prompt.

**Where to apply it**

| Job | What to render |
|-----|----------------|
| Compliance investigation | The funds-flow tab. One sequence per subject. |
| Par settlement | Settlement legs: escrow, delivery, attestation, claim. Capability lists use the same grammar. |
| Analytics | The activity row: `$AMOUNT SOURCE_VT SOURCE_TT → DEST_VT DEST_TT` |
| Self-custody wallet | Explorer links built from the chain's `explorer_url` (`brale.network/api/transfer-type/:id`) plus the tx hash |

You do not need a CSF renderer on day one. You do need the leg format in any operator-facing transfer list. See [value-layer.md](value-layer.md).

## GSF

Answers: which entities exist, and what links them?

- Render as a force-directed graph from `{ view, nodes, links }`
- Primitives: relationship, type, variables, weight
- Density: light, medium, heavy. Light is achromatic, matching CSF Light.
- Paste `gsf-0.5.2.json` into the prompt when you ask a model for a dataset.

**Where to apply it**

| Job | What the graph is |
|-----|-------------------|
| Compliance investigation | Subject graph, hop depth you choose (1–5 has been used), edges labeled with value type and transfer type |
| Operations dashboard | Contacts and their payment methods. A natural graph even before you draw it. |
| Analytics | Account → address → value type, when you outgrow a flat feed |
| Par settlement | Solver and route topology, when you need to explain coverage |

## Converting between them

| CSF | GSF |
|-----|-----|
| Participant | Node |
| Value leg | A `transaction` or `transfers_via` link |
| Data leg | An `instruction` link |
| An exchange | `transfers_via` whose endpoints differ, plus `via` |
| Step order | Not in GSF. Keep CSF if order matters. |

Going CSF → GSF → CSF drops the order of steps. Going GSF → CSF → GSF keeps the structure. If an investigator needs “what happened first”, store CSF. If they need “who touches whom”, store GSF. Storing only one and converting at read time will lose the other question.

Source: [standards README](https://github.com/benmilne-com/standards/blob/main/README.md).

## Related

- [value-layer.md](value-layer.md)
- [concepts.md](concepts.md#compliance-monitoring)
- [design-style.md](design-style.md)
