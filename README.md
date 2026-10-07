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
| 1 | **Identity** | who it works for, and how they decide. For a bot: who may start it, and that anyone can stop it | `1-me/profile.md`, `how-i-work.md`; for a bot: `kit/owner.env` (owner) + `.claude/STOP` | every session (keep it short) |
| 2 | **Memory** | where things stand, what happened, what went wrong | `NOW.md`, `2-work/<item>/state.md` + `log.md`, `1-me/learnings.md` (a bot's per-message state is runtime data: in its own repo, gitignored) | two small pages, then on demand |
| 3 | **Rules** | how work is done in *this* repo | the repo's `AGENTS.md`; `.claude/rules/*.md` with `paths:` | every session there; scoped rules only when relevant |
| 4 | **Skills** | the procedures it can run | `.claude/skills/` (KB, repo, or `~/.claude/skills/`) | ~50 tokens each until used |
| 5 | **Reach** | which live systems it may touch, and how | MCP servers per repo, or a CLI; the register in `3-toolbox/mcp.md` | its tool names, every session |
| 6 | **Guards** | what it must never do | permissions, hooks, sandbox; the rules in `3-toolbox/safety.md` | zero: they run outside the model |
| 7 | **Checks** | whether its work is actually good | tests it can't edit, golden tasks (`.claude/golden/`), a fresh-eyes `reviewer` agent | only when you run them |

Around them: **the loop** (`kb-capture` after work, `kb-tidy` weekly) keeps the drawers true, and
**the toolbox** (`3-toolbox/`) is the shareable part: what you hand a colleague.

`sh kb report` shows which drawers your agents have, and what to do about the empty ones.

Claude's own auto-memory is a separate, private notebook it keeps for itself. It is useful, but it isn't a drawer you curate.

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

**Needs:** Claude Code and git. That's all.
- **Windows:** [Git for Windows](https://git-scm.com/download/win) (the per-user install works without admin). It gives
  Claude Code its Git Bash, and brings Perl, which runs the guards. WSL works too.
- **macOS:** `xcode-select --install` (git, Perl and Python in one go).
- **Linux:** git from your package manager. Perl is already there.
- **Python is optional.** The hooks and the check use Python 3.8+ if you have it, and their Perl twins if you don't.
  Same rules, same messages, tested against each other.
- **`gh` is optional.** It saves a few clicks; the web button does the same job.

Not sure? After cloning, run `sh kb doctor`: it lists what this laptop has and the exact fix for anything missing.

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
kb              one command for every laptop: sh kb check | report | doctor | test
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

With a slash, you type it. Without one, you just say it in plain words and the agent picks the skill.

| Skill | When |
|-------|------|
| `/kb-setup` | Once, first run |
| `/kb-link-repo` | Once per code repo |
| `kb-capture` | End of every meaningful session ("capture") |
| `kb-decide` | A real choice was made ("record this decision") |
| `kb-intake` | Something to file ("process my inbox") |
| `kb-tidy` | Weekly, or when the session-start check complains |
| `kb-vet` | Before installing any skill, plugin, hook or MCP server |

In each linked repo you also get a **`reviewer`** agent ("review this") and a **golden-tasks runner**
(`.claude/golden/`): drawer 7.

## Safety, in one breath

No secrets or restricted data in prompts or in this KB. Company accounts only. Read every diff:
you own what you merge. Vet before you install. Never combine private data, untrusted content
and a way out in one session. The full page is [`3-toolbox/safety.md`](3-toolbox/safety.md).

## Keep it healthy

`sh kb check` (inside Claude Code: `! sh kb check`) reports boot cost, broken links, stale or oversized pages,
missing indexes, likely secrets and hidden Unicode. It runs at every session start and prints only problems.
The same command works on every laptop, with or without Python. On Windows, run it in Git Bash or
through Claude Code (`! sh kb check`): plain PowerShell has no `sh`.

| Command | What it does |
|---------|--------------|
| `sh kb check` | the health check |
| `sh kb report` | your score out of seven drawers |
| `sh kb doctor` | what this laptop has, and how to fix what's missing |
| `sh kb test` | the hook tests, on every runtime this laptop has |

## Where it came from

It started as a much heavier, company-wide knowledge-base idea. We kept what worked and slimmed
it down to what one person and their agents actually need. [ADR-001](0-meta/decisions/adr-001-personal-workbench.md)
has what was kept, cut and added.
