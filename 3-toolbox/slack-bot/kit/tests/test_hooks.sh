#!/bin/sh
# Every hook fed fake stdin JSON: allow and deny cases. No model, no Slack.
. "$(dirname "$0")/lib.sh"
mk_sandbox
RECEPTION_DIR=$RX
TARGET_REPO=$TARGET
export RECEPTION_DIR TARGET_REPO
SEND=mcp__claude_ai_Slack__slack_send_message
SIG="🤖 Tester's agent:"
FOOT="React 🔕 to stop me in this thread."

decision() { # hook json -> allow|deny
  _o=$(printf '%s' "$2" | "$KIT/hooks/$1")
  if [ -z "$_o" ]; then echo allow; return; fi
  printf '%s' "$_o" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}
ev() { # tool [input-json]
  jq -nc --arg t "$1" --argjson i "${2:-{\}}" '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: $i}'
}
send_ev() { # message [thread] [channel]
  ev "$SEND" "$(jq -nc --arg m "$1" --arg ts "${2:-1700000000.000100}" --arg ch "${3:-CTEST}" '{channel_id: $ch, thread_ts: $ts, message: $m}')"
}
expect() { # desc expected hook json
  _got=$(decision "$3" "$4")
  if [ "$_got" = "$2" ]; then ok "$1"; else bad "$1" "expected $2, got $_got"; fi
}

echo "watch-guard.sh"
export RECEPTION_PHASE=watch TRIGGER_QUERY='in:#test hasmy::robot_face: after:2026-10-03'
SEARCH=mcp__claude_ai_Slack__slack_search_public
expect "exact trigger query is allowed" allow watch-guard.sh "$(ev $SEARCH '{"query":"in:#test hasmy::robot_face: after:2026-10-03"}')"
expect "a different query is denied" deny watch-guard.sh "$(ev $SEARCH '{"query":"in:#general password"}')"
expect "query with an extra term is denied" deny watch-guard.sh "$(ev $SEARCH '{"query":"in:#test hasmy::robot_face: after:2026-10-03 OR from:me"}')"
expect "send while watching is denied" deny watch-guard.sh "$(send_ev "$SIG hi
$FOOT")"
expect "read thread while watching is denied" deny watch-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{}')"
unset TRIGGER_QUERY
expect "no TRIGGER_QUERY set: denied (fail closed)" deny watch-guard.sh "$(ev $SEARCH '{"query":"x"}')"
unset RECEPTION_PHASE
expect "outside the kit (no phase): no-op" allow watch-guard.sh "$(ev $SEARCH '{"query":"anything"}')"

echo "witness.sh"
export RECEPTION_PHASE=watch RECEPTION_TICK=t1
printf '%s' '{"tool_name":"'$SEARCH'","tool_input":{"query":"q"},"tool_response":{"messages":[{"ts":"1700000000.000100","text":"Bergen shows sunny"}]}}' | "$KIT/hooks/witness.sh"
check "watch: raw response appended to state/witness/<tick>.txt" grep -qF '1700000000.000100' "$RX/state/witness/t1.txt"
printf '%s' '{"tool_name":"'$SEARCH'","tool_response":"plain text 1700000000.000200"}' | "$KIT/hooks/witness.sh"
check "watch: string responses are kept raw too" grep -qF 'plain text 1700000000.000200' "$RX/state/witness/t1.txt"
claim c1 slack 1700000000.000100
export RECEPTION_PHASE=act RECEPTION_CLAIM=c1
printf '%s' '{"tool_name":"mcp__claude_ai_Slack__slack_get_reactions","tool_response":{"reactions":[{"name":"robot_face","users":["UOWNER"]}]}}' | "$KIT/hooks/witness.sh"
check "act: reactions response stored for the 🔕 check" grep -q robot_face "$RX/state/claims/c1/reactions.txt"
check "act: reactions timestamp stored" test -s "$RX/state/claims/c1/reactions.at"
unset RECEPTION_PHASE
rm -f "$RX/state/witness/t2.txt"
RECEPTION_TICK=t2
printf '%s' '{"tool_name":"x","tool_response":"y"}' | "$KIT/hooks/witness.sh"
check "outside the kit (no phase): writes nothing" test ! -f "$RX/state/witness/t2.txt"

echo "slack-guard.sh (slack thread c1, fresh reactions without 🔕)"
export RECEPTION_PHASE=act RECEPTION_CLAIM=c1
GOOD="$SIG The API returns Fahrenheit with ?units=fahrenheit, see src/weather_api/units.py:12.
$FOOT"
expect "signed, footer, right thread and channel: allowed" allow slack-guard.sh "$(send_ev "$GOOD")"
expect "wrong channel: denied" deny slack-guard.sh "$(send_ev "$GOOD" 1700000000.000100 CGENERAL)"
expect "another thread: denied" deny slack-guard.sh "$(send_ev "$GOOD" 1700000000.999999)"
expect "top-level post (no thread_ts): denied" deny slack-guard.sh "$(ev $SEND "$(jq -nc --arg m "$GOOD" '{channel_id: "CTEST", message: $m}')")"
expect "missing signature: denied" deny slack-guard.sh "$(send_ev "Here you go.
$FOOT")"
expect "missing 🔕 footer: denied" deny slack-guard.sh "$(send_ev "$SIG done")"
expect "mentions someone else: denied" deny slack-guard.sh "$(send_ev "$SIG ping <@U0OTHER>
$FOOT")"
expect "mentions only the owner: allowed" allow slack-guard.sh "$(send_ev "$SIG over to you <@UOWNER>
$FOOT")"
expect "<!here> broadcast: denied" deny slack-guard.sh "$(send_ev "$SIG <!here> look
$FOOT")"
expect "Slack token shape: denied" deny slack-guard.sh "$(send_ev "$SIG token xoxb-1234-abcd
$FOOT")"
expect "value from the target's .env: denied" deny slack-guard.sh "$(send_ev "$SIG it is supersecretvalue123
$FOOT")"
echo 'WEATHER_SOURCE=fixtures' >>"$TARGET/.env"
expect "non-secret .env value (WEATHER_SOURCE=fixtures): allowed" allow slack-guard.sh "$(send_ev "$SIG it reads the fixtures
$FOOT")"
printf '%s\n' "$GOOD" >"$RX/state/claims/c1/outgoing.txt"
expect "live send of exactly the approved reply: allowed" allow slack-guard.sh "$(send_ev "$GOOD")"
expect "live send that differs from the approved reply: denied" deny slack-guard.sh "$(send_ev "$SIG something else
$FOOT")"
rm -f "$RX/state/claims/c1/outgoing.txt"
expect "promise 'will be fixed': denied" deny slack-guard.sh "$(send_ev "$SIG this will be fixed soon
$FOOT")"
expect "promise 'tomorrow': denied" deny slack-guard.sh "$(send_ev "$SIG done by tomorrow
$FOOT")"
expect "'ETA': denied" deny slack-guard.sh "$(send_ev "$SIG ETA 2 days
$FOOT")"
expect "'beta' is not 'ETA': allowed" allow slack-guard.sh "$(send_ev "$SIG the beta endpoint works
$FOOT")"
expect "schedule_message: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_schedule_message '{"channel_id":"CTEST"}')"
expect "create_conversation (DM): denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_create_conversation '{"users":"U0OTHER"}')"
expect "canvas: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_create_update_canvas '{}')"
expect "search during act: denied" deny slack-guard.sh "$(ev $SEARCH '{"query":"x"}')"
expect "read the claimed thread: allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CTEST","message_ts":"1700000000.000100"}')"
expect "read another thread in our channel: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CTEST","message_ts":"1"}')"
expect "read thread in another channel: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CHR","thread_ts":"1"}')"
expect "add :eyes: on the claimed thread: allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","timestamp":"x","thread_ts":"1700000000.000100","name":"eyes"}')"
expect "add :white_check_mark: (answered): allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","thread_ts":"1700000000.000100","name":"white_check_mark"}')"
expect "add another emoji: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","thread_ts":"1700000000.000100","name":"thumbsup"}')"
echo "$(($(date +%s) - 120))" >"$RX/state/claims/c1/reactions.at"
expect "reactions check older than 60 s: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
date +%s >"$RX/state/claims/c1/reactions.at"
echo '{"reactions":[{"name":"no_bell","users":["U0ANYONE"]}]}' >"$RX/state/claims/c1/reactions.txt"
expect "someone reacted 🔕: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
rm -f "$RX/state/claims/c1/reactions.at"
expect "no reactions check at all: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
RECEPTION_PREFLIGHT=1 expect "work.sh preflight skips only the reactions freshness" allow slack-guard.sh "$(send_ev "$GOOD")"
RECEPTION_PREFLIGHT=1 expect "preflight still denies secrets" deny slack-guard.sh "$(send_ev "$SIG supersecretvalue123
$FOOT")"
unset RECEPTION_PREFLIGHT
RECEPTION_PHASE=triage
expect "send during triage: denied" deny slack-guard.sh "$(send_ev "$GOOD")"

echo "slack-guard.sh (inbox claim i1)"
claim i1 inbox
RECEPTION_PHASE=act RECEPTION_CLAIM=i1
IGOOD="$SIG answer
$FOOT"
expect "inbox: signed reply in its own thread: allowed" allow slack-guard.sh "$(send_ev "$IGOOD" i1)"
touch "$RX/inbox/i1.no_bell"
expect "inbox: inbox/<id>.no_bell exists: denied" deny slack-guard.sh "$(send_ev "$IGOOD" i1)"
RECEPTION_CLAIM=nope
expect "unknown claim: denied" deny slack-guard.sh "$(send_ev "$IGOOD" i1)"
unset RECEPTION_PHASE
expect "outside the kit (no phase): no-op" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_schedule_message '{}')"
check "every deny is logged in log/denies.log" test "$(grep -c DENY "$RX/log/denies.log")" -ge 20

rm -rf "$SB"
summary
