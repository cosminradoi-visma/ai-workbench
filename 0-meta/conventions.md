# Conventions

How to write and file pages. Agents need this to **write** here, not to read.

## The seven drawers, and where they live

Identity → `1-me/` · Memory → `NOW.md`, `2-work/*/state.md` + `log.md`, `4-know/` (systems, people, domain, playbooks, incidents), `1-me/learnings.md` · Rules → each repo's
`AGENTS.md` + `.claude/rules/` · Skills → `.claude/skills/` · Reach → MCP per repo (`.mcp.json`) or a CLI, register in `3-toolbox/mcp.md` ·
Guards → permissions, hooks, sandbox, `3-toolbox/safety.md` · Checks → repo tests, `.claude/golden/`, the `reviewer` agent.
When you add something, put it in its drawer. "Score my workbench" (`kb-score`) shows which drawers are empty.

## The layers

| Layer | Holds | Zone | Changes |
|-------|-------|------|---------|
| `1-me/` | True across all your work: profile, how you work, team, glossary, learnings | private | rarely |
| `2-work/` | One folder per project, area, product or repo; finished ones in `_archive/` | private | every session |
| `4-know/` | What outlives tasks: systems, people, domain concepts, playbooks, incidents | private | when you learn something |
| `3-toolbox/` | What you reuse: safety rules, tips, skills catalog, MCP, hooks, kits | **shareable** | when you adopt a tool |
| `0-meta/` | How the KB itself works | shareable | rarely |
| `inbox/` | Raw material to file; gitignored | never leaves the machine | constantly |

**Private** means it stays in your repo. **Shareable** means you can hand a page or a
skill to a colleague as it is. Keep shareable pages free of anything private, so
sharing never needs an edit.

Don't add top-level folders. Something that doesn't fit is a work item (it has a next step),
a `4-know/` page (it stays true after the work), or a note inside one.

## Which kind of page

Ask what the reader needs, then write only that kind on the page (after Diátaxis: don't mix them).

| The reader needs to… | Kind | Lives in |
|----------------------|------|----------|
| know where something stands, and what is next | state | `2-work/<item>/state.md` |
| know what happened, in order | log | `2-work/<item>/log.md` |
| understand why it is like this | decision · concept | `decisions/adr-NNN-*.md` · `4-know/domain/` |
| look up a fact: owner, dependency, environment | reference | `4-know/systems/`, `4-know/people/`, `1-me/glossary.md` |
| do a task, step by step | playbook | `4-know/playbooks/` (a skill, once an agent should run it) |
| not repeat a failure | incident · learning | `4-know/incidents/` · `1-me/learnings.md` |

## Projects, areas, archive

- A **project** ends. An **area** never does (on-call, a service you own, your team). Both are
  work items; set `kind:` on the card.
- When a project ends: write its three-line **Outcome** at the top of `state.md`, promote what
  lasts to `4-know/`, set `status: done`, move the folder to `2-work/_archive/`, take it out of
  `NOW.md`. Stale pages next to live ones mislead agents; archiving keeps them searchable but out of the way.

## Promote, don't bury

Logs are raw material. Knowledge is what you'd want next time. At the end of a session
(`kb-capture`), anything that will still be true after this task moves to its page:

- a system's trap or owner → `4-know/systems/<system>.md`
- what a term really means here → `4-know/domain/<concept>.md` (title = the claim)
- a procedure you just did twice → `4-know/playbooks/<task>.md`
- something that broke → `4-know/incidents/YYYY-MM-<slug>.md`
- how someone wants to work → `4-know/people/<name>.md`

The work item keeps a link, never a copy. `INDEX.md` gets one line for each new page.

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
2. `<item>/state.md` → enough to start; its card links the `4-know/` pages it touches.
3. `INDEX.md` and the folder indexes → one line per page, so the agent opens one page, not ten.

Only `NOW.md` and the profile load up front (about 650 tokens). `INDEX.md` and every `4-know/`
page load only when the task needs them, so a bigger knowledge base doesn't make the boot heavier.

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

- **The header**, on every page in `4-know/` (the templates have it):
  `type` (system, person, concept, playbook, incident) · `status` (draft, active, archived;
  incidents: open, closed) · `owner` (who keeps it true) · `updated` · `review` (monthly,
  quarterly, at-change: when `kb-tidy` asks "still true?") · `data` (verified against the source,
  assumed, or example). Then two lines: **Purpose** (the question it answers) and **Not here**
  (what belongs elsewhere, with the link).
- State pages and notes: `updated: YYYY-MM-DD`, and `verified:` naming what you checked it against.
- File names: lowercase, hyphens, named by the thing (`payments-api.md`, `ana-pop.md`). Incidents
  start with `YYYY-MM-`. No numbers below the top level, because they force renames.
  `_example-` pages are fictional; delete them once you have your own.
- One H1 per page. Answer first, reasoning after. Tables for anything compared.
- `[unverified]` inline on any claim not confirmed, with whom to confirm it.
- **Link, don't copy.** If two pages say the same thing, one will go stale.
- Every folder has a `README.md` listing every file in it, and `INDEX.md` has one line per page.
  An index line is the page's purpose, so the agent can choose without opening it.
- Maintainer notes go in `<!-- HTML comments -->`. Claude Code strips them before loading.

## Decisions (ADRs)

Record one when someone will ask "why is it like this?" in three months: a real choice
between alternatives, with a trade-off. Use `kb-decide`. Status stays `Proposed`
until the owner confirms it. Accepted ADRs are never rewritten; a new one supersedes them.

## Never in here

Secrets, tokens, connection strings, customer data, payroll or HR records, other
people's personal data. See `3-toolbox/safety.md`. `kb-tidy` looks for the
obvious cases, but it can't catch everything.
