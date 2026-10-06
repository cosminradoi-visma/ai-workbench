# <Repo name>

<!-- Loaded in every session in this repo, by Claude Code, Copilot, Cursor and Codex.
     Keep it under ~100 lines. Agents can read the code, so don't describe the repo.
     Write only what they would get WRONG without this file. Test each line:
     "would removing this cause a mistake?" If not, delete it.
     Delete these comments and any section with nothing real in it. -->

<!-- One sentence: what it does and who depends on it. -->

## Operate

<!-- How to run, check and debug this repo, one line each. Agents (and the W3 bot) read this
     section first, so keep the heading exactly "## Operate". Model: the weather-api practice repo. -->

- Install: `<!-- -->`
- Start / stop / status: `<!-- -->`
- Smoke: `<!-- one command, one line of output, exit 0 or 1 -->`
- Tests: `<!-- -->` · One area: `<!-- -->`
- Proving a change works: <!-- the check that actually catches regressions, e.g. "integration tests
  against the compose DB; unit tests mock the DB and miss SQL bugs" -->
- Logs: `<!-- where, and what one line looks like -->`
- Lint/format: `<!-- -->` (a hook runs this; you don't need to)

Never touch:
- <!-- e.g. `.env`, `.claude/`, generated/, main directly -->

## Non-obvious conventions

<!-- Only what a reviewer would reject and a newcomer wouldn't guess.
     e.g. "money is integer cents", "src/domain imports no framework code". -->

## Ask before

<!-- e.g. changing a public API, a DB migration, CI config, adding a dependency. -->

## Gotchas

<!-- Things that cost someone an hour. -->
