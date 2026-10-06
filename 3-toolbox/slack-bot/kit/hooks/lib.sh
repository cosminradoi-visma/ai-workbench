# Shared by the hooks. Reads the hook's stdin JSON into $IN and loads owner.env.
# Fail closed: every deny is "reason on stderr, exit 2", which Claude Code treats as a block whatever the JSON
# parser or the hook's stdout does. A hook that needs jq and has none exits 2 too.
KIT=$(cd "$(dirname "$0")/.." && pwd)
IN=$(cat)
PHASE=${RECEPTION_PHASE:-}
TOOL=""

deny() {
  reason=$1
  mkdir -p "${RECEPTION_DIR:-$KIT}/log" 2>/dev/null
  printf '%s DENY %s phase=%s claim=%s tool=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$0")" \
    "$PHASE" "${RECEPTION_CLAIM:-}" "$TOOL" "$reason" >>"${RECEPTION_DIR:-$KIT}/log/denies.log" 2>/dev/null
  echo "$(basename "$0" .sh): $reason" >&2
  exit 2
}

# need_jq: call after the "is this hook active?" check. No jq = no way to read the tool input = deny.
need_jq() {
  command -v jq >/dev/null 2>&1 || deny "jq is not installed, so this hook cannot check the call (install jq)"
  TOOL=$(printf '%s' "$IN" | jq -r '.tool_name // ""' 2>/dev/null) || deny "unreadable hook input"
}

load_owner_env() {
  # Fail closed: a phase is set but there is no config to check against.
  [ -n "${OWNER_ENV:-}" ] && [ -f "$OWNER_ENV" ] || deny "no owner.env (OWNER_ENV=${OWNER_ENV:-unset})"
  set -a; eval "$(tr -d '\r' <"$OWNER_ENV")"; set +a   # CRLF-safe, like lib/common.sh
  SLACK_SEARCH_TOOL=${SLACK_SEARCH_TOOL:-mcp__claude_ai_Slack__slack_search_public}
  if [ "${SELF_DM:-false}" = true ]; then
    case "$SLACK_SEARCH_TOOL" in *_search_public) SLACK_SEARCH_TOOL=${SLACK_SEARCH_TOOL}_and_private ;; esac
  fi
  SLACK_SEND_TOOL=${SLACK_SEND_TOOL:-mcp__claude_ai_Slack__slack_send_message}
  SLACK_REACTIONS_TOOL=${SLACK_REACTIONS_TOOL:-mcp__claude_ai_Slack__slack_get_reactions}
  SLACK_ADD_REACTION_TOOL=${SLACK_ADD_REACTION_TOOL:-mcp__claude_ai_Slack__slack_add_reaction}
  SLACK_READ_THREAD_TOOL=${SLACK_READ_THREAD_TOOL:-mcp__claude_ai_Slack__slack_read_thread}
  MUTE=${MUTE:-no_bell}
  OWNER_NAME=${OWNER_NAME:-owner}
  SIGNATURE=${SIGNATURE:-🤖 $OWNER_NAME\'s agent:}
  FOOTER="React 🔕 to stop me in this thread."
}
