# Lessons

Field notes, one file per architecture in [guide/concepts.md](../guide/concepts.md). The guide says what to do. These say what went wrong and which page to follow.

## Format

```markdown
### Title

- **What happened:** the failure or the surprise
- **Do this instead:** the rule, in one or two sentences
- **Guide:** link to the playbook section
```

## When to add one

| When this happens… | Also update |
|--------------------|-------------|
| A Brale quirk bites you | `guide/brale-api.md` and the concept’s lesson file |
| A Cloudflare choice was wrong | `guide/cloudflare-stack.md`. Update `guide/concepts.md` if the recommended shape changes. |
| A security control changes | `guide/security.md` |
| You confirm a new architecture is worth recommending | A section in `guide/concepts.md` and a new file here |

Do not open a lesson file per product. If the note does not fit an existing architecture, say so in the pull request and add the architecture first.

## By architecture

- [Self-custody wallet](self-custody-wallet.md)
- [Agent wallet](agent-wallet.md)
- [Par settlement](par-settlement.md)
- [Analytics command center](analytics.md)
- [Operations dashboard](operations-dashboard.md)
- [Compliance monitoring](compliance.md)
- [Managed treasury](managed-treasury.md)
- [Balance reconciliation](balance-reconciliation.md)
- [Cloudflare platform](cloudflare-platform.md)
