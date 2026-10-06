"""One JSON line per request to logs/app.log (override with WEATHER_LOG)."""
import json
import os
from datetime import datetime, timezone
from pathlib import Path


def log_path() -> Path:
    return Path(os.environ.get("WEATHER_LOG", "logs/app.log"))


def log_request(path: str, city: str | None, status: int, ms: float) -> None:
    line = {
        "ts": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
        "path": path,
        "city": city,
        "status": status,
        "ms": ms,
    }
    target = log_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("a") as f:
        f.write(json.dumps(line) + "\n")
