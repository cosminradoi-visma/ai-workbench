# Shared setup for the kit scripts and hooks. Source it, don't run it.
# Needs: KIT set by the caller (the kit folder). POSIX sh + jq.

OWNER_ENV=${OWNER_ENV:-$KIT/owner.env}
if [ ! -f "$OWNER_ENV" ]; then
  echo "w3-reception-kit: no owner config at $OWNER_ENV (cp owner.env.example owner.env)" >&2
  exit 2
fi
OWNER_ENV="$(cd "$(dirname "$OWNER_ENV")" && pwd)/$(basename "$OWNER_ENV")"
ENV_DIR=$(dirname "$OWNER_ENV")

set -a
# shellcheck disable=SC1090
. "$OWNER_ENV"
set +a

# Resolve a path relative to the owner.env folder.
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) if [ -d "$ENV_DIR/$1" ]; then (cd "$ENV_DIR/$1" && pwd); else printf '%s\n' "$ENV_DIR/$1"; fi ;;
  esac
}

: "${OWNER_ID:?OWNER_ID missing in owner.env}"
OWNER_NAME=${OWNER_NAME:-owner}
SIGNATURE=${SIGNATURE:-🤖 $OWNER_NAME\'s agent:}
FOOTER="React 🔕 to stop me in this thread."
SOURCE=${SOURCE:-inbox}
TRIGGER=${TRIGGER:-robot_face}
MUTE=${MUTE:-no_bell}
ALLOW_PR=${ALLOW_PR:-false}
WATCH_MODEL=${WATCH_MODEL:-haiku}
WORK_MODEL=${WORK_MODEL:-opus}
TRIAGE_MODEL=${TRIAGE_MODEL:-$WORK_MODEL}
WORK_BUDGET_USD=${WORK_BUDGET_USD:-3}
WATCH_BUDGET_USD=${WATCH_BUDGET_USD:-0.05}
POST_BUDGET_USD=${POST_BUDGET_USD:-0.50}   # one "post this exact reply" run; every connector you have loads into it
CLAUDE_BIN=${CLAUDE_BIN:-claude}
TEST_CMD=${TEST_CMD:-uv run pytest -q}          # red/green: "$TEST_CMD <failing_test>"
TEST_ALL_CMD=${TEST_ALL_CMD:-uv run pytest -q}  # full suite on head
RED_EXIT_CODES=${RED_EXIT_CODES:-1}             # pytest: 1 = tests failed (2 = collection error, 5 = no tests)
DIFF_MAX_LINES=${DIFF_MAX_LINES:-200}
DIFF_MAX_FILES=${DIFF_MAX_FILES:-5}
SLACK_SEARCH_TOOL=${SLACK_SEARCH_TOOL:-mcp__claude_ai_Slack__slack_search_public}
SLACK_SEND_TOOL=${SLACK_SEND_TOOL:-mcp__claude_ai_Slack__slack_send_message}
SLACK_REACTIONS_TOOL=${SLACK_REACTIONS_TOOL:-mcp__claude_ai_Slack__slack_get_reactions}
SLACK_ADD_REACTION_TOOL=${SLACK_ADD_REACTION_TOOL:-mcp__claude_ai_Slack__slack_add_reaction}
SLACK_READ_THREAD_TOOL=${SLACK_READ_THREAD_TOOL:-mcp__claude_ai_Slack__slack_read_thread}
# SLACK_TRANSPORT: mcp = the claude.ai Slack connector, polled by watch.sh (the workshop default).
#                  app = your own Slack app: listen.sh gets reactions pushed over Socket Mode, the script talks to
#                        Slack with lib/slackapi.py, and the model gets no Slack tools at all.
SLACK_TRANSPORT=${SLACK_TRANSPORT:-mcp}
SLACK_KEYCHAIN_SERVICE=${SLACK_KEYCHAIN_SERVICE:-}                      # app only, macOS: Keychain items <service>.SLACK_APP_TOKEN / .SLACK_USER_TOKEN
SLACK_TOKEN_FILE=${SLACK_TOKEN_FILE:-$HOME/.config/w3-agent/slack.env}   # app only, fallback (Linux/VM): the same two lines, chmod 600
APP_CHANNELS=${APP_CHANNELS:-${CHANNEL_ID:-}}                           # app only: where a 🤖 counts (space-separated ids)
SLACKAPI=${SLACKAPI:-$KIT/lib/slackapi.py}

if [ -n "${RECEPTION_DIR:-}" ]; then RECEPTION_DIR=$(abspath "$RECEPTION_DIR"); else RECEPTION_DIR=$KIT; fi
[ -n "${TARGET_REPO:-}" ] && TARGET_REPO=$(abspath "$TARGET_REPO")
[ -n "${EXTRA_PROMPTS_DIR:-}" ] && EXTRA_PROMPTS_DIR=$(abspath "$EXTRA_PROMPTS_DIR")
[ -n "${MEMORY_FILE:-}" ] && MEMORY_FILE=$(abspath "$MEMORY_FILE")

INBOX=$RECEPTION_DIR/inbox
OUTBOX=$RECEPTION_DIR/outbox
STATE=$RECEPTION_DIR/state
LOGDIR=$RECEPTION_DIR/log
mkdir -p "$INBOX" "$OUTBOX" "$STATE/claims" "$STATE/witness" "$STATE/seen" "$LOGDIR" 2>/dev/null

export KIT OWNER_ENV RECEPTION_DIR TARGET_REPO SIGNATURE FOOTER MUTE OWNER_ID CHANNEL_ID SOURCE APP_CHANNELS SLACK_TOKEN_FILE SLACK_KEYCHAIN_SERVICE

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date +%s; }
log() { printf '%s %s\n' "$(now)" "$*" >>"$LOGDIR/reception.log"; }
say() { printf '%s\n' "$*"; log "$*"; }

# Portable checksum of a file (POSIX cksum).
sum_of() { cksum <"$1" | awk '{print $1}'; }

# Keep only safe characters for an id used as a directory name.
safe_id() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-80; }

# Float maths without bc.
fadd() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN { printf "%.4f", a + b }'; }
fsub() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN { d = a - b; if (d < 0) d = 0; printf "%.4f", d }'; }
fgt() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN { exit !(a > b) }'; }

# render FILE KEY VALUE [KEY VALUE ...]: replace {{KEY}} with VALUE, literally (no regex, no shell eval).
render() {
  _t=$(cat "$1")
  shift
  while [ $# -ge 2 ]; do
    _t=$(printf '%s' "$_t" | jq -Rrs --arg k "{{$1}}" --arg v "$2" 'split($k) | join($v)')
    shift 2
  done
  printf '%s\n' "$_t"
}

new_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then uuidgen | tr 'A-Z' 'a-z'
  elif [ -r /proc/sys/kernel/random/uuid ]; then cat /proc/sys/kernel/random/uuid
  else python3 -c 'import uuid; print(uuid.uuid4())'; fi
}

yesterday() { date -v-1d +%F 2>/dev/null || date -d yesterday +%F 2>/dev/null || python3 -c 'import datetime; print(datetime.date.today() - datetime.timedelta(days=1))'; }

# Value of KEY in an optional front-matter block (first line "---", closed by "---").
header() {
  awk -v k="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
    NR > 1 { i = index($0, ":"); if (i && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit } }' "$1"
}

# The message body without the front-matter block.
body_of() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { print }' "$1"
}

# Armed = install.sh self-test passed for the current target settings.
is_armed() {
  [ -f "$STATE/armed" ] && [ -f "$TARGET_REPO/.claude/settings.json" ] &&
    [ "$(cat "$STATE/armed")" = "$(sum_of "$TARGET_REPO/.claude/settings.json")" ]
}

# witnessed TS FILE: did Slack's raw search response (saved by hooks/witness.sh) return TS as a RESULT?
# Real connector format (tested 5 Oct): each hit has an unindented "Message_ts: <ts>" line; the
# surrounding "Context before/after" messages are indented. Only the unindented line counts, so the
# model cannot nominate a neighbouring message nobody reacted to. The JSON form is the local fake's.
witnessed() {
  [ -f "$2" ] || return 1
  sed -e 's/\\\\n/\n/g' -e 's/\\n/\n/g' "$2" | grep -qxF "Message_ts: $1" && return 0
  grep -qF "\"ts\": \"$1\"" "$2"
}

# thread_of TS FILE: the first message of TS's thread, read from the permalink of TS's own search RESULT
# (".../p<ts>?thread_ts=<first>&..."). A message that is not in a thread is its own thread. The script
# decides this from Slack's raw response, never the model.
thread_of() {
  _t=$(sed -e 's/\\\\n/\n/g' -e 's/\\n/\n/g' "$2" 2>/dev/null | awk -v ts="$1" '
    /^Message_ts: / { inres = ($2 == ts); next }
    inres && /^Permalink:/ { if (match($0, /thread_ts=[0-9]+\.[0-9]+/)) print substr($0, RSTART + 10, RLENGTH - 10); exit }
    /^---/ { inres = 0 }')
  printf '%s\n' "${_t:-$1}"
}
