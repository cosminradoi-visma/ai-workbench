---
name: golden-run
description: Runs this repo's golden tasks (.claude/golden/*.md), each in a clean git worktree with a fresh headless agent, then the task's check, and reports pass count and cost. Use when asked to "run the golden tasks", "run the evals", or after changing AGENTS.md, a skill, a rule or the model.
disable-model-invocation: true
---

# golden-run

Golden tasks measure whether agents do good work here. You are the referee, not the player:
never do a task yourself, never edit a task's protected files, never touch the main checkout.

## For each `.claude/golden/*.md` (skip `README.md`; only names matching the user's filter, if given)

1. Read its front matter: `check:` (required), `protect:` (globs), `max_turns:` (default 15),
   `tools:` (default `Read,Edit,Write,Grep,Glob`). The body, minus `<!-- comments -->`, is the prompt.
   No `check:` or no prompt: report the task as FAIL "task needs a check and a prompt".
2. `git worktree add --detach <tmp>/golden-<name> HEAD`. Uncommitted changes are not in the run: say so once.
3. In that worktree: `claude -p "<prompt>" --output-format json --permission-mode acceptEdits --max-turns <n> --allowedTools "<tools>"`.
   From its JSON keep `result`, `total_cost_usd`, `num_turns`, `subtype`. Write `result` to `.golden-output.txt` there.
4. `git status --porcelain` there, ignoring `.golden-output.txt` and caches (`__pycache__`, `node_modules`,
   `.pytest_cache`, `.venv`). Any changed file matching `protect:` → FAIL "edited protected file(s)".
5. Otherwise run `check:` there. Exit 0 = pass; else FAIL with the last line of its output.
6. `git worktree remove --force` it, unless the user said keep.

## Report

A table: task · pass/FAIL · turns · cost · why. Then `N/M passed · $total · $ per pass`.
It costs real tokens: confirm before running more than three tasks.
