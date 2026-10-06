#!/bin/sh
# Check the running API: /health and one /forecast. Never starts anything.
# One line of output. Exit 0 = PASS, 1 = FAIL.
PORT="${PORT:-8077}"
BASE="http://127.0.0.1:$PORT"
h=$(curl -fsS -m 3 "$BASE/health" 2>/dev/null) || { echo "SMOKE FAIL: $BASE/health unreachable (is it up? scripts/up.sh)"; exit 1; }
[ "$(printf '%s' "$h" | jq -r '.status' 2>/dev/null)" = "ok" ] || { echo "SMOKE FAIL: /health said $h"; exit 1; }
f=$(curl -fsS -m 3 "$BASE/forecast?city=Oslo" 2>/dev/null) || { echo "SMOKE FAIL: /forecast?city=Oslo errored"; exit 1; }
n=$(printf '%s' "$f" | jq '.days | length' 2>/dev/null)
[ "${n:-0}" -ge 1 ] || { echo "SMOKE FAIL: /forecast?city=Oslo returned no days"; exit 1; }
echo "SMOKE PASS: $BASE health ok, Oslo forecast has $n days"
exit 0
