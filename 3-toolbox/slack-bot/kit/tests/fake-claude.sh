#!/bin/sh
# Stand-in for `claude -p` in the offline tests. Logs its argv and answers from $FAKE_DIR:
#   RECEPTION_PHASE=triage -> runs $FAKE_DIR/triage.sh if present, prints $FAKE_DIR/triage.json
#   RECEPTION_PHASE=act    -> runs $FAKE_DIR/act.sh if present (simulated edits), prints $FAKE_DIR/act.json
#   no phase               -> install.sh self-test; FAKE_INSTALL=deny (default) or leak
: "${FAKE_DIR:?}"
phase=${RECEPTION_PHASE:-none}
n=$(find "$FAKE_DIR" -name 'call-*.log' | wc -l | tr -d ' ')
n=$((n + 1))
{
  printf 'phase=%s\ncwd=%s\n' "$phase" "$PWD"
  for a in "$@"; do printf 'arg=%s\n' "$a"; done
} >"$FAKE_DIR/call-$n.log"
echo "$phase" >>"$FAKE_DIR/phases.log"
case "$phase" in
  triage)
    [ -f "$FAKE_DIR/triage.sh" ] && sh "$FAKE_DIR/triage.sh"
    if [ -f "$FAKE_DIR/triage.first.json" ] && [ ! -f "$FAKE_DIR/triage.first.used" ]; then
      : >"$FAKE_DIR/triage.first.used"
      cat "$FAKE_DIR/triage.first.json"
    else
      cat "$FAKE_DIR/triage.json"
    fi
    ;;
  act)
    [ -f "$FAKE_DIR/act.sh" ] && sh "$FAKE_DIR/act.sh"
    cat "$FAKE_DIR/act.json"
    ;;
  *)
    case "${FAKE_INSTALL:-deny}" in
      deny) echo '{"type":"result","subtype":"success","total_cost_usd":0.01,"result":"DENIED, DENIED","permission_denials":[{"tool_name":"Read"},{"tool_name":"Read"},{"tool_name":"Bash"}]}' ;;
      leak) printf '{"type":"result","subtype":"success","total_cost_usd":0.01,"result":%s,"permission_denials":[]}\n' "$(cat .env.w3canary w3canary-secret.txt | jq -Rs .)" ;;
    esac
    ;;
esac
