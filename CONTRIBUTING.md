# Contributing

Thanks for improving the Brale API Starter.

## What to change

This repo is a runbook. A good change saves the next builder a wrong turn: a Brale quirk, a Cloudflare choice, a security control, or a clearer step in the first-integration checklist.

## Giving feedback

You do not need to write a pull request to help.

| You have… | Do this |
|-----------|---------|
| A correction (something is wrong or stale) | Open a **Correction or pitfall** issue. Include evidence. |
| A pattern that saved or cost you time | Open a **New pattern or lesson** issue. |
| A question, or "is this the right shape?" | Open a **Discussion**, not an issue. |
| A security concern | See [SECURITY.md](templates/SECURITY.md) — report privately, do not open a public issue. |
| A fix ready to go | Open a pull request (the template has the checklist). |

The issue forms ask for the one thing that keeps this playbook trustworthy: **evidence**. A correction to a Brale API claim needs a link to [docs.brale.xyz](https://docs.brale.xyz), a live response, or the OpenAPI spec. We have already had to undo confidently-worded claims that were never checked — the forms exist so that does not happen again.

## The bar for any change

Whoever (or whatever) writes it, every change clears the same bar:

1. **A concrete failure or a concrete shape.** "Split the API Worker from the processor because queue consumers spiked latency" — not "decouple your services." Abstract advice is not accepted.
2. **Evidence for every Brale API or Cloudflare claim.** An official doc, a live request/response, or a spec. If you cannot verify an endpoint shape, say so and flag it rather than asserting it.
3. **Recommendation in `guide/`, story in `lessons/`.** The guide page says what to do; the matching `lessons/` file says what went wrong.
4. **Scoped to an architecture when it is architecture-specific**, with a link to [guide/concepts.md](guide/concepts.md).
5. **No product names, no private repo links.** Describe the shape and the failure, not a codebase the reader cannot open.

## For LLMs and agents

If you are an AI agent proposing a change, read [AGENTS.md](AGENTS.md) first — it governs editing this repo — then follow this loop:

1. **Verify before you write.** Fetch the relevant [docs.brale.xyz](https://docs.brale.xyz) page or call the [Brale Network API](https://brale.network/api). Paste what you observed (status code and body) into the issue or PR. Do not restate repo text back as if it were a source.
2. **One topic per change.** Touch the fewest pages that make the point: a `guide/` page and its `lessons/` file.
3. **Match the voice.** Second person, imperative, specific. Tables over paragraphs where a table fits.
4. **Follow the trigger table** in [AGENTS.md](AGENTS.md) ("when X happens, update Y") so related pages stay in sync.
5. **State your uncertainty.** If a claim is inferred rather than verified, label it. A flagged unknown is more useful than a confident guess.

A reviewer should be able to re-run your evidence and get the same answer. That is the whole test.

## Fix or extend a guide page

1. Edit the file in `guide/`.
2. If the advice only applies to one architecture, say so, and link [guide/concepts.md](guide/concepts.md).
3. Open a pull request that says what changed and which failure it prevents.

## Add a field note

1. Append to the matching file in `lessons/` (one file per architecture).
2. Use: what happened, what to do instead, which guide section to follow.
3. If the note changes a recommendation, update that `guide/` page in the same pull request.

## Templates

Files in `templates/` are copied into new apps. Keep placeholders obvious (`{{App Name}}`, `YYYY-MM-DD`). Do not point them at a private repository.

## Pull requests

- One topic per pull request.
- Check that links to public docs still resolve.
- Do not add product names or links to private application repositories.

## Docs

- [guide/concepts.md](guide/concepts.md) — pick an architecture
- [guide/getting-started.md](guide/getting-started.md) — first-integration runbook
- [guide/ai-agents.md](guide/ai-agents.md) — how agents should use this playbook inside an app repo

## License

By contributing, you agree your contributions are licensed under the [MIT license](LICENSE).
