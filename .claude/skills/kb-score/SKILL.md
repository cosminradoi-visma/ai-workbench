---
name: kb-score
description: Scores the workbench out of seven drawers (Identity, Memory, Rules, Skills, Reach, Guards, Checks) and names the one step that fills the emptiest. Use when asked to "score my workbench", "how many drawers", or at the end of kb-tidy.
---

# kb-score

Read, don't guess: open the files below and judge each drawer **filled** (✓) or **empty** (·).
Placeholders (`<!-- -->`, `YYYY-MM-DD`, `TODO`) and `_example-` pages don't count.

| # | Drawer | Filled when |
|---|--------|-------------|
| 1 | Identity | `1-me/profile.md` has at least three real lines |
| 2 | Memory | `NOW.md` is dated within `stale_days` (`0-meta/kb.yaml`) and lists a real item whose `state.md` is current; count `4-know/` pages too |
| 3 | Rules | a linked repo (a `- Repo:` line on a card in `2-work/`) has an `AGENTS.md` |
| 4 | Skills | at least one skill of the owner's own (not `kb-*`) in `.claude/skills/`, `~/.claude/skills/` or a linked repo |
| 5 | Reach | `3-toolbox/mcp.md` registers a server, or a linked repo has `.mcp.json` |
| 6 | Guards | a linked repo's `.claude/settings.json` has `deny` rules, or `~/.claude/settings.json` does (the personal kit) |
| 7 | Checks | a linked repo has `.claude/agents/reviewer.md` or a real golden task in `.claude/golden/` |

Show it like this, then stop:

```
Your workbench: 4/7 drawers
  ✓ 1 Identity  profile: 5 lines
  ✓ 2 Memory    NOW.md current · 1 item · 3 pages in 4-know/
  · 4 Skills    none of your own yet  → copy 0-meta/templates/skill/
Next: <the one step that fills the emptiest drawer>
```

Linked repos outside the workbench need `/add-dir <path>` first; if you can't read one, say so
instead of scoring it empty.
