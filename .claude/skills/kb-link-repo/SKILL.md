---
name: kb-link-repo
description: Connects a code repo to its workbench item. Writes AGENTS.md, CLAUDE.md and CLAUDE.local.md from the real build files, adds guards, a reviewer agent and golden tasks. Run it by typing /kb-link-repo.
disable-model-invocation: true
---

# kb-link-repo

You need the repo path and the workbench path. Ask for whichever is missing.

## Steps

1. **Read the repo cheaply:** README, the build or manifest file (`package.json`, `pom.xml`,
   `*.csproj`, `pyproject.toml`, `go.mod`, `Makefile`), CI config, any existing
   `CLAUDE.md` / `AGENTS.md` / `.cursor/rules` / `.github/copilot-instructions.md`.
   Don't read source beyond what you need for commands and the non-obvious conventions.
2. **Work item:** if `2-work/<name>/` doesn't exist, create it from the template (kind `repo`)
   and add it to `2-work/README.md` and `NOW.md`.
3. **`AGENTS.md`** from `3-toolbox/project-kit/AGENTS.md`: fill `## Operate` (keep that exact heading, the W3 bot
   reads it) from the build files;
   "proving a change works" from CI; conventions only if non-obvious. **No repo overview.**
   Under 100 lines. If one exists, **merge**: keep everything still true, show the diff, never
   overwrite. If other tools' instruction files exist, fold their content into `AGENTS.md` and
   leave a one-line pointer behind.
4. **`CLAUDE.md`, always:** `@AGENTS.md` plus the compaction line. Then ask: **will an agent run here unattended**
   (a bot, a schedule, CI)?
   - **No:** create `CLAUDE.local.md` from `CLAUDE.local.md.example`: the import of `2-work/<name>/state.md` with the
     real workbench path (replace `~/workbench` if it lives elsewhere). Make sure `CLAUDE.local.md` is in `.gitignore`.
   - **Yes:** **no `CLAUDE.local.md`** (it would feed your private workbench to every run). Copy
     `.claude/unattended.json.example` to `.claude/unattended.json` with the real paths and send tools, and add the
     "who may start it, anyone can stop it" lines to `AGENTS.md`.
5. **Guard rails:** copy `.claude/hooks/guard.py`, `prompt_guard.py`, `no_em_dash.py`, `py` and `rules/tests.md`; merge
   `gitattributes` into the repo's `.gitattributes` (hooks must stay LF on Windows). Merge
   `.claude/settings.json` (union of lists, keep existing hooks), and add the repo's test command to `permissions.allow`
   (e.g. `Bash(make test)`), so the reviewer can run it. Offer `pre-commit-config.yaml`.
6. **Checks (drawer 7):** copy `.claude/agents/reviewer.md` and `.claude/golden/` (runner, README, and the two examples as formats:
   `example.md` fails until you replace it).
   Offer to draft **three golden tasks** from recently fixed bugs (`git log --oneline -30`): each a small real job
   with a `check:` command that fails before the fix and passes after, and `protect:` on the tests. If the repo will run
   a bot, also copy the must-decline tasks from `3-toolbox/slack-bot/golden/`. Don't run
   them without asking; they cost tokens. Make sure the card has a `- Repo: \`<path>\`` line so `--report` sees the repo.
7. **MCP (optional):** ask which live systems the work needs. Propose a pinned, read-only `.mcp.json`
   and run `kb-vet` on each server. Skip if none.
8. **Prove it:** ask the user to open a fresh **interactive** `claude` in the repo, approve the one-time prompt for the
   external import (`CLAUDE.local.md` → the workbench), and ask "How do I test this, and what's next?". It should answer
   without exploring. Headless, the external import isn't loaded: add `--add-dir <workbench>` to `claude -p`.
9. **Commit `.claude/` (hooks, settings, agents, golden) before any bot or golden run:** they run in worktrees of
   `HEAD`, so uncommitted guards are simply absent there.
10. Tell the user what to commit (AGENTS.md, CLAUDE.md, .claude/) and what stays local (CLAUDE.local.md).

## Don't

- Commit or push. That's the user's call.
- Put personal paths or KB content in files the team commits.
