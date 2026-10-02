---
updated: 2026-10-02
verified: Claude Code 2.1.287 docs and changelog. Features move fast, so re-check anything that surprises you.
---

# Tips and tricks

The ones that pay back most, grouped by what they save. Claude Code first; the
equivalents for other tools are at the end.

## See what you're paying for

1. **`/context`** shows what is in the window right now: system prompt, CLAUDE.md, skills,
   MCP tools, conversation. Run it once in each repo; the surprises are usually MCP tools.
2. **`/usage`** (also `/cost`) shows usage and cache hits, broken down by skill, subagent and MCP server.
3. **Put context use in your status line.** `personal-kit/statusline.py` shows model, context %
   and session cost.
4. **`python3 0-meta/scripts/kb_check.py`** shows what your KB costs before you type anything.

## Keep the context clean

5. **`/clear` between unrelated tasks.** After two failed corrections, clear and re-ask
   with what you learned. A fresh session with a good prompt beats a long one full of wrong turns.
6. **`/compact focus on X`** to steer what survives compaction, or keep a "when compacting,
   preserve…" line in CLAUDE.md.
7. **`/btw <question>`** for a side question that never enters the conversation history.
8. **Esc Esc** (`/rewind`) undoes code and conversation to a checkpoint. "Summarize from here"
   compacts just the tail. Changes made through Bash aren't tracked.
9. **Imports don't save tokens.** `@file` loads at launch. To load something only when relevant,
   use a skill, or a `.claude/rules/*.md` file with `paths:`.

## Put knowledge where it's cheapest

10. **Prefer CLAUDE.md to /init output.** Delete every line the agent would get right anyway.
    Repo overviews measurably don't help.
11. **Path-scoped rules:** `.claude/rules/api.md` with `paths: ["src/api/**"]` loads only when
    those files are read. Good for "how we write controllers" without paying for it in every session.
12. **Write a skill the second time you explain something.** Its description costs ~50 tokens;
    the body loads only when used.
13. **`!` in a skill runs a command before the model sees it:** `` !`git diff --stat` `` puts
    the diff in the skill, no exploration needed.
14. **`disable-model-invocation: true`** on skills with side effects (deploy, release, commit),
    so they only run when you type `/name`.
15. **Prefer a CLI to an MCP server** when one exists (`gh`, `az`, `kubectl`). Fewer tokens,
    better known to the model. Disable idle servers with `/mcp`.

## Get it right first time

16. **Give it a way to check its work:** a test command, a script, a URL to screenshot.
    The single biggest quality lever.
17. **Explore → plan → code.** Shift+Tab into plan mode for anything multi-file; read the
    plan before saying go.
18. **A second agent with fresh eyes** catches what the first one rationalised:
    `/code-review`, or a reviewer subagent that hasn't seen the conversation.
19. **A Stop hook that runs the tests** keeps it working until they pass. Check
    `stop_hook_active` in the input to avoid an endless loop.
20. **A formatter hook** (PostToolUse on `Edit|Write`) means the model never spends a turn on formatting.

## Go faster

21. **Parallel work:** `claude --worktree <name>` gives each session its own checkout.
22. **Cheap subagents:** send log-reading and test-running to a subagent on `haiku`.
    Only the summary comes back.
23. **Don't switch model or effort mid-task.** Each switch starts a cold cache. Pick at the start.
24. **Headless for CI and scripts:** `claude -p "…" --bare --output-format json --max-turns 5
    --allowedTools "Read,Grep"`. `--bare` skips hooks, skills, MCP and CLAUDE.md, which is
    what you want on untrusted input. The JSON includes `total_cost_usd`.
25. **Tell it to edit CLAUDE.md.** The old `#` shortcut is gone; "add to CLAUDE.md: …" does the same.

## Is it any good, and is it worth it?

26. **Keep five golden tasks per repo:** real, small, with a known right answer. Run them headless
    after you change CLAUDE.md, a skill or the model, and count passes. That's your eval.
27. **Judge with something the agent can't edit:** tests it didn't write, a reviewer subagent with
    fresh context, a human reading the diff. "The agent says the tests pass" is not evidence.
28. **Know the cost per task:** `/usage` in a session, `total_cost_usd` in headless JSON. If a task
    costs more than doing it yourself and isn't getting cheaper, stop delegating it.
29. **Not worth it when:** the task is a one-liner you'd type faster, the spec is in your head and nowhere
    else, or nothing can check the result.

## Unattended (CI, schedules)

30. **Headless needs a fence:** `--bare` (ignore repo config), `--max-turns`, an `--allowedTools`
    allowlist, a token with the least scope, and output that a human or a test checks before anything merges.
31. **Never `bypassPermissions` outside a throwaway container.** In CI the container is the boundary.
32. **Share a team's skills and hooks by committing them** (`.claude/` in the repo). For many repos, a plugin marketplace.

## Other tools

| | Instructions | Scoped rules | Skills | Hooks |
|-|-|-|-|-|
| Copilot | `AGENTS.md`, `.github/copilot-instructions.md` | `.github/instructions/*.instructions.md` with `applyTo` | `.github/skills`, `.claude/skills` | `.github/hooks/*.json` |
| Cursor | `AGENTS.md`, `.cursor/rules/*.mdc` | `globs:` in `.mdc` | `.cursor/skills`, `.claude/skills` [unverified] | `.cursor/hooks.json` |
| Codex | `AGENTS.md` (32 KiB cap) | nested `AGENTS.md` | `.agents/skills` | `.codex/hooks.json` [unverified] |

`AGENTS.md` is the shared format. Keep it the source and let each tool's file point to it.
