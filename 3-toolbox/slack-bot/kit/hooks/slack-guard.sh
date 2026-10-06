#!/bin/sh
# PreToolUse on mcp__claude_ai_Slack__.* while working on a claimed message (RECEPTION_PHASE=triage|act).
# work.sh also pipes every outbox reply through this same script (inbox lane), so one guard covers both lanes.
#
# Allowlist:
#   read thread / get reactions  triage+act, claimed channel only
#   add reaction                 act, claimed channel + thread, :eyes: only (the claim marker)
#   send message                 act only, and ALL of:
#     the script wrote state/claims/<id>/outgoing.txt and the text is exactly that (no file = no send),
#     channel = CHANNEL_ID, thread_ts = the claimed thread (and message_ts, if given, too), no reply_broadcast,
#     starts with SIGNATURE, ends with the 🔕 footer, no mentions except the owner, no broadcast mention,
#     no secrets (token shapes, AWS keys, Slack webhooks, JWTs, values from the repo's .env), no promise words,
#     🔕 check: slack = a reactions witness for this thread younger than 60 s that shows no :no_bell:;
#               inbox = no inbox/<id>.no_bell file
#   everything else (schedule, DM/create conversation, canvas, search, ...) is denied.
. "$(dirname "$0")/lib.sh"
case "$PHASE" in triage | act) ;; *) exit 0 ;; esac
need_jq
load_owner_env
DIR=${RECEPTION_DIR:-$KIT}
CLAIM=${RECEPTION_CLAIM:-}
[ -n "$CLAIM" ] && [ -d "$DIR/state/claims/$CLAIM" ] || deny "no claimed thread for this run"
C="$DIR/state/claims/$CLAIM"
CLAIM_TS=$(cat "$C/ts" 2>/dev/null)          # the thread's first message
CLAIM_FOCUS=$(cat "$C/focus" 2>/dev/null || printf '%s' "$CLAIM_TS")   # the message the owner reacted to
CLAIM_SOURCE=$(cat "$C/source" 2>/dev/null)

# [T] untested: argument names of the Slack connector tools. These are the assumed ones.
channel=$(printf '%s' "$IN" | jq -r '.tool_input.channel_id // .tool_input.channel // ""') || deny "unreadable tool input"
thread=$(printf '%s' "$IN" | jq -r '.tool_input.thread_ts // ""')   # a send must name the thread itself
# Every ts-like argument the call carries, one per line: each one must point at the claimed thread.
all_ts=$(printf '%s' "$IN" | jq -r '.tool_input | [.thread_ts, .message_ts, .ts, .timestamp] | map(select(. != null and . != "")) | .[] | tostring')
msg=$(printf '%s' "$IN" | jq -r '.tool_input.message // .tool_input.text // ""')
broadcast=$(printf '%s' "$IN" | jq -r '.tool_input.reply_broadcast // false | tostring')

check_channel() { # CHANNEL_ID, or one of APP_CHANNELS (app transport)
  [ -n "$channel" ] || deny "no channel given"
  case " $(printf '%s' "${APP_CHANNELS:-$CHANNEL_ID}" | tr ',' ' ') " in *" $channel "*) ;; *) deny "channel $channel is not $CHANNEL_ID" ;; esac
}
# check_ts: every ts argument (thread_ts AND message_ts AND ts) is the claimed thread or the reacted message.
check_ts() {
  [ -n "$all_ts" ] || deny "no thread_ts / message_ts given"
  for _t in $all_ts; do
    [ "$_t" = "$CLAIM_TS" ] || [ "$_t" = "$CLAIM_FOCUS" ] || deny "$1 ($CLAIM_TS), not $_t"
  done
}

case "$TOOL" in
  "$SLACK_READ_THREAD_TOOL" | "$SLACK_REACTIONS_TOOL")
    check_channel
    # Other Slack messages are data the owner did not approve: only the claimed thread may be read.
    check_ts "may only read the claimed thread"
    exit 0
    ;;
  "$SLACK_ADD_REACTION_TOOL")
    [ "$PHASE" = act ] || deny "reactions only in the act phase"
    check_channel
    check_ts "reaction outside the claimed thread"
    emoji=$(printf '%s' "$IN" | jq -r '.tool_input.name // .tool_input.emoji // .tool_input.reaction // ""')
    case "$emoji" in eyes | white_check_mark) ;; *) deny "only :eyes: (picked up) and :white_check_mark: (answered) may be added" ;; esac
    exit 0
    ;;
  "$SLACK_SEND_TOOL") ;;
  *) deny "tool not on the allowlist" ;;
esac

# ---- send message ----
[ "$PHASE" = act ] || deny "no posting during triage"
check_channel
[ -n "$CLAIM_TS" ] && [ "$thread" = "$CLAIM_TS" ] || deny "reply must go in the claimed thread ($CLAIM_TS), got '$thread'"
_mts=$(printf '%s' "$IN" | jq -r '.tool_input.message_ts // empty')
[ -z "$_mts" ] || [ "$_mts" = "$CLAIM_TS" ] || deny "message_ts $_mts is not the claimed thread"
[ "$broadcast" = false ] || deny "reply_broadcast would post the reply to the whole channel"

case "$msg" in "$SIGNATURE"*) ;; *) deny "missing signature '$SIGNATURE'" ;; esac
trimmed=$(printf '%s' "$msg" | sed -e 's/[[:space:]]*$//' | tail -1)
case "$trimmed" in *"$FOOTER" | *"$FOOTER"_) ;; *) deny "missing footer '$FOOTER'" ;; esac

# Live sends must be exactly the reply the script approved (work.sh writes it before the post run).
# No outgoing.txt = the script approved nothing = no send.
if [ "${RECEPTION_PREFLIGHT:-}" != 1 ]; then
  [ -f "$C/outgoing.txt" ] || deny "no reply approved by the script (state/claims/$CLAIM/outgoing.txt is missing)"
  want=$(cat "$C/outgoing.txt")
  [ "$(printf '%s' "$msg" | sed -e 's/[[:space:]]*$//')" = "$(printf '%s' "$want" | sed -e 's/[[:space:]]*$//')" ] ||
    deny "text differs from the reply the script approved (send it verbatim)"
fi

# Mentions: only the owner. No broadcasts.
others=$(printf '%s' "$msg" | grep -o '<@[A-Za-z0-9]*>' | grep -v "^<@$OWNER_ID>\$" | head -1)
[ -z "$others" ] || deny "mentions someone other than the owner ($others)"
printf '%s' "$msg" | grep -Eiq '<!(channel|here|everyone)>|(^|[^A-Za-z0-9])@(channel|here|everyone)([^A-Za-z0-9]|$)' && deny "broadcast mention"

# Secrets: common token shapes, plus every value in the target repo's .env files.
printf '%s' "$msg" | grep -Eq 'xox[abeprs]-[A-Za-z0-9-]+|xapp-[0-9]+-[A-Za-z0-9-]+|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-ant-[A-Za-z0-9_-]{10,}|(AKIA|ASIA)[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY' &&
  deny "looks like a secret token"
printf '%s' "$msg" | grep -Eiq 'hooks\.slack\.com/(services|workflows|triggers)/' && deny "looks like a Slack webhook URL"
printf '%s' "$msg" | grep -Eq 'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}' && deny "looks like a JWT"
printf '%s' "$msg" | grep -Eiq 'aws_?secret_?access_?key|secret_?access_?key["'"'"' ]*[:=]' && deny "looks like an AWS secret access key"
# An AWS secret key is 40 chars of base64. A git sha is 40 chars of hex, so: not all hex, and mixed case + a digit.
printf '%s' "$msg" | tr -c 'A-Za-z0-9/+=' '\n' | grep -Ex '[A-Za-z0-9/+]{40}' | grep -Evx '[0-9a-f]+' |
  grep '[A-Z]' | grep '[a-z]' | grep -q '[0-9]' && deny "looks like an AWS secret access key (40 chars of base64)"
if [ -n "${TARGET_REPO:-}" ]; then
  for envf in "$TARGET_REPO"/.env "$TARGET_REPO"/.env.*; do
    [ -f "$envf" ] || continue
    # The hook reads .env itself (the model cannot). A value counts as secret if its key looks secret
    # (KEY, TOKEN, SECRET, PASS, AUTH, CREDENTIAL, PRIVATE, DSN, COOKIE, SESSION) and it has 6+ chars,
    # or if it is 16+ chars whatever the key. So WEATHER_SOURCE=fixtures is not a secret.
    vals=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$envf" | awk -F= '{
      k = toupper($1); v = substr($0, index($0, "=") + 1); gsub(/^"|"$/, "", v)
      if ((k ~ /KEY|TOKEN|SECRET|PASS|PWD|AUTH|CREDENTIAL|PRIVATE|DSN|COOKIE|SESSION/ && length(v) >= 6) || length(v) >= 16) print v }')
    printf '%s\n' "$vals" | while IFS= read -r v; do
      [ -n "$v" ] && printf '%s' "$msg" | grep -qF -- "$v" && echo leak
    done | grep -q leak && deny "contains a value from $(basename "$envf")"
  done
fi

# No promises, no dates.
printf '%s' "$msg" | grep -Eiq '(^|[^A-Za-z])ETA([^A-Za-z]|$)|by (mon|tues|wednes|thurs|fri|satur|sun)day|tomorrow|next week|will be fixed|guarantee' &&
  deny "promise language (ETA, dates, 'will be fixed', 'guarantee')"

# 🔕: anyone can stop the agent in this thread.
if [ "$CLAIM_SOURCE" = inbox ]; then
  [ -f "$DIR/inbox/$CLAIM.$MUTE" ] && deny "thread muted (inbox/$CLAIM.$MUTE)"
elif [ "${RECEPTION_PREFLIGHT:-}" != 1 ]; then
  # Slack: checked by the real hook inside the post run, right after it fetched the reactions.
  # (work.sh's preflight check of the text runs before that fetch, so it skips only this part.)
  # [T] untested: reaction payload shape. We only grep the raw witness for the emoji name.
  [ -f "$C/reactions.at" ] || deny "no reactions check before sending (call $SLACK_REACTIONS_TOOL first)"
  age=$(($(date +%s) - $(cat "$C/reactions.at")))
  [ "$age" -le 60 ] || deny "reactions check is ${age}s old (max 60)"
  grep -q "$MUTE" "$C/reactions.txt" 2>/dev/null && deny "thread muted (:$MUTE:)"
fi
exit 0
