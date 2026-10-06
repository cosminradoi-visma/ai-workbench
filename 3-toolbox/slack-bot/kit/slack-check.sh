#!/bin/sh
# The 11:55 roll call. Headless, proves the three things the afternoon needs:
#   the Slack connector loads under claude -p, `hasmy::` search returns YOUR reaction, and sending in a thread is allowed.
#   1. React ✅ on Bogdan's pinned roll-call message first.
#   2. ./slack-check.sh   -> one Haiku search (exact query, witnessed), one Haiku post in that thread with your smoke line.
# Prints one JSON verdict (schema/verdict.json shape). Exit 0 = posted.
# [T] untested: everything here talks to the claude.ai Slack connector, which this build never called.
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
. "$KIT/lib/common.sh"
ROLLCALL_EMOJI=${ROLLCALL_EMOJI:-white_check_mark}

verdict() { # verdict notes reply
  jq -nc --arg v "$1" --arg n "$2" --arg r "${3:-}" \
    '{verdict: $v, reply: $r, failing_test: null, pr_title: null, pr_body: null, notes: $n}'
  [ "$1" = posted ]
  exit $?
}

if [ -x "$TARGET_REPO/scripts/smoke.sh" ]; then smoke=$("$TARGET_REPO/scripts/smoke.sh" 2>&1 | head -1); else smoke="no scripts/smoke.sh in $TARGET_REPO"; fi

# 1. find the roll-call message: same mechanics as a watch tick (exact query + witness).
TICK=rollcall-$(date +%Y%m%dT%H%M%S)-$$
TRIGGER_QUERY="in:#$CHANNEL_NAME hasmy::$ROLLCALL_EMOJI: after:$(yesterday)"
RECEPTION_PHASE=watch
RECEPTION_TICK=$TICK
export TRIGGER_QUERY RECEPTION_PHASE RECEPTION_TICK
out=$("$CLAUDE_BIN" -p "$(render "$KIT/prompts/watch.md" TRIGGER_QUERY "$TRIGGER_QUERY")" \
  --model "$WATCH_MODEL" --tools "" --allowedTools "$SLACK_SEARCH_TOOL" \
  --permission-mode dontAsk --permission-prompts none --max-turns 3 --max-budget-usd 0.05 \
  --no-session-persistence --output-format json --json-schema "$(cat "$KIT/schema/watch.json")" \
  --plugin-dir "$KIT" </dev/null 2>&1)
ts=$(printf '%s' "$out" | jq -r '.structured_output.hits[0].ts // empty' 2>/dev/null)
[ -n "$ts" ] || verdict failed "search: no message with your :$ROLLCALL_EMOJI: in #$CHANNEL_NAME ($(printf '%s' "$out" | jq -r '.subtype // "no output"' 2>/dev/null)). React first, or the connector/hasmy is not working." "$smoke"
grep -qF "$ts" "$STATE/witness/$TICK.txt" 2>/dev/null || verdict failed "search: hit $ts was not in Slack's raw response (witness)" "$smoke"

# 2. reply in that thread, through the same guard as the agent.
id=$(safe_id "rollcall-$ts")
mkdir -p "$STATE/claims/$id"
printf 'slack\n' >"$STATE/claims/$id/source"
printf '%s\n' "$ts" >"$STATE/claims/$id/ts"
text=$(printf '%s roll call: %s\n%s\n' "$SIGNATURE" "$smoke" "$FOOTER")
RECEPTION_PHASE=act
RECEPTION_CLAIM=$id
export RECEPTION_PHASE RECEPTION_CLAIM
printf '%s\n' "$text" >"$STATE/claims/$id/outgoing.txt"
post=$("$CLAUDE_BIN" -p "$(render "$KIT/prompts/post.md" OWNER_NAME "$OWNER_NAME" CHANNEL_ID "$CHANNEL_ID" TS "$ts" MUTE "$MUTE" TEXT "$text" \
  SEND_TOOL "$SLACK_SEND_TOOL" REACTIONS_TOOL "$SLACK_REACTIONS_TOOL")" \
  --model "$WATCH_MODEL" --tools "" --allowedTools "$SLACK_REACTIONS_TOOL,$SLACK_SEND_TOOL" \
  --permission-mode dontAsk --permission-prompts none --max-turns 4 --max-budget-usd 0.10 \
  --no-session-persistence --output-format json --plugin-dir "$KIT" </dev/null 2>&1)
denied=$(printf '%s' "$post" | jq -r '[.permission_denials[]?.tool_name] | join(",")' 2>/dev/null)
[ -z "$denied" ] || verdict failed "send denied ($denied): org may set Slack send to ask, see /mcp; or see log/denies.log" "$smoke"
# Only a send that hooks/witness.sh saw succeed counts, not the model's word.
grep -q "$SLACK_SEND_TOOL" "$STATE/claims/$id/witness.log" 2>/dev/null || verdict failed "the post step did not send (muted, or the model stopped)" "$smoke"
verdict posted "replied in thread $ts" "$smoke"
