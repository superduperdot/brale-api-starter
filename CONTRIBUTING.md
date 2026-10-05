# Contributing

Thanks for improving the Brale Playbook.

## What to change

This repo is a runbook. A good change saves the next builder a wrong turn: a Brale quirk, a Cloudflare choice, a security control, or a clearer step in the first-integration checklist.

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
