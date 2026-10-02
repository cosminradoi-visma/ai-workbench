---
updated: YYYY-MM-DD
---

# Skills

A skill is a folder with a `SKILL.md`. Its description is always in context (about 50
tokens) and its body loads only when used. It is the cheapest way to give an agent a procedure.

## Where they live

| Scope | Path | For |
|-------|------|-----|
| This KB | `.claude/skills/` | Running the KB (`kb-*`) |
| A repo | `<repo>/.claude/skills/` | That codebase's procedures: release, migrations, test data. Commit them so the team gets them |
| You, everywhere | `~/.claude/skills/` | Your habits: how you review, how you write PR descriptions |
| A team | a plugin in a private marketplace | Shared, versioned, updatable (below) |

## Mine

| Skill | Scope | What it does |
|-------|-------|--------------|
| `kb-setup` | KB | First run: interview, fill `1-me/` and the first work item, offer the personal kit |
| `kb-capture` | KB / global | End of session: state, log, decisions, learnings |
| `kb-decide` | KB / global | Record a decision as an ADR |
| `kb-intake` | KB | File `inbox/` material or a pasted doc |
| `kb-link-repo` | KB | Connect a code repo to its work item |
| `kb-tidy` | KB | Health check and fix-up |
| `kb-vet` | KB / global | Vet a skill, plugin or MCP server before installing it |
| <!-- yours --> | | |

## Writing one that actually gets used

- **The description decides everything.** Third person, what it does *and when*, using the words
  you'd type. "Drafts release notes from merged PRs. Use when asked for release notes or a
  changelog." Not "Helps with releases."
- Keep the body under about 500 lines. Put long reference material in files next to it, linked
  one level deep. Put deterministic steps in `scripts/`: scripts run without being read, so they cost no context.
- End with a check the agent can run.
- Test it: ask for the task three ways, in a fresh session. If it doesn't trigger, fix the description.
- Side effects (deploy, publish, send)? Add `disable-model-invocation: true`.

## Sharing with a team

Once two people copy the same skill, make it a plugin. A repo with
`.claude-plugin/marketplace.json` is a marketplace; colleagues run
`/plugin marketplace add <org>/<repo>` and `/plugin install <name>@<marketplace>`, and get
updates. Run `claude plugin validate` before you publish.
See [plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces).

## Before installing someone else's

Run `kb-vet` on it. A skill is instructions, and often scripts, that run with your permissions.
Sources worth starting from: [anthropics/skills](https://github.com/anthropics/skills),
[vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills). Vet those too.
