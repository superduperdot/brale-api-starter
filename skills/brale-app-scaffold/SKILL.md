---
name: brale-app-scaffold
description: >-
  Bootstrap a new Brale app repo from playbook templates and paste SEED-PROMPT.
  Use when starting a new repository, when the user says "scaffold", "new repo",
  "bootstrap", or "create project" for a Brale integration.
disable-model-invocation: true
---

# Brale app scaffold

Bootstrap a repository for a Brale integration using the playbook templates.

## Prerequisites

Before scaffolding, the user must have decided:

| Field | Source |
|-------|--------|
| Architecture | One of seven from `guide/concepts.md` (use the `brale-architecture-router` skill if undecided) |
| Repo slug | Follow `guide/naming-conventions.md` |
| Display name | Follow `guide/naming-conventions.md` |
| Package name | Follow `guide/naming-conventions.md` |
| Customer | One sentence: who this is for |
| Brale surface | `api.brale.xyz` / read API / none |
| Cloudflare | Workers + (D1, DO, KV, R2, Queues, Cron) / none |

If any field is missing, ask the user. Do not guess names or architectures.

## Scaffold steps

1. **Create the repo directory** with the chosen slug.

2. **Copy these templates** from the playbook `templates/` directory:

   | File | Role |
   |------|------|
   | `README.md` | Who it is for, Brale surface, Cloudflare primitives |
   | `brain.md` | As-built truth — read this first, forever |
   | `AGENTS.md` | Commands, guardrails, when to update the playbook |
   | `architecture.md` | Runtime and file index |
   | `CONTRIBUTING.md` | Setup and pull requests |
   | `SECURITY.md` | Vulnerability reporting |
   | `LICENSE` | MIT unless the user said otherwise |

3. **Fill in the templates:**
   - Write the architecture name and customer sentence into `brain.md` and `README.md`.
   - Fill the Brale API and Cloudflare tables in `README.md`.
   - Set the stack in `architecture.md` based on the architecture's recommended layout from `guide/concepts.md`.

4. **Paste SEED-PROMPT** — copy `templates/SEED-PROMPT.md` into the agent session, with the decisions table filled in.

5. **Initialize the project:**
   - `git init && pnpm init`
   - TypeScript strict: `tsconfig.json` with `"strict": true`
   - Add `.gitignore`, `.dev.vars` (gitignored — secrets go here, never in committed config)

## Repo checklist

After scaffolding, verify:

- [ ] Architecture named in README (one sentence)
- [ ] Customer named in the first screen of README
- [ ] Brale API table filled in, or explicit "none"
- [ ] Cloudflare table filled in, or explicit "none"
- [ ] `brain.md`, `AGENTS.md`, `architecture.md` present
- [ ] Entity IDs prefixed (`org_`, `tr_`, …) if you mint your own identifiers
- [ ] Link to the playbook from README
- [ ] `.dev.vars` in `.gitignore`

## Reference

- `guide/getting-started.md` — full first-integration runbook
- `guide/naming-conventions.md` — naming rules
- `guide/concepts.md` — the seven architectures
- `templates/SEED-PROMPT.md` — bootstrap prompt
