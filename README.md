# Workbench

**A private, organised workplace for your AI agents.** They start every session already knowing
who you are, what you're working on, what was decided and what went wrong last time,
without spending tokens exploring. Safe defaults included.

> Same models for everyone. Nobody else has your context. This is where it lives.

## The seven drawers

Everything an agent needs, in one organised place. Each drawer answers one question the agent
would otherwise guess at, or spend tokens finding out:

| # | Drawer | The agent needs to know… | Lives in | Costs |
|---|--------|--------------------------|----------|-------|
| 1 | **Identity** | who it works for, and how they decide. For a bot: who may start it, and that anyone can stop it | `1-me/profile.md`, `how-i-work.md`; for a bot: its owner setting | every session (keep it short) |
| 2 | **Memory** | where things stand, what happened, and what you know: systems, people, terms, how things are done, what broke | `NOW.md`, `2-work/<item>/state.md` + `log.md`, `4-know/`, `INDEX.md`, `1-me/learnings.md` | two small pages, then one page on demand |
| 3 | **Rules** | how work is done in *this* repo | the repo's `AGENTS.md`; `.claude/rules/*.md` with `paths:` | every session there; scoped rules only when relevant |
| 4 | **Skills** | the procedures it can run | `.claude/skills/` (KB, repo, or `~/.claude/skills/`) | ~50 tokens each until used |
| 5 | **Reach** | which live systems it may touch, and how | MCP servers per repo, or a CLI; the register in `3-toolbox/mcp.md` | its tool names, every session |
| 6 | **Guards** | what it must never do | permissions, hooks, sandbox; the rules in `3-toolbox/safety.md` | zero: they run outside the model |
| 7 | **Checks** | whether its work is actually good | tests it can't edit, golden tasks (`.claude/golden/`), a fresh-eyes `reviewer` agent | only when you run them |

Around them: **the loop** (`kb-capture` after work, `kb-tidy` weekly) keeps the drawers true, and
**the toolbox** (`3-toolbox/`) is the shareable part: what you hand a colleague.

Say "score my workbench" (`kb-score`) to see which drawers your agents have, and what to do about the empty ones.

Claude's own auto-memory is a separate, private notebook it keeps for itself. It is useful, but it isn't a drawer you curate.

## What you keep here

Most of a workbench is knowledge, not tooling. Five kinds of page outlive any one task, and each
has a template and a filled example (the fictional Orders API, all linked to each other):

| Page | One per | Example |
|------|---------|---------|
| **System** (`4-know/systems/`) | service, app, database you touch: owner, dependencies, environments, traps | [Orders API](4-know/systems/_example-orders-api.md) |
| **Person** (`4-know/people/`) | colleague you work with often: what they own, how to ask (work facts only) | [Ana](4-know/people/_example-ana.md) |
| **Concept** (`4-know/domain/`) | term that means something specific here, titled with the claim | [minor units](4-know/domain/_example-minor-units.md) |
| **Playbook** (`4-know/playbooks/`) | task you repeat: steps, and how you know it worked | [release](4-know/playbooks/_example-release-orders-api.md) |
| **Incident** (`4-know/incidents/`) | thing that broke: why, and what changed | [split-refund rounding](4-know/incidents/_example-2026-03-split-refund-rounding.md) |

Work lives in `2-work/`: **projects** end and move to `_archive/`, **areas** (on-call, a service you
own) never do. `INDEX.md` is the map, one line per page. Every page has the same short header:
type, status, owner, updated, when to review, and whether it is verified or assumed.

**The rule that makes it grow: promote, don't bury.** A log line is gone in a month. When
`kb-capture` finds something that will still be true after the task (a system's trap, who signs
off, what a term really means), it moves it to its page and links it from the work item.
`kb-tidy` then asks, page by page, whether it is still true. The ideas come from PARA, Diátaxis,
evergreen notes and Karpathy's LLM wiki; [ADR-005](0-meta/decisions/adr-005-knowledge-layer.md) has the reasoning and sources.

## Why it is built like this

- **Context files make agents faster and cheaper, not smarter.** One study found an AGENTS.md cut
  runtime by 29% and output tokens by 17%. Others found no gain in correctness, and that repo
  overviews didn't help. So this KB stays short, specific and current. It doesn't try to be complete.
- **More context makes agents worse.** Every model tested degrades as input grows. So only
  about 1,000 tokens load up front, and everything else is one hop away behind an index.
- **The usual failure is staleness.** Half of all AGENTS.md files are never updated. So there is a
  two-minute capture habit (`kb-capture`) and a check that flags stale pages.
- **Prompts are advice; settings are guarantees.** So the safety rules that must hold are permission
  rules Claude Code enforces, and two prompt hooks catch what a pattern can't. Nothing to run (ADR-006).

Sources: [`0-meta/decisions/research.md`](0-meta/decisions/research.md).

## Set it up (about 15 minutes)

**Needs:** Claude Code and git. Nothing else: the workbench is markdown and Claude Code settings,
with **nothing to run**. No Python, no scripts, no installs. Windows: Git for Windows (the per-user
install works without admin). macOS: `xcode-select --install`. Linux: your package manager. `gh` is optional.

1. **Create your copy**, a **private** repo in your own account, cloned to `~/workbench`. Either:
   - on GitHub, **Use this template → Create a new repository → Private**, then
     ```bash
     git clone https://github.com/<you>/my-workbench.git ~/workbench
     ```
     (git asks you to sign in: on Windows a browser window opens; on macOS/Linux use a
     [personal access token](https://github.com/settings/tokens) as the password, or an SSH URL), or
   - with `gh` logged in (`gh auth status`):
     ```bash
     gh repo create my-workbench --private --template cosminradoi-visma/ai-workbench --clone
     mv my-workbench ~/workbench
     ```
2. **Open Claude Code there and type `/kb-setup`.** A short interview fills in your profile, your
   first work item and `NOW.md`, and offers safe personal defaults for `~/.claude/`.
3. **Connect your main repo:** from the workbench, type `/kb-link-repo` and give it the repo path.
4. **End your next working session with "capture".** That's the habit that makes it work.

Copilot, Cursor and Codex read `AGENTS.md`, so the KB works there too. The skills and hooks are Claude Code's.

## What's where

```
AGENTS.md       the boot file: under 60 lines, a router, not an encyclopedia
NOW.md          what's active, read first, under 40 lines
INDEX.md        the map: one line per page, opened on demand
1-me/           private: profile, how you work, team, glossary, learnings, brag doc
2-work/         private: one folder per project / area / product / repo (state, log, decisions); _archive/
4-know/         private: what outlives tasks: systems, people, domain, playbooks, incidents
3-toolbox/      shareable: safety, tips, skills, MCP, hooks, project kit, personal kit
0-meta/         how the KB works: conventions, templates, health check, decisions + research
inbox/          drop raw material here; gitignored, untrusted, filed by kb-intake
.claude/        the KB's skills, hooks and a path-scoped writing rule
```

## The loop

```
  start                     work                       end
  NOW.md → state.md   →   agent works with context  →   kb-capture: state, log, decisions,
  (~700 tokens)             opens 4-know/ pages            promote what lasts to 4-know/ (2 min)
                            hooks guard it                         ↑
                                                         weekly: kb-tidy, "still true?"
```

With a slash, you type it. Without one, you just say it in plain words and the agent picks the skill.

| Skill | When |
|-------|------|
| `/kb-setup` | Once, first run |
| `/kb-link-repo` | Once per code repo |
| `kb-capture` | End of every meaningful session ("capture") |
| `kb-decide` | A real choice was made ("record this decision") |
| `kb-intake` | Something to file ("process my inbox") |
| `kb-tidy` | Weekly: the checks, then "still true?" page by page |
| `kb-score` | "Score my workbench": seven drawers, and the next step |
| `kb-vet` | Before installing any skill, plugin, hook or MCP server |

In each linked repo you also get a **`reviewer`** agent ("review this") and a **golden-tasks runner**
(`.claude/golden/`, run with `/golden-run`): drawer 7.

## Safety, in one breath

No secrets or restricted data in prompts or in this KB. Company accounts only. Read every diff:
you own what you merge. Vet before you install. Never combine private data, untrusted content
and a way out in one session. The full page is [`3-toolbox/safety.md`](3-toolbox/safety.md).

## Keep it healthy

Say "tidy" (`kb-tidy`) once a week. The agent checks what a script used to: boot size, broken links,
missing index lines, stale or oversized pages, likely secrets, hidden Unicode. Then it reviews the
knowledge itself with you: pages due for review, contradictions, facts buried in logs, work to archive.
`/context` shows what loads before your first message ("Memory files"): keep it under 2,000 tokens.

## Where it came from

It started as a much heavier, company-wide knowledge-base idea. We kept what worked and slimmed
it down to what one person and their agents actually need. [ADR-001](0-meta/decisions/adr-001-personal-workbench.md)
has what was kept, cut and added.
