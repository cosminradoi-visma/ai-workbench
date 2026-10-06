#!/bin/sh
# PostToolUse on mcp__claude_ai_Slack__.*: keep the RAW tool_response, so scripts check what Slack
# actually returned instead of trusting what the model says it saw.
#   watch phase: append to state/witness/<tick>.txt (watch.sh greps hit ts values in it)
#   act phase:   reactions responses go to state/claims/<id>/reactions.txt + reactions.at (for the 🔕 check)
. "$(dirname "$0")/lib.sh"
[ -n "$PHASE" ] || exit 0
DIR=${RECEPTION_DIR:-$KIT}
raw=$(printf '%s' "$IN" | jq -r '.tool_response | if type == "string" then . else tojson end')
if [ "$PHASE" = watch ]; then
  mkdir -p "$DIR/state/witness"
  printf '%s\n' "$raw" >>"$DIR/state/witness/${RECEPTION_TICK:-unknown}.txt"
  exit 0
fi
if [ -n "${RECEPTION_CLAIM:-}" ] && [ -d "$DIR/state/claims/$RECEPTION_CLAIM" ]; then
  load_owner_env
  c="$DIR/state/claims/$RECEPTION_CLAIM"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TOOL" >>"$c/witness.log"
  if [ "$TOOL" = "$SLACK_REACTIONS_TOOL" ]; then
    printf '%s\n' "$raw" >"$c/reactions.txt"
    date +%s >"$c/reactions.at"
  fi
fi
exit 0
