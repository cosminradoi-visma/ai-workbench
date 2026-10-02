---
name: kb-link-repo
description: Connects a code repo to its workbench work item. Writes the repo's AGENTS.md, CLAUDE.md and CLAUDE.local.md from its real build files, adds the guard hooks and settings, and creates the work item if needed. Use when asked to "link this repo" or "set this repo up for agents".
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
3. **`AGENTS.md`** from `3-toolbox/project-kit/AGENTS.md`: commands from the build files;
   "proving a change works" from CI; conventions only if non-obvious. **No repo overview.**
   Under 100 lines. If one exists, **merge**: keep everything still true, show the diff, never
   overwrite. If other tools' instruction files exist, fold their content into `AGENTS.md` and
   leave a one-line pointer behind.
4. **`CLAUDE.md`:** `@AGENTS.md` plus the compaction line. **`CLAUDE.local.md`:** the import of
   `2-work/<name>/state.md` with the real workbench path. Make sure `CLAUDE.local.md` is in `.gitignore`.
5. **Guard rails:** copy `.claude/hooks/guard.py`, `prompt_guard.py`, `py` and `rules/tests.md`; merge
   `gitattributes` into the repo's `.gitattributes` (hooks must stay LF on Windows). Merge
   `.claude/settings.json` (union of lists, keep existing hooks). Offer `pre-commit-config.yaml`.
6. **MCP (optional):** ask which live systems the work needs. Propose a pinned, read-only `.mcp.json`
   and run `kb-vet` on each server. Skip if none.
7. **Prove it:** run `claude -p "What are the test and run commands here, and what's the next step on this item?" --max-turns 3`
   in the repo, or ask the user to open a fresh session and ask it. It should answer without exploring.
8. Tell the user what to commit (AGENTS.md, CLAUDE.md, .claude/) and what stays local (CLAUDE.local.md).

## Don't

- Commit or push. That's the user's call.
- Put personal paths or KB content in files the team commits.
