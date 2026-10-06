---
name: operate
description: Run, check and test weather-api. Verbs are up, down, status, smoke, test <scope>, new-test <case>. Use whenever the service must be running, must be proven working, or a test must be added.
argument-hint: "<verb> [scope|case]"
---

# operate

Call the scripts. Never retype what they do. Run from the repo root.

| Verb | Do | Done when |
|---|---|---|
| `up` | `scripts/up.sh` | prints `up:` or `already up:` |
| `down` | `scripts/down.sh` | prints `down` or `already down` |
| `status` | `scripts/status.sh` | one line, exit 0 up, 1 down |
| `smoke` | `scripts/smoke.sh` | `SMOKE PASS` (exit 0). It never starts the service: if it fails, run `status`, then `tail -5 logs/server.out` |
| `test <scope>` | `all`: `uv run pytest -q`. A file: `uv run pytest -q tests/test_<scope>.py`. Anything else: `uv run pytest -q -k <scope>` | last line shows `passed` and no `failed` |
| `new-test <case>` | Write ONE test for `<case>` in the matching `tests/test_<area>.py`. Run only that test. | see below |

## new-test, red before green

1. Write the test so it states the correct behaviour, not the current one.
2. Run it alone: `uv run pytest -q tests/test_<area>.py::<name>`. It must FAIL. Quote the failing assert line.
3. If it passes, the test does not catch the bug. Rewrite it. Do not touch code yet.
4. Fix the code, smallest change that makes sense.
5. Run it alone again: green. Then `test all`: green.
6. Report as `path::name`, red line, green line.

## Rules

- Stop what you started: if you ran `up`, run `down` before you finish.
- Never read `.env`. Never edit `.claude/`. Never push or merge.
