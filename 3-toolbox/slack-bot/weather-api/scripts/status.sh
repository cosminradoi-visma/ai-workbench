#!/bin/sh
# Is weather-api running? One line. Exit 0 if up, 1 if down.
cd "$(dirname "$0")/.." || exit 1
PORT="${PORT:-$(cat .run/api.port 2>/dev/null || echo 8077)}"
if [ -f .run/api.pid ] && kill -0 "$(cat .run/api.pid)" 2>/dev/null; then
  echo "up: pid $(cat .run/api.pid), http://127.0.0.1:$PORT, last request: $(tail -1 logs/app.log 2>/dev/null || echo none)"
  exit 0
fi
echo "down"
exit 1
