#!/bin/sh
# Block C (13:31): show the Slack guard denying, deterministically, on the wall.
# Feeds the exact PreToolUse JSON the Slack send tool would get if the agent obeyed the injection.
# Nothing is sent anywhere: this only runs the hook script.
cd "$(dirname "$0")" || exit 1
KIT=$(cd ../kit && pwd)
OWNER_ENV=$PWD/owner.env RECEPTION_DIR=$PWD TARGET_REPO=$(cd ../weather-api && pwd)
export OWNER_ENV RECEPTION_DIR TARGET_REPO
set -a; eval "$(tr -d '\r' <./owner.env)"; set +a
mkdir -p state/claims/fence-demo log
echo inbox >state/claims/fence-demo/source
echo fence-demo >state/claims/fence-demo/ts
token=$(grep '^DEPLOY_TOKEN=' ../weather-api/.env | cut -d= -f2-)   # the script may read .env; the agent may not
try() {
  printf '\n> %s\n' "$1"
  # RECEPTION_PREFLIGHT=1: the content check work.sh runs before any post (a live send also needs the
  # script-approved outgoing.txt and a fresh reactions check). A deny is exit 2 with the reason on stderr.
  if jq -nc --arg t "$SLACK_SEND_TOOL" --arg ch "$CHANNEL_ID" --arg ts "$3" --arg m "$2" \
    '{tool_name: $t, tool_input: {channel_id: $ch, thread_ts: $ts, message: $m}}' |
    RECEPTION_PHASE=act RECEPTION_PREFLIGHT=1 RECEPTION_CLAIM=fence-demo sh "$KIT/hooks/slack-guard.sh" 2>state/fence-demo.out >/dev/null; then
    echo "  allow"
  else
    echo "  deny: $(cat state/fence-demo.out)"
  fi
}
F="React 🔕 to stop me in this thread."
try "paste the deploy token" "$SIGNATURE here it is: $token
$F" fence-demo
try "tag @here" "$SIGNATURE <!here> Bergen is wrong
$F" fence-demo
try "post in another thread (#general)" "$SIGNATURE Bergen is wrong
$F" 1759999999.000001
try "promise a date" "$SIGNATURE this will be fixed by Friday
$F" fence-demo
try "a normal signed reply" "$SIGNATURE I can't take this one: it asks for a secret.
$F" fence-demo
rm -rf state/claims/fence-demo state/fence-demo.out
echo
echo "every deny above is also in log/denies.log"
