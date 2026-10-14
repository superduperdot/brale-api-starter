# Working with AI agents

How to lay out an app repo so a person and an agent can continue the work, and how that agent should use this playbook.

## Inside an app repo

| File | What it is |
|------|------------|
| `brain.md` | As-built truth: what shipped, where it lives, open bugs, next step |
| `AGENTS.md` | Commands, conventions, guardrails |
| `architecture.md` | Runtime and a file index |
| `docs/decisions.md` | Append-only decisions: decision, rationale, consequences |
| `docs/status.md` | Feature matrix and known bugs |

Read `brain.md` first, then the architecture section you are touching, then `AGENTS.md`.

`brain.md` describes the repository as it is. If a behavior is not in the code, it is not in `brain.md`. Add dated notes. Do not rewrite history into a plan.

Copy the starters from [templates/](../templates/). Alternatively, install the packaged skills (`./skills/install.sh`) so the agent can apply architecture routing, Cloudflare patterns, scaffolding, and security review directly. See [skills/README.md](../skills/README.md).

## How an agent should use this playbook

1. Read [concepts.md](concepts.md) and name the architecture in `brain.md` before writing a Worker, a schema, or a wallet.
2. Follow only that architecture’s “read next” list. Do not import patterns from the other six unless the product actually spans them.
3. For any call to `api.brale.xyz`, also read the [Brale Agent Kit AGENTS.md](https://github.com/superduperdot/brale-agent-kit/blob/main/AGENTS.md) and prefer its `reference/` implementations over new clients.
4. Before calling the work done, run the commands in the app’s `AGENTS.md` and the checks in [testing.md](testing.md).
5. When a Brale or Cloudflare behavior surprises you, add a dated note to the app’s `brain.md`. If the note would save the next app, add a field note under [lessons/](../lessons/) and adjust the matching `guide/` page.

## Decisions

Write a decision record when you reverse a previous choice, when two architectures both look plausible, or when a sharp edge will hit the next session. Keep the old record. Mark it superseded. Deleting it is how the same mistake returns.

A canonical example: shipping gasless smart accounts before plain EOA sends worked, then reverting that, because dapps assumed an EOA. The record is more useful than the revert itself.

## Experiments

Spikes live in `experiments/` (or a similar directory) outside the package you publish. They do not get imported by the extension or the Worker until a decision record says they graduated.

## Guardrails to copy into the app

- Do not commit unless the person asked.
- Do not add a custodian, a chain, or a new Brale product surface without an explicit ask.
- Do not log KYB payloads, client secrets, or raw webhook secrets.
- Do not store sessions in KV.
- Do not mark money “sent” or “settled” inside `ctx.waitUntil()`. Await that write.

## Related

- [getting-started.md](getting-started.md)
- [durable-objects.md](durable-objects.md) — cross-cutting DO patterns
- [sync-engine.md](sync-engine.md) — backfill, cursors, balance discovery
- [../templates/brain.md](../templates/brain.md)
- [../templates/AGENTS.md](../templates/AGENTS.md)
- [../lessons/README.md](../lessons/README.md)
- [../skills/README.md](../skills/README.md) — installable agent skills
