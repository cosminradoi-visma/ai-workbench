#!/bin/sh
# Stand-in for `claude -p` in the offline tests. Logs its argv and answers from $FAKE_DIR:
#   RECEPTION_PHASE=triage -> runs $FAKE_DIR/triage.sh if present, prints $FAKE_DIR/triage.json
#   RECEPTION_PHASE=act    -> runs $FAKE_DIR/act.sh if present (simulated edits), prints $FAKE_DIR/act.json
#   no phase               -> install.sh self-test, in stream-json: one tool_use + tool_result per numbered call in
#                             the prompt ("<n>. Read tool: <path>" / "<n>. Bash: <cmd>").
#                             FAKE_INSTALL=deny (default, every call denied) | leak (calls run, values printed)
#                             | skip (the last call is never made) | output (git --output is allowed and writes)
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
    mode=${FAKE_INSTALL:-deny}
    prompt=""
    for a in "$@"; do case "$a" in "Self-test"*) prompt=$a ;; esac; done
    echo '{"type":"system","subtype":"init","mcp_servers":[]}'
    calls=$(printf '%s\n' "$prompt" | grep -E '^[0-9]+\. (Read tool|Bash): ')
    total=$(printf '%s\n' "$calls" | grep -c .)
    i=0
    printf '%s\n' "$calls" | while IFS= read -r line; do
      i=$((i + 1))
      [ "$mode" = skip ] && [ "$i" = "$total" ] && break
      kind=${line#*. }; kind=${kind%%:*}
      arg=${line#*: }
      if [ "$kind" = "Read tool" ]; then name=Read; input=$(jq -nc --arg p "$arg" '{file_path: $p}')
      else name=Bash; input=$(jq -nc --arg c "$arg" '{command: $c}'); fi
      err=true; content="Permission to use $name has been denied."
      case "$mode" in
        leak) err=false; if [ "$name" = Read ]; then content=$(cat "$arg" 2>&1); else content=$(sh -c "$arg" 2>&1); fi ;;
        output) case "$arg" in *--output=*) err=false; content=$(sh -c "$arg" 2>&1) ;; esac ;;
      esac
      jq -nc --arg id "t$i" --arg n "$name" --argjson in "$input" '{type: "assistant", message: {content: [{type: "tool_use", id: $id, name: $n, input: $in}]}}'
      jq -nc --arg id "t$i" --argjson e "$err" --arg c "$content" '{type: "user", message: {content: [{type: "tool_result", tool_use_id: $id, is_error: $e, content: $c}]}}'
    done
    echo '{"type":"result","subtype":"success","total_cost_usd":0.01,"result":"done"}'
    ;;
esac
