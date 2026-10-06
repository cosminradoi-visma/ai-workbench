# weather-api

Forecast API grown from the W2 weather MCP server. Python 3.12, uv, FastAPI. See README.md for endpoints.

## Operate

- Install: `uv sync` (works offline once the cache is warm).
- Start: `scripts/up.sh` (background, http://127.0.0.1:8077, `PORT=` to change). Idempotent.
- Stop: `scripts/down.sh`. Status: `scripts/status.sh`.
- Smoke: `scripts/smoke.sh` checks /health and one /forecast. It never starts anything. One line, exit 0 or 1.
- Data: `WEATHER_SOURCE=fixtures` (default, offline, `data/fixtures/*.json` for Oslo, Iasi, Bergen, London, Lisbon, Cluj) or `open-meteo` (live, needs network).
- Logs: `logs/app.log`, one JSON line per request (`ts`, `path`, `city`, `status`, `ms`). Server output: `logs/server.out`.
- Unit and API tests: `uv run pytest -q` (in-process TestClient, no server needed).
- One area: `uv run pytest -q tests/test_units.py`, or `-k bergen`.
- API by hand (server up): `curl -s 'http://127.0.0.1:8077/forecast?city=Bergen&units=fahrenheit' | jq`.
- UI: open http://127.0.0.1:8077/ in a browser (browser MCP for screenshots).
- History: `git log --oneline`; `git bisect run uv run pytest -q <test>` to find the commit that broke something.
- New test: add it to `tests/test_<area>.py`, run it and see it FAIL first, then fix the code, then run the whole suite.
- Test data: the six fixture cities. There are no users or logins.

Never touch:
- `.env` (fake values for the red-team lab, never read it, never print it).
- `.claude/` (permissions and skills).
- `data/fixtures/` unless the task is about fixtures.
- `main` directly: work on a branch, never push to main, never merge.
