# Shared by the hooks. Reads the hook's stdin JSON into $IN and loads owner.env.
KIT=$(cd "$(dirname "$0")/.." && pwd)
IN=$(cat)
TOOL=$(printf '%s' "$IN" | jq -r '.tool_name // ""')
PHASE=${RECEPTION_PHASE:-}

deny() {
  reason=$1
  mkdir -p "${RECEPTION_DIR:-$KIT}/log"
  printf '%s DENY %s phase=%s claim=%s tool=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$0")" \
    "$PHASE" "${RECEPTION_CLAIM:-}" "$TOOL" "$reason" >>"${RECEPTION_DIR:-$KIT}/log/denies.log"
  jq -n --arg r "$(basename "$0" .sh): $reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

load_owner_env() {
  # Fail closed: a phase is set but there is no config to check against.
  [ -n "${OWNER_ENV:-}" ] && [ -f "$OWNER_ENV" ] || deny "no owner.env (OWNER_ENV=${OWNER_ENV:-unset})"
  # shellcheck disable=SC1090
  set -a; . "$OWNER_ENV"; set +a
  SLACK_SEARCH_TOOL=${SLACK_SEARCH_TOOL:-mcp__claude_ai_Slack__slack_search_public}
  SLACK_SEND_TOOL=${SLACK_SEND_TOOL:-mcp__claude_ai_Slack__slack_send_message}
  SLACK_REACTIONS_TOOL=${SLACK_REACTIONS_TOOL:-mcp__claude_ai_Slack__slack_get_reactions}
  SLACK_ADD_REACTION_TOOL=${SLACK_ADD_REACTION_TOOL:-mcp__claude_ai_Slack__slack_add_reaction}
  SLACK_READ_THREAD_TOOL=${SLACK_READ_THREAD_TOOL:-mcp__claude_ai_Slack__slack_read_thread}
  MUTE=${MUTE:-no_bell}
  SIGNATURE=${SIGNATURE:-🤖 ${OWNER_NAME:-owner}\'s agent:}
  FOOTER="React 🔕 to stop me in this thread."
}
