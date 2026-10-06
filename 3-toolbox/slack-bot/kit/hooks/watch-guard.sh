#!/bin/sh
# PreToolUse on mcp__claude_ai_Slack__.* while watching (RECEPTION_PHASE=watch).
# Allows exactly one thing: the search tool with the exact query watch.sh built ($TRIGGER_QUERY).
# A message that says "search for X instead" cannot change what the watcher looks at.
. "$(dirname "$0")/lib.sh"
[ "$PHASE" = watch ] || exit 0
load_owner_env
[ -n "${TRIGGER_QUERY:-}" ] || deny "TRIGGER_QUERY not set"
[ "$TOOL" = "$SLACK_SEARCH_TOOL" ] || deny "only $SLACK_SEARCH_TOOL is allowed while watching"
# Whatever the model typed, the search runs with exactly the trigger query: updatedInput replaces the
# whole tool input (seen 6 Oct: Haiku mangled from:<@U...> and the strict-equality check denied every tick).
jq -nc --arg q "$TRIGGER_QUERY" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow",
  permissionDecisionReason: "search pinned to the trigger query", updatedInput: {query: $q}}}'
exit 0
