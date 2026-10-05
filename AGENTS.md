# AGENTS.md

Guidance for AI agents and contributors working on **this playbook**.

## What you are editing

This repository is a runbook for people building on the Brale API. It is organized by architecture (wallet, agent, settlement, analytics, dashboard, compliance, treasury), not by product name.

Do not add product names, private repo links, or a catalog of sibling applications. If a lesson came from a specific system, write the pattern and the failure mode. Point at a section of `guide/`, not at a codebase the reader cannot open.

## Before editing

- Read [guide/concepts.md](guide/concepts.md) so new advice lands on the right architecture.
- Check [lessons/](lessons/) before adding a rule. If the story already exists, link it. Do not restate it as a new universal law.
- Check [docs.brale.xyz/llms.txt](https://docs.brale.xyz/llms.txt) before changing endpoint paths in [guide/brale-api.md](guide/brale-api.md).

## Adding content

- A rule needs a concrete failure or a concrete shape (“split the API Worker from the processor”). Abstract advice is not enough.
- Put the recommendation in `guide/`. Put the story (what happened, what to do instead) in the matching `lessons/` file.
- Keep pages short. Link to the [Brale Agent Kit reference](https://github.com/superduperdot/brale-agent-kit/tree/main/reference) for TypeScript. Do not paste production clients into this repo.

## When something changes, update these

| When this happens… | …update |
|--------------------|---------|
| A Brale endpoint or quirk is confirmed | `guide/brale-api.md` and the concept’s lesson file |
| A Cloudflare primitive is the right (or wrong) tool | `guide/cloudflare-stack.md` and, if it changes the recommended shape, `guide/concepts.md` |
| A security control changes | `guide/security.md` |
| CSF or GSF changes | `guide/csf-gsf.md` (pinned version and date) |
| A new architecture is common enough to recommend | A section in `guide/concepts.md` plus `lessons/<concept>.md` |
| Brale docs change | Re-verify `guide/brale-api.md` and the table in [README.md](README.md) |
| `brale-agent-kit` documents a new pitfall | Pull the rule into `guide/brale-api.md`. Leave the code in the kit. |

## Voice

- Second person, imperative where you are telling the reader to do something.
- Name the Brale surface (`api.brale.xyz`, `data.brale.xyz`, `brale.network/api`) instead of saying “the API”.
- Prefer “analytics command center” over any product name.

## External references to keep current

| Reference | What to pull |
|-----------|--------------|
| [docs.brale.xyz/llms.txt](https://docs.brale.xyz/llms.txt) | Endpoint inventory, transfer types, value types, webhook events |
| [brale-agent-kit](https://github.com/superduperdot/brale-agent-kit) | Learned API rules and `reference/*.ts` |
| [csf.json](https://github.com/Brale-xyz/commons/blob/main/Commons%20Stablecoin%20Format/csf.json) | CSF version and leg format |
| [gsf-0.5.2.json](https://github.com/benmilne-com/standards/blob/main/gsf/gsf-0.5.2.json) | GSF version and primitives |
| [api.brale.xyz/openapi](https://api.brale.xyz/openapi) | Canonical paths, enums, response shapes |
