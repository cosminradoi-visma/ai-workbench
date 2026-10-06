#!/bin/sh
# Find your Slack member ID and your self-DM's channel ID, and write both into owner.env (SELF_DM=true).
# How: one headless run sends you ONE message ("W3 bot setup ...") with the Slack connector. The channel id is
# read from Slack's own tool result (stream-json), not from the model's words. Usage: find-self-dm.sh
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
ENVF=${OWNER_ENV:-$KIT/owner.env}
[ -f "$ENVF" ] || cp "$KIT/owner.env.example" "$ENVF"
SEND=${SLACK_SEND_TOOL:-mcp__claude_ai_Slack__slack_send_message}
SCHEMA='{"type":"object","properties":{"owner_id":{"type":"string","pattern":"^[UW][A-Z0-9]+$"}},"required":["owner_id"]}'
echo "Sending yourself one Slack message to find your DM (needs /mcp -> claude.ai Slack connected)..."
# --setting-sources project: your personal allow rules and hooks do not apply (the Slack connector still loads:
# checked 6 Oct on v2.1.288; claude.ai connectors connect after the init event, as deferred tools).
out=$(claude -p --setting-sources project "Send exactly one Slack message to yourself with $SEND. Use your own Slack user id as channel_id (the tool's description names the current user's id). Text: 'W3 bot setup: this DM is where your bot will answer you.' Then return that user id as owner_id." \
  --model haiku --tools "" --allowedTools "$SEND" --permission-mode dontAsk --permission-prompts none \
  --max-turns 4 --no-session-persistence --output-format stream-json --verbose --json-schema "$SCHEMA" </dev/null 2>/dev/null)
# Your user id: the channel_id the send call was made to (a DM to yourself is addressed to your own id).
oid=$(printf '%s\n' "$out" | jq -r --arg t "$SEND" 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name==$t) | .input.channel_id // empty' 2>/dev/null | grep -E '^[UW][A-Z0-9]+$' | head -1)
[ -n "$oid" ] || oid=$(printf '%s\n' "$out" | jq -r 'select(.type=="result") | .structured_output.owner_id // empty' 2>/dev/null | tail -1)
# The DM's id comes from Slack's tool result: message_context.channel_id (a D... id).
cid=$(printf '%s\n' "$out" | jq -r 'select(.type=="user") | .message.content[]? | select(.type=="tool_result") | .content | tostring' 2>/dev/null |
  grep -o 'channel_id[^A-Z]*D[A-Z0-9]*' | grep -o 'D[A-Z0-9]*$' | head -1)
if [ -z "$oid" ] || [ -z "$cid" ]; then
  echo "Could not find them (owner_id='$oid' channel_id='$cid'). Is the Slack connector connected in /mcp?" >&2
  exit 1
fi
set_kv() {
  if grep -q "^$1=" "$ENVF"; then sed -i.bak "s|^$1=.*|$1=$2|" "$ENVF" && rm -f "$ENVF.bak"
  else printf '%s=%s\n' "$1" "$2" >>"$ENVF"; fi
}
# Every connector except Slack goes on the deny list, so the bot's runs load only the Slack tools.
servers=$(printf '%s\n' "$out" | jq -r 'select(.type=="system" and .subtype=="init") | .mcp_servers[]?.name' 2>/dev/null)
# v2.1.288: claude.ai connectors connect after init, so init lists none. `claude mcp list` names them all.
[ -n "$servers" ] || servers=$(claude mcp list 2>/dev/null | sed -n 's/^\(claude\.ai [^:]*\): .*/\1/p; s/^\([A-Za-z0-9_.-]*\): .*/\1/p')
deny=$(printf '%s\n' "$servers" | grep -v '^$' | grep -vx 'claude.ai Slack' | sed -e 's/[.: ]/_/g' -e 's/^/mcp__/' | paste -sd, -)
set_kv MCP_DENY "$deny"
set_kv OWNER_ID "$oid"
set_kv CHANNEL_ID "$cid"
set_kv SELF_DM true
set_kv SOURCE slack
set_kv SLACK_SEARCH_TOOL mcp__claude_ai_Slack__slack_search_public_and_private
echo "owner.env: OWNER_ID=$oid CHANNEL_ID=$cid SELF_DM=true SOURCE=slack ($ENVF)"
echo "Check Slack: you should see 'W3 bot setup' in your DM with yourself."
