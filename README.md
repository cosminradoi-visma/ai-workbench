# Workbench

**A private knowledge base for your AI agents.** They start every session already knowing
who you are, what you're working on, what was decided and what went wrong last time,
without spending tokens exploring. Safe defaults included.

> Same models for everyone. Nobody else has your context. This is where it lives.

## Why it is built like this

- **Context files make agents faster and cheaper, not smarter.** One study found an AGENTS.md cut
  runtime by 29% and output tokens by 17%. Others found no gain in correctness, and that repo
  overviews didn't help. So this KB stays short, specific and current. It doesn't try to be complete.
- **More context makes agents worse.** Every model tested degrades as input grows. So only
  about 1,000 tokens load up front, and everything else is one hop away behind an index.
- **The usual failure is staleness.** Half of all AGENTS.md files are never updated. So there is a
  two-minute capture habit (`kb-capture`) and a check that flags stale pages.
- **Prompts are advice; settings and hooks are guarantees.** So the safety rules that must hold
  are enforced outside the model.

Sources: [`0-meta/decisions/research.md`](0-meta/decisions/research.md).

## Set it up (about 15 minutes)

1. **Create your copy:** "Use this template" → a **private** repo in your own account → clone it to `~/workbench`.
   ```bash
   gh repo create my-workbench --private --template cosminradoi-visma/ai-workbench --clone
   mv my-workbench ~/workbench
   ```
2. **Open Claude Code there and run `/kb-setup`.** A short interview fills in your profile, your
   first work item and `NOW.md`, and offers safe personal defaults for `~/.claude/`.
3. **Connect your main repo:** from the workbench, run `/kb-link-repo` and give it the repo path.
4. **End your next working session with "capture".** That's the habit that makes it work.

Needs: Claude Code, git, Python 3.8+ (for the hooks and the check). On Windows: WSL, or Git for Windows plus
Python from python.org. The Microsoft Store `python3` stub doesn't count; the launcher skips it.
Copilot, Cursor and Codex read `AGENTS.md`, so the KB works there too. The skills and hooks are Claude Code's.

## What's where

```
AGENTS.md       the boot file: under 60 lines, a router, not an encyclopedia
NOW.md          what's active, read first, under 40 lines
1-me/           private: profile, how you work, team, glossary, learnings
2-work/         private: one folder per product / project / repo (state, log, decisions)
3-toolbox/      shareable: safety, tips, skills, MCP, hooks, project kit, personal kit
0-meta/         how the KB works: conventions, templates, health check, decisions + research
inbox/          drop raw material here; gitignored, untrusted, filed by kb-intake
.claude/        the KB's skills, hooks and a path-scoped writing rule
```

## The loop

```
  start                     work                       end
  NOW.md → state.md   →   agent works with context  →   /kb-capture: state, log, decisions, learnings
  (~1k tokens)              hooks guard it               (2 min)          ↑
                                                                          weekly: /kb-tidy
```

| Skill | When |
|-------|------|
| `/kb-setup` | Once, first run |
| `/kb-link-repo` | Once per code repo |
| `kb-capture` | End of every meaningful session ("capture") |
| `kb-decide` | A real choice was made ("record this decision") |
| `kb-intake` | Something to file ("process my inbox") |
| `kb-tidy` | Weekly, or when the session-start check complains |
| `kb-vet` | Before installing any skill, plugin, hook or MCP server |

## Where does a thing go?

| It is… | Put it in | Costs |
|--------|-----------|-------|
| How agents work in **one repo** (commands, proof, conventions, boundaries) | that repo's `AGENTS.md` | every session there |
| Guidance for **one part** of a repo (tests, API layer) | `.claude/rules/x.md` with `paths:` | only when those files are read |
| Where a piece of work **stands** | `2-work/<item>/state.md` | when that item is touched |
| What **happened**, in order | `2-work/<item>/log.md` | on demand |
| **Why** something was decided | `2-work/<item>/decisions/` | on demand |
| A **procedure** you repeat | a skill | ~50 tokens until used |
| Something that must **always / never** happen | a hook or a permission rule | zero; runs outside the model |
| Access to a **live system** | an MCP server (or a CLI) | its tool names, every session |
| How **you** like to work | `1-me/profile.md` | every session |
| Claude's own notes to itself | its auto-memory, not here | first 200 lines |

## Safety, in one breath

No secrets or restricted data in prompts or in this KB. Company accounts only. Read every diff:
you own what you merge. Vet before you install. Never combine private data, untrusted content
and a way out in one session. The full page is [`3-toolbox/safety.md`](3-toolbox/safety.md).

## Keep it healthy

`python3 0-meta/scripts/kb_check.py` reports boot cost, broken links, stale or oversized pages,
missing indexes, likely secrets and hidden Unicode. It runs at every session start and prints only problems.

## Credits

Slimmed and reworked from ABQ Institute's [FACE](https://abq.institute/face) / EACF knowledge-base
templates. See [ADR-001](0-meta/decisions/adr-001-personal-workbench.md) for what was kept, cut and added.
