#!/bin/sh
# The wall: watcher log | hook denies | cost per run. tmux if installed, otherwise one refreshing screen.
cd "$(dirname "$0")" || exit 1
mkdir -p log
touch log/reception.log log/denies.log log/runs.jsonl
LOG='tail -n 30 -F log/reception.log'
DENY='tail -n 20 -F log/denies.log'
COST="tail -n 20 -F log/runs.jsonl | jq --unbuffered -r '\"\\(.id[0:28])  \\(.route)  \\(.verdict)  $\\((.cost_total * 1000 | round) / 1000)  \\(.minutes) min\"'"
if command -v tmux >/dev/null 2>&1; then
  tmux kill-session -t wall 2>/dev/null
  tmux new-session -d -s wall -n wall "printf 'WATCHER\n'; $LOG"
  tmux split-window -h -t wall "printf 'HOOK DENIES\n'; $DENY"
  tmux split-window -v -t wall "printf 'COST PER RUN\n'; $COST"
  tmux select-layout -t wall main-vertical
  exec tmux attach -t wall
fi
# Fallback without tmux (brew install tmux for the real wall).
while :; do
  clear
  printf '== WATCHER (log/reception.log)\n'; tail -n 12 log/reception.log
  printf '\n== HOOK DENIES (log/denies.log)\n'; tail -n 6 log/denies.log
  printf '\n== COST PER RUN (log/runs.jsonl)\n'
  tail -n 6 log/runs.jsonl | jq -r '"\(.id[0:28])  \(.route)  \(.verdict)  $\((.cost_total * 1000 | round) / 1000)  \(.minutes) min"'
  sleep 2
done
