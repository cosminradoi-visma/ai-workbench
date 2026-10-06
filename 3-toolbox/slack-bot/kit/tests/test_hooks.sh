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

decision() { # hook json -> allow|deny. A deny is exit 2 with the reason on stderr (fail closed, no JSON needed).
  _o=$(printf '%s' "$2" | "$KIT/hooks/$1" 2>"$SB/hook.err")
  _rc=$?
  if [ "$_rc" -eq 2 ]; then [ -s "$SB/hook.err" ] && echo deny || echo "deny-without-reason"; return; fi
  [ "$_rc" -eq 0 ] || { echo "exit-$_rc"; return; }
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
# expect_send desc expected message [thread] [channel]: a live send of a reply the script approved (outgoing.txt =
# the message), so only the content rules decide.
expect_send() {
  printf '%s\n' "$3" >"$RX/state/claims/$RECEPTION_CLAIM/outgoing.txt"
  expect "$1" "$2" slack-guard.sh "$(send_ev "$3" "${4:-1700000000.000100}" "${5:-CTEST}")"
  rm -f "$RX/state/claims/$RECEPTION_CLAIM/outgoing.txt"
}

echo "watch-guard.sh"
export RECEPTION_PHASE=watch TRIGGER_QUERY='in:#test hasmy::robot_face: after:2026-10-03'
SEARCH=mcp__claude_ai_Slack__slack_search_public
expect "exact trigger query is allowed" allow watch-guard.sh "$(ev $SEARCH '{"query":"in:#test hasmy::robot_face: after:2026-10-03"}')"
# A different or mangled query is not denied: it is rewritten to exactly the trigger query (updatedInput).
pinned() { printf '%s' "$2" | "$KIT/hooks/watch-guard.sh" | jq -e --arg q "$TRIGGER_QUERY" '.hookSpecificOutput.permissionDecision == "allow" and .hookSpecificOutput.updatedInput == {query: $q}' >/dev/null && ok "$1" || bad "$1"; }
pinned "a different query is replaced by the trigger query" "$(ev $SEARCH '{"query":"in:#general password"}')"
pinned "a query with an extra term is replaced by the trigger query" "$(ev $SEARCH '{"query":"in:#test hasmy::robot_face: after:2026-10-03 OR from:me"}')"
pinned "filters/keywords instead of query are replaced too" "$(ev $SEARCH '{"filters":"in:#general","keywords":["token"]}')"
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
expect_send "signed, footer, right thread and channel: allowed" allow "$GOOD"
expect "no outgoing.txt (the script approved nothing): denied" deny slack-guard.sh "$(send_ev "$GOOD")"
expect_send "wrong channel: denied" deny "$GOOD" 1700000000.000100 CGENERAL
expect_send "another thread: denied" deny "$GOOD" 1700000000.999999
printf '%s\n' "$GOOD" >"$RX/state/claims/c1/outgoing.txt"
expect "top-level post (no thread_ts): denied" deny slack-guard.sh "$(ev $SEND "$(jq -nc --arg m "$GOOD" '{channel_id: "CTEST", message: $m}')")"
expect "top-level post with only message_ts: denied" deny slack-guard.sh "$(ev $SEND "$(jq -nc --arg m "$GOOD" '{channel_id: "CTEST", message_ts: "1700000000.000100", message: $m}')")"
expect "thread_ts right but message_ts another message: denied" deny slack-guard.sh "$(ev $SEND "$(jq -nc --arg m "$GOOD" '{channel_id: "CTEST", thread_ts: "1700000000.000100", message_ts: "1700000000.999999", message: $m}')")"
expect "reply_broadcast: true (also posts to the channel): denied" deny slack-guard.sh "$(ev $SEND "$(jq -nc --arg m "$GOOD" '{channel_id: "CTEST", thread_ts: "1700000000.000100", reply_broadcast: true, message: $m}')")"
rm -f "$RX/state/claims/c1/outgoing.txt"
expect_send "missing signature: denied" deny "Here you go.
$FOOT"
expect_send "missing 🔕 footer: denied" deny "$SIG done"
expect_send "mentions someone else: denied" deny "$SIG ping <@U0OTHER>
$FOOT"
expect_send "mentions only the owner: allowed" allow "$SIG over to you <@UOWNER>
$FOOT"
expect_send "<!here> broadcast: denied" deny "$SIG <!here> look
$FOOT"
expect_send "Slack token shape: denied" deny "$SIG token xoxb-1234-abcd
$FOOT"
AWSK=$(printf 'wJalrXUtnFEMI/K7MDENG/bPxRfiCY%s' 'EXAMPLEKEY')   # AWS's documented example key, split for the KB secret scan
expect_send "AWS secret access key (40 chars base64): denied" deny "$SIG the key is $AWSK
$FOOT"
expect_send "aws_secret_access_key label: denied" deny "$SIG aws_secret_access_key = abc
$FOOT"
expect_send "Slack webhook URL: denied" deny "$SIG post to https://hooks.slack.com/services/T000/B000/XXXX
$FOOT"
JWT=$(printf 'eyJhbGciOiJIUzI1NiJ9.%s.%s' 'eyJzdWIiOiIxMjM0NTY3ODkwIn0' 'dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U')
expect_send "JWT: denied" deny "$SIG token $JWT
$FOOT"
expect_send "a full 40-char git sha is not a secret: allowed" allow "$SIG since commit \`5ba168d0c3e9f1a2b4d6e8f0a1b2c3d4e5f60718\`
$FOOT"
expect_send "value from the target's .env: denied" deny "$SIG it is supersecretvalue123
$FOOT"
echo 'WEATHER_SOURCE=fixtures' >>"$TARGET/.env"
expect_send "non-secret .env value (WEATHER_SOURCE=fixtures): allowed" allow "$SIG it reads the fixtures
$FOOT"
printf '%s\n' "$GOOD" >"$RX/state/claims/c1/outgoing.txt"
expect "live send of exactly the approved reply: allowed" allow slack-guard.sh "$(send_ev "$GOOD")"
expect "live send that differs from the approved reply: denied" deny slack-guard.sh "$(send_ev "$SIG something else
$FOOT")"
rm -f "$RX/state/claims/c1/outgoing.txt"
expect_send "promise 'will be fixed': denied" deny "$SIG this will be fixed soon
$FOOT"
expect_send "promise 'tomorrow': denied" deny "$SIG done by tomorrow
$FOOT"
expect_send "'ETA': denied" deny "$SIG ETA 2 days
$FOOT"
expect_send "'beta' is not 'ETA': allowed" allow "$SIG the beta endpoint works
$FOOT"
expect "schedule_message: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_schedule_message '{"channel_id":"CTEST"}')"
expect "create_conversation (DM): denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_create_conversation '{"users":"U0OTHER"}')"
expect "canvas: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_create_update_canvas '{}')"
expect "search during act: denied" deny slack-guard.sh "$(ev $SEARCH '{"query":"x"}')"
expect "read the claimed thread: allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CTEST","message_ts":"1700000000.000100"}')"
expect "read another thread in our channel: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CTEST","message_ts":"1"}')"
expect "read: thread_ts ours but message_ts another: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CTEST","thread_ts":"1700000000.000100","message_ts":"1"}')"
expect "read thread in another channel: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_read_thread '{"channel_id":"CHR","thread_ts":"1"}')"
expect "add :eyes: on the claimed thread: allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","message_ts":"1700000000.000100","name":"eyes"}')"
expect "add :white_check_mark: (answered): allowed" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","thread_ts":"1700000000.000100","name":"white_check_mark"}')"
expect "add a reaction on another message (message_ts): denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","thread_ts":"1700000000.000100","message_ts":"1700000000.999999","name":"eyes"}')"
expect "add another emoji: denied" deny slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_add_reaction '{"channel_id":"CTEST","thread_ts":"1700000000.000100","name":"thumbsup"}')"
printf '%s\n' "$GOOD" >"$RX/state/claims/c1/outgoing.txt"
echo "$(($(date +%s) - 120))" >"$RX/state/claims/c1/reactions.at"
expect "reactions check older than 60 s: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
date +%s >"$RX/state/claims/c1/reactions.at"
echo '{"reactions":[{"name":"no_bell","users":["U0ANYONE"]}]}' >"$RX/state/claims/c1/reactions.txt"
expect "someone reacted 🔕: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
rm -f "$RX/state/claims/c1/reactions.at"
expect "no reactions check at all: denied" deny slack-guard.sh "$(send_ev "$GOOD")"
rm -f "$RX/state/claims/c1/outgoing.txt"
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
expect_send "inbox: signed reply in its own thread: allowed" allow "$IGOOD" i1
touch "$RX/inbox/i1.no_bell"
expect_send "inbox: inbox/<id>.no_bell exists: denied" deny "$IGOOD" i1
RECEPTION_CLAIM=nope
expect "unknown claim: denied" deny slack-guard.sh "$(send_ev "$IGOOD" i1)"
unset RECEPTION_PHASE
expect "outside the kit (no phase): no-op" allow slack-guard.sh "$(ev mcp__claude_ai_Slack__slack_schedule_message '{}')"
check "every deny is logged in log/denies.log" test "$(grep -c DENY "$RX/log/denies.log")" -ge 20

echo "fail closed without jq"
NOJQ=$SB/nojq
mkdir -p "$NOJQ"
for b in sh cat dirname basename date mkdir printf tr grep sed awk; do
  _p=$(command -v "$b" 2>/dev/null) && case "$_p" in /*) ln -sf "$_p" "$NOJQ/$b" ;; esac
done
nojq() { printf '%s' "$2" | PATH=$NOJQ RECEPTION_PHASE=$3 RECEPTION_CLAIM=c1 TRIGGER_QUERY=q "$NOJQ/sh" "$KIT/hooks/$1" >/dev/null 2>"$SB/nojq.err"; echo $?; }
check "slack-guard without jq: exit 2 (deny)" test "$(nojq slack-guard.sh "$(send_ev "$GOOD")" act)" -eq 2
check "slack-guard without jq: says why on stderr" grep -q "jq is not installed" "$SB/nojq.err"
check "watch-guard without jq: exit 2 (deny)" test "$(nojq watch-guard.sh "$(ev $SEARCH '{"query":"q"}')" watch)" -eq 2

echo "hooks.json"
check "hook commands quote \${CLAUDE_PLUGIN_ROOT} (paths with spaces)" sh -c "jq -r '.. | .command? // empty' '$KIT/hooks/hooks.json' | grep -v '\"\\\${CLAUDE_PLUGIN_ROOT}/' | grep -q . && exit 1 || exit 0"

echo "stop-guard.sh (every tool, mid-run)"
P=$RX/PAUSED S=$TARGET/.claude/STOP
stopg() { (cd "${2:-$TARGET}" && printf '%s' "$1" | sh "$KIT/hooks/stop-guard.sh" "$P" "$S" >/dev/null 2>"$SB/stop.err"); echo $?; }
check "no switch: any tool allowed (exit 0)" test "$(stopg "$(ev Read '{"file_path":"x"}')")" -eq 0
: >"$P"
check "PAUSED: Read is blocked (exit 2)" test "$(stopg "$(ev Read '{"file_path":"x"}')")" -eq 2
check "PAUSED: the reason is on stderr" grep -q "stopped: .*PAUSED" "$SB/stop.err"
check "PAUSED: an MCP tool is blocked too" test "$(stopg "$(ev $SEND '{}')")" -eq 2
rm -f "$P"; : >"$S"
check ".claude/STOP in the target repo: Bash is blocked" test "$(stopg "$(ev Bash '{"command":"ls"}')")" -eq 2
rm -f "$S"
git -C "$TARGET" worktree add -q --detach "$TARGET/.worktrees/w1" HEAD 2>/dev/null
mkdir -p "$SB/other/.claude"; git -C "$SB/other" init -q 2>/dev/null
P=$SB/none1 S=$SB/none2   # paths not passed: the hook must find the main repo from the worktree itself
: >"$TARGET/.claude/STOP"
check "cwd is a worktree, STOP in its main repo: blocked" test "$(stopg "$(ev Read '{}')" "$TARGET/.worktrees/w1")" -eq 2
rm -f "$TARGET/.claude/STOP"
check "cwd is a worktree, no STOP anywhere: allowed" test "$(stopg "$(ev Read '{}')" "$TARGET/.worktrees/w1")" -eq 0
: >"$SB/other/.claude/STOP"
check ".claude/STOP in the session's own checkout: blocked" test "$(stopg "$(ev Read '{}')" "$SB/other")" -eq 2
git -C "$TARGET" worktree remove --force "$TARGET/.worktrees/w1" 2>/dev/null

rm -rf "$SB"
summary
