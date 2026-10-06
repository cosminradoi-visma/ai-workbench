#!/bin/sh
# One watcher tick. Run it from cron (*/1 9-18 * * 1-5) or by hand. Usage: watch.sh [--wait]
#   1. PAUSED?            -> exit, do nothing.
#   2. Not armed?         -> refuse (install.sh self-test must have passed for the current settings).
#   3. Find new messages:
#        SOURCE=inbox  every inbox/*.md not yet claimed and approved by the owner (reacted_by, default the owner)
#        SOURCE=slack  Haiku runs ONE exact `hasmy::` search; a hit counts only if its ts is in Slack's raw
#                      response (state/witness/<tick>.txt, written by hooks/witness.sh)   # [T] untested
#   4. Atomic claim: mkdir state/claims/<id>. Whoever gets the mkdir works it; nobody works it twice.
#   5. work.sh <id>  (background by default; --wait runs it in the foreground)
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
. "$KIT/lib/common.sh"
WAIT=0
[ "${1:-}" = --wait ] && WAIT=1
WORK_CMD=${WORK_CMD:-$KIT/work.sh}
TICK=$(date +%Y%m%dT%H%M%S)-$$

if [ -f "$RECEPTION_DIR/PAUSED" ]; then
  log "tick $TICK: PAUSED, nothing done"
  echo "paused ($RECEPTION_DIR/PAUSED exists)"
  exit 0
fi
if ! is_armed; then
  say "tick $TICK: NOT ARMED. Run install.sh: the secret-deny self-test must pass for the current .claude/settings.json"
  exit 3
fi

start_work() {
  unset RECEPTION_PHASE RECEPTION_TICK TRIGGER_QUERY
  if [ "$WAIT" = 1 ]; then
    "$WORK_CMD" "$1"
  else
    nohup "$WORK_CMD" "$1" >>"$LOGDIR/work-$1.log" 2>&1 &
  fi
}

claimed=0
case "$SOURCE" in
  inbox)
    for f in "$INBOX"/*.md; do
      [ -f "$f" ] || continue
      id=$(safe_id "$(basename "$f" .md)")
      [ -d "$STATE/claims/$id" ] && continue
      by=$(header "$f" reacted_by)
      by=${by:-$OWNER_ID}
      if [ "$by" != "$OWNER_ID" ]; then
        # Someone else's approval: stay silent. Log it once.
        if [ ! -f "$STATE/seen/$id" ]; then
          say "tick $TICK: $id ignored, approved by $by, not by the owner"
          : >"$STATE/seen/$id"
        fi
        continue
      fi
      mkdir "$STATE/claims/$id" 2>/dev/null || continue
      printf 'inbox\n' >"$STATE/claims/$id/source"
      printf '%s\n' "$id" >"$STATE/claims/$id/ts"
      printf '%s\n' "$f" >"$STATE/claims/$id/message_path"
      now >"$STATE/claims/$id/claimed_at"
      say "tick $TICK: claimed $id (inbox)"
      claimed=$((claimed + 1))
      start_work "$id"
    done
    ;;
  slack)
    # [T] untested: needs the claude.ai Slack connector under claude -p, hasmy:: passed through, tool names.
    TRIGGER_QUERY="in:<#$CHANNEL_ID> hasmy::$TRIGGER: after:$(yesterday)"   # in:<#ID> works for channels and DMs (tested 5 Oct)
    RECEPTION_PHASE=watch
    RECEPTION_TICK=$TICK
    export TRIGGER_QUERY RECEPTION_PHASE RECEPTION_TICK
    out=$("$CLAUDE_BIN" -p "$(render "$KIT/prompts/watch.md" TRIGGER_QUERY "$TRIGGER_QUERY")" \
      --model "$WATCH_MODEL" --tools "" --allowedTools "$SLACK_SEARCH_TOOL" \
      --permission-mode dontAsk --permission-prompts none --max-turns 5 --max-budget-usd "$WATCH_BUDGET_USD" \
      --no-session-persistence --output-format json --json-schema "$(cat "$KIT/schema/watch.json")" \
      --plugin-dir "$KIT" </dev/null 2>>"$LOGDIR/watch.err")
    printf '%s' "$out" | jq -c --arg t "$TICK" \
      '{tick: $t, subtype, cost: .total_cost_usd, hits: ((.structured_output.hits // []) | length)}' >>"$LOGDIR/watch.jsonl" 2>/dev/null
    # A tick that never reached Slack is not "no messages": say so (seen on 5 Oct, Haiku sometimes answers without searching).
    if [ ! -s "$STATE/witness/$TICK.txt" ]; then
      printf '%s tick %s: the watcher did not search Slack (no witness). Treat as a failed tick, not "no messages".\n' "$(now)" "$TICK" >>"$LOGDIR/alarm.log"
      say "tick $TICK: WARNING no search happened (see log/alarm.log)"
    fi
    for row in $(printf '%s' "$out" | jq -r '.structured_output.hits[]? | "\(.ts)|\(.channel)"' 2>/dev/null); do
      ts=${row%%|*}
      ch=${row#*|}
      if ! witnessed "$ts" "$STATE/witness/$TICK.txt"; then
        printf '%s tick %s: %s NOT-WITNESSED (the model named a message Slack did not return)\n' "$(now)" "$TICK" "$ts" >>"$LOGDIR/alarm.log"
        continue
      fi
      id=$(safe_id "$ts")
      [ -d "$STATE/claims/$id" ] && continue
      # The reacted message is the task (focus); its thread is where the agent reads and answers.
      parent=$(thread_of "$ts" "$STATE/witness/$TICK.txt")
      tdir="$STATE/threads/$(safe_id "$parent")"
      mkdir -p "$tdir"
      # One worker per thread at a time. A busy thread is retried next tick; a lock older than 30 min is stale.
      [ -n "$(find "$tdir/busy" -maxdepth 0 -mmin +30 2>/dev/null)" ] && rmdir "$tdir/busy" 2>/dev/null
      mkdir "$tdir/busy" 2>/dev/null || { log "tick $TICK: $ts waits, thread $parent is busy"; continue; }
      mkdir "$STATE/claims/$id" 2>/dev/null || { rmdir "$tdir/busy"; continue; }
      printf 'slack\n' >"$STATE/claims/$id/source"
      printf '%s\n' "$parent" >"$STATE/claims/$id/ts"
      printf '%s\n' "$ts" >"$STATE/claims/$id/focus"
      printf '%s\n' "$ch" >"$STATE/claims/$id/channel"
      now >"$STATE/claims/$id/claimed_at"
      say "tick $TICK: claimed $id (slack $ch)"
      claimed=$((claimed + 1))
      start_work "$id"
    done
    ;;
  *)
    say "tick $TICK: unknown SOURCE=$SOURCE (slack|inbox)"
    exit 2
    ;;
esac
log "tick $TICK: done, $claimed claimed"
echo "tick $TICK: $claimed claimed"
