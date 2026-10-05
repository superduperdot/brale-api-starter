# Naming

Decide names before the first commit. They propagate into URLs, package names, Worker names, and support conversations.

## Four layers

These are related and they are not the same string.

| Layer | Format | Example | Where it shows up |
|-------|--------|---------|-------------------|
| Repo slug | kebab-case noun | `treasury-portal` | Git host, clone path, Worker name |
| Display name | Title case | Treasury Portal | README title, UI chrome |
| Package name | scoped kebab-case | `@acme/treasury-portal` | `package.json` |
| Money label | Value Layer, or plain language | `USDC Base 10.00` | Transfer copy |

The README title is the display name. The one-liner under it says who it is for. Do not put an internal codename in either line.

| Avoid | Prefer | Why |
|-------|--------|-----|
| `TreasuryPortal` as the Git slug | `treasury-portal` | Slugs are kebab-case |
| `treasury-portal-app` | `treasury-portal` | The `-app` suffix adds nothing |
| Renaming a published Worker or npm name in place | Document the old name, migrate on purpose | Deployed names and package names are expensive |

Match Cloudflare names to the repo slug: Worker `treasury-portal` or `treasury-portal-api`, D1 database `treasury-portal`. KV namespaces can be shorter (`treasury-flags`) because they are not the product name.

## Files agents look up by exact name

| File | Purpose |
|------|---------|
| `brain.md` | As-built truth, repo root, lowercase |
| `AGENTS.md` | Working agreement, repo root |
| `architecture.md` | As-built architecture |
| `docs/decisions.md` | Append-only decisions |
| `docs/status.md` | Feature matrix and known bugs |

Do not rename these. The seed prompt and this playbook both assume the names.

## Money words

In operator tools (analytics, investigation, internal audit) use Value Layer labels:

| Do not write | Write |
|--------------|-------|
| onramp | `USD Wire → USDC Base` |
| offramp | `USDC Base → USD ACH Credit` |
| swap | the actual pair, e.g. `USDC Base → SBC Base` |
| payout | `SBC Base → USD ACH Credit` |
| chain | the transfer type: `Base`, `Solana`, `Wire` |
| token | the value type: `USDC`, `SBC`, `USD` |

In a product for non-technical users, do not show the words “value type” or “transfer type” either. Show `USDC`, `Base`, `Wire`. Your public API can say `currency` and `chain` and map to `value_type` and `transfer_type` internally. Both rules are in [value-layer.md](value-layer.md).

## Entity IDs

Prefix ids you mint so a log line tells you the kind of row.

```
{prefix}_{random}
```

One `generateId(entity)` function. Every entity type gets its own prefix.

| Prefix | Entity |
|--------|--------|
| `org_` | Organization |
| `usr_` | User |
| `mem_` | Membership |
| `wlt_` | Wallet |
| `tr_` | Transfer |
| `dst_` | Destination |
| `sess_` | Session |

Add prefixes as you add entities (`card_`, `inv_`). Do not reuse one prefix for two types.

Brale ids (KSUIDs, UUIDs) and other provider ids stay internal. Your public API and your UI return your prefixed id. The map from provider id to your id lives in the database.

## Checklist before the first commit

- [ ] Repo slug, display name, and package name chosen and written at the top of `brain.md`
- [ ] README title is the display name
- [ ] No codename in the title or the customer paragraph
- [ ] Worker and D1 names match the slug, if you deploy to Cloudflare
- [ ] Transfer copy follows the rule for your audience (operator grammar, or plain language)
- [ ] New ids go through `generateId`

## Related

- [getting-started.md](getting-started.md)
- [value-layer.md](value-layer.md)
- [../templates/SEED-PROMPT.md](../templates/SEED-PROMPT.md)
