---
name: kb-setup
description: First-run setup of this workbench. Instead of an interview, the agent discovers how the owner works (their repos, their own git history, existing instruction files, an /insights report), proposes how to organise it, writes it after a yes, and ends with a workbench card. Run it by typing /kb-setup.
disable-model-invocation: true
---

# kb-setup

Goal: in about fifteen minutes, a workbench that already knows its owner, built mostly from what is
on their laptop, not from typing. You do the reading; they confirm. Short messages, no lectures.

## 0. Ask first, in one message

Say what you will and won't read, then ask two questions:

> I'll set this up by looking at how you already work. I'll read, only where you point me:
> your git repos (README, build and CI files, any AGENTS.md or CLAUDE.md, and **your own** git
> history), and an `/insights` report if you have one. I won't read
> secret files, source code beyond build files, or anything you exclude. Nothing is written until
> you say yes.
> 1. Which folder holds your code? Type `/add-dir <that folder>` so I may read it (Claude Code only
>    lets me outside the workbench when you add a folder). Not sure where? Say "find it".
> 2. Any repo with customer or personal data I should skip?

Also mention: typing `/insights` makes Claude Code write a report on how they use it (useful if they have
used Claude Code before); if they make one, ask for its path. Their `~/.claude/CLAUDE.md` is already loaded in
this session: use what it says, don't read it again. Confirm the workbench path (`pwd`) for step 4.

## 1. Discover (read-only)

"Find it": run one `find` for `.git` folders under the home folder, at most three levels deep, skipping
`node_modules`, `.cache`, `Library`, `AppData`, `go/pkg`, `.venv` (Claude Code asks them to allow it once). List what
you find with each repo's last commit date, let them pick up to five, and ask them to `/add-dir` the folder that
holds them. If a read is blocked, say which folder to add; never work around it. For each picked repo, read only:

- the README (first 80 lines), the build or manifest file (`package.json`, `*.csproj`, `pom.xml`,
  `pyproject.toml`, `go.mod`, `Makefile`), the CI file names, `CODEOWNERS`, and any `AGENTS.md`,
  `CLAUDE.md`, `.cursor/rules`, `.github/copilot-instructions.md`
- **their own** history only: `git -C <repo> log --author="$(git -C <repo> config user.email)" --since=90.days
  --date=format:'%a %H' --pretty='%ad|%s' --no-merges` (day, hour, subject; no diffs)
- `git -C <repo> branch --sort=-committerdate --format='%(refname:short) %(committerdate:relative)'`, top five

Plus the `/insights` report if they gave a path.

**Never** compute anything about other people: no commit counts per colleague, no "most active", no
rankings (never rank or monitor people). Colleagues appear only as names with what they own,
from `CODEOWNERS` or from what the owner tells you.

## 2. Show what you found, then propose

One short message: **What I found** (repos, stack, what they touched in the last 90 days and the last 14,
branches in flight, rules they already wrote down), then **How I'd organise it**:

- `1-me/profile.md`: role (a guess to confirm), stack, how to work with them (from their CLAUDE.md files, global and per repo)
- `1-me/how-i-work.md`: three or four habits, each with its evidence ("small commits, tests in the same
  commit"). Phrase them as habits worth keeping, never as a judgement.
- `2-work/`: one item per active repo or project (`kind:` repo or project); an **area** for anything ongoing
- `4-know/systems/`: one page per service, from its README and CI (owner from `CODEOWNERS`, or ask)
- `1-me/glossary.md`: acronyms and internal names from READMEs and repo names, each to confirm
- `NOW.md`: what moved in the last 14 days, and the branches in flight

Then ask at most three questions: what is wrong in this, what matters most this month, what is blocked.

## 3. Write it, after a yes

Copy templates from `0-meta/templates/`. Fill only what you found or were told; anything inferred and not
confirmed gets `[unverified]`. Every new page gets its line in the folder's `README.md` and in `INDEX.md`.
Set `owner:` in `0-meta/kb.yaml`, and `updated:` to today on every page you write.
If a repo is local, fill "How to work on it" in its `state.md` from the build and CI files. Don't copy code.

## 4. Examples and personal kit (ask first)

- Delete the fictional examples (`2-work/_example-orders-api/`, the `_example-*` pages in `4-know/`) and their
  lines in the indexes, `INDEX.md`, `1-me/glossary.md` and `NOW.md`?
- Offer `3-toolbox/personal-kit/`: merge `~/.claude/CLAUDE.md` and `~/.claude/settings.json` (show the diff,
  get a yes), and copy `kb-capture`, `kb-decide`, `kb-vet`, `interview`, `standup` and `wrap-up` to `~/.claude/skills/`,
  so they work from any repo.

## 5. The workbench card

End with a card built only from what you found, in a code block, at most 12 lines:

```
┌─ <Name>'s workbench ─────────────────────────────┐
  <role> · <stack>
  Works on    <items, most active first>
  Rhythm      busiest on <day>, around <hour>:00   (your own commits)
  Signature   "<the word your commit subjects start with most>"
  Knows now   <n> systems · <n> terms · <n> work items
  Drawers     <n>/7 filled (say "score my workbench")
└──────────────────────────────────────────────────┘
```

Then three lines, no more:
1. Type `/context`: the **Memory files** line is your boot cost. Post it.
2. `/clear`, then ask "Where am I, and what's next?" It should answer without exploring.
3. New to Claude Code? `/powerup` has two-minute lessons. Want this terminal to feel like yours? `/statusline`.

## Done when

`kb.yaml` has no TODO, `NOW.md` lists a real item, every new page has its index line, the card is shown,
and the owner has read their boot cost from `/context`.

## Don't

- Read secret files, private keys, or source beyond build and config files.
- Compute or write anything about colleagues' activity. Names and ownership only.
- Fill gaps with plausible guesses: leave the placeholder or write `[unverified]`.
- Write anything before the yes in step 3, or to `~/.claude/` without showing the change.
