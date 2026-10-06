# weather-api

The W2 weather MCP server, grown into a small HTTP service for the W3 workshop.
Offline by default: forecasts come from `data/fixtures/*.json`.
Set `WEATHER_SOURCE=open-meteo` for live data (needs network).

```sh
uv sync
uv run pytest -q
```

## Endpoints

| Endpoint | What |
|---|---|
| `GET /` | A small HTML forecast page |
| `GET /health` | `{"status": "ok", "source": "fixtures"}` |
| `GET /metrics` | Request and error counters |
| `GET /cities` | All cities we serve, sorted alphabetically |
| `GET /forecast?city=X&units=celsius\|fahrenheit` | Seven days: condition, umbrella advice, max/min temperature, precipitation |

Every request writes one JSON line to `logs/app.log`: `ts`, `path`, `city`, `status`, `ms`.

## Operate

See `AGENTS.md` (`## Operate`) and the `operate` skill in `.claude/skills/operate/`.
`scripts/up.sh`, `scripts/down.sh`, `scripts/status.sh`, `scripts/smoke.sh`.
