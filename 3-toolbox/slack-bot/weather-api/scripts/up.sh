#!/bin/sh
# Start weather-api in the background on 127.0.0.1:$PORT (default 8077).
# Idempotent: if it is already up, say so and exit 0.
set -eu
cd "$(dirname "$0")/.."
PORT="${PORT:-8077}"
mkdir -p .run logs
if [ -f .run/api.pid ] && kill -0 "$(cat .run/api.pid)" 2>/dev/null; then
  echo "already up: pid $(cat .run/api.pid), http://127.0.0.1:$PORT"
  exit 0
fi
uv sync --quiet
nohup .venv/bin/uvicorn weather_api.app:app --app-dir src --host 127.0.0.1 --port "$PORT" >>logs/server.out 2>&1 &
echo $! >.run/api.pid
echo "$PORT" >.run/api.port
i=0
while [ "$i" -lt 40 ]; do
  if curl -fsS -m 1 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "up: pid $(cat .run/api.pid), http://127.0.0.1:$PORT"
    exit 0
  fi
  i=$((i + 1))
  sleep 0.25
done
echo "failed to start in 10 s, last lines of logs/server.out:"
tail -5 logs/server.out
exit 1
