#!/bin/sh
# PreToolUse on mcp__claude_ai_Slack__.* while watching (RECEPTION_PHASE=watch).
# Allows exactly one thing: the search tool with the exact query watch.sh built ($TRIGGER_QUERY).
# A message that says "search for X instead" cannot change what the watcher looks at.
. "$(dirname "$0")/lib.sh"
[ "$PHASE" = watch ] || exit 0
load_owner_env
[ -n "${TRIGGER_QUERY:-}" ] || deny "TRIGGER_QUERY not set"
[ "$TOOL" = "$SLACK_SEARCH_TOOL" ] || deny "only $SLACK_SEARCH_TOOL is allowed while watching"
# [T] untested: the search tool's argument name. "query" is assumed.
q=$(printf '%s' "$IN" | jq -r '.tool_input.query // ""')
[ "$q" = "$TRIGGER_QUERY" ] || deny "query must be exactly the trigger query"
exit 0
