# Packaged skills

Installable Cursor Agent Skills extracted from this playbook. Each skill encapsulates a decision process — architecture routing, Cloudflare pattern selection, scaffolding, or security review — so a downstream agent can apply the playbook without reading every page.

## Skills

| Skill | What it decides |
|-------|-----------------|
| [brale-architecture-router](brale-architecture-router/SKILL.md) | Routes a new build to one of the seven architectures, its read-next list, and the non-negotiables |
| [brale-cloudflare-patterns](brale-cloudflare-patterns/SKILL.md) | Which Cloudflare primitive to use and the DO/queue/sync pitfalls |
| [brale-app-scaffold](brale-app-scaffold/SKILL.md) | Bootstrap a repo from `templates/` and paste SEED-PROMPT |
| [brale-security-review](brale-security-review/SKILL.md) | Before-you-ship security and webhook-integrity checklist |

## Install

Run the installer to copy skills into your Cursor or Claude skills directory:

```bash
./skills/install.sh
```

By default, skills are installed to `~/.cursor/skills/`. Pass `--claude` to install to `~/.claude/skills/` instead. Pass a custom path to install elsewhere:

```bash
./skills/install.sh ~/.cursor/skills
./skills/install.sh --claude
```

## Keeping skills in sync

When a `guide/` page changes a recommendation, update the matching skill. See the trigger table in [AGENTS.md](../AGENTS.md).
