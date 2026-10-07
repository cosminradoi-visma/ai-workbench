# Conventions

How to write and file pages. Agents need this to **write** here, not to read.

## The seven drawers, and where they live

Identity → `1-me/` · Memory → `NOW.md`, `2-work/*/state.md` + `log.md`, `1-me/learnings.md` · Rules → each repo's
`AGENTS.md` + `.claude/rules/` · Skills → `.claude/skills/` · Reach → MCP per repo (`.mcp.json`) or a CLI, register in `3-toolbox/mcp.md` ·
Guards → permissions, hooks, sandbox, `3-toolbox/safety.md` · Checks → repo tests, `.claude/golden/`, the `reviewer` agent.
When you add something, put it in its drawer. `sh kb report` shows which drawers are empty.

## The layers

| Layer | Holds | Zone | Changes |
|-------|-------|------|---------|
| `1-me/` | True across all your work: profile, how you work, team, glossary, learnings | private | rarely |
| `2-work/` | One folder per product, project or repo | private | every session |
| `3-toolbox/` | What you reuse: safety rules, tips, skills catalog, MCP, hooks, kits | **shareable** | when you adopt a tool |
| `0-meta/` | How the KB itself works | shareable | rarely |
| `inbox/` | Raw material to file; gitignored | never leaves the machine | constantly |

**Private** means it stays in your repo. **Shareable** means you can hand a page or a
skill to a colleague as it is. Keep shareable pages free of anything private, so
sharing never needs an edit.

Don't add top-level folders. Something that doesn't fit is almost always a work
item, or a note inside one.

## A work item

```
2-work/<name>/
  README.md     the card: what, links, kind, status       rarely changes
  state.md      where it stands now (≤ 80 lines)          overwritten each session
  log.md        what happened, newest first               append only
  decisions/    README.md index + adr-NNN-<slug>.md       append, supersede, never rewrite
  notes/        designs, research, meeting notes          optional, indexed in README.md
```

`kind:` in the card is `product` (long-lived), `project` (time-bounded) or `repo` (a codebase).

**Why state and log are separate:** the page an agent reads first must stay short and
current. Mixing history into it is how state pages reach 60 KB and stop being read.

## The read path is the design

Agents pay for every token they open, and long contexts make them worse, not just
more expensive. Arrange pages so the common question is answered in two hops:

1. `NOW.md` → which item.
2. `<item>/state.md` → enough to start.
3. Indexes → one line per file, so the agent opens one note, not ten.

So **put the answer at the top**, keep first-read pages short, and push detail down
one level, but no deeper. Agents skim nested references badly.

## What to write and what to leave out

Agents can read code. They can't read your head. Write what they would get wrong:

- **Yes:** decisions and why, things deliberately not done, gotchas, who owns what,
  internal names, how a change is proven to work, what must never happen.
- **No:** repo overviews, file-by-file descriptions, language conventions the model
  already knows, anything a linter or formatter enforces. Research shows repo
  overviews don't help and add cost.
- **No:** time-sensitive claims without a date. Write "as of 2026-10-02", not "currently".

## Page format

- Frontmatter on state pages and notes: `updated: YYYY-MM-DD`. Optional
  `status: verified | assumed | draft`, and `verified:` naming what you checked it against.
- File names: lowercase, hyphens, descriptive. No numbers below the top level, because
  they force renames.
- One H1 per page. Answer first, reasoning after. Tables for anything compared.
- `[unverified]` inline on any claim not confirmed, with whom to confirm it.
- **Link, don't copy.** If two pages say the same thing, one will go stale.
- Every folder has a `README.md` listing every file in it.
- Maintainer notes go in `<!-- HTML comments -->`. Claude Code strips them before loading.

## Decisions (ADRs)

Record one when someone will ask "why is it like this?" in three months: a real choice
between alternatives, with a trade-off. Use `kb-decide`. Status stays `Proposed`
until the owner confirms it. Accepted ADRs are never rewritten; a new one supersedes them.

## Never in here

Secrets, tokens, connection strings, customer data, payroll or HR records, other
people's personal data. See `3-toolbox/safety.md`. The health check (`sh kb check`) scans for the
obvious cases, but it can't catch everything.
