#!/bin/sh
# Stop weather-api if this checkout started it. Idempotent.
cd "$(dirname "$0")/.." || exit 1
if [ ! -f .run/api.pid ]; then
  echo "already down"
  exit 0
fi
pid=$(cat .run/api.pid)
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do i=$((i + 1)); sleep 0.25; done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid"
  echo "down: stopped pid $pid"
else
  echo "down: pid $pid was not running"
fi
rm -f .run/api.pid .run/api.port
