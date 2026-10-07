# ADR-006: Nothing to run

**Date:** 2026-10-07 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** the owner, after trying the workbench on colleagues' laptops: "no python or anything to run in the kb"

## Context

The guards and the health check were scripts: Python, then Perl twins for laptops without Python,
a launcher, a test suite. About 2,500 lines of code in a knowledge base, which had to work on Windows,
macOS and Linux, and which every user would have to trust and review. The knowledge it was meant to
protect was a few hundred lines.

## Decision

The workbench contains only markdown and Claude Code settings. Nothing in it is executed.

- **Guards** are settings Claude Code enforces: permission `deny` / `ask` rules; one `"type": "prompt"` hook,
  where a small model checks prompts for secrets; and one line of `grep` inline in `settings.json` that keeps
  em-dashes out of prose. That line is the only thing that executes, and there is no file for it.
- **The health check** is the `kb-tidy` skill: the agent checks links, indexes, dates, sizes and likely secrets
  itself, and `/context` shows the boot cost. The score is `kb-score`.
- **Golden tasks** run through the `golden-run` skill, not a runner script.

## Why

- Nothing to install means nothing to break on a colleague's laptop, and nothing to review as code.
- Tested on Claude Code 2.1.292: deny rules block `cat .env` through Bash too and hold against a user
  "authorising" a force-push; the prompt hook stopped 3 of 3 fake tokens and let harmless prompts through.
- An em-dash prompt hook was tried first and let the dash through in half the runs (the agent also wrote
  through the shell). A pattern is exact, so the em-dash rule stayed a pattern: one line, inline.

## Rejected

- **Scripts with twins for every runtime:** worked, but turned a knowledge base into software to maintain.
- **No guards at all, rules in prose:** prose is advice; the deny rules are guarantees.

## Consequences

The prompt hook is a model's judgement: likely, not certain, and about a second per prompt. The em-dash line needs
`sh` and `grep` (Git for Windows brings them); without them it does nothing. When it blocks, the agent explains and
rewrites when asked. The mechanical
checks now cost a few agent turns once a week instead of running at every session start.
