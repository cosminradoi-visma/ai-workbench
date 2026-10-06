#!/bin/sh
# work.sh end to end with a fake `claude` (tests/fake-claude.sh): routes, downgrades, the fix_pr gate
# (red on base, green on head, diff cap), the guard on the outbox, edited messages, mute, memory, extra routes.
. "$(dirname "$0")/lib.sh"

new_case() { # fresh sandbox + message
  [ -n "${SB:-}" ] && rm -rf "$SB"
  mk_sandbox
  cp "$KIT/tests/fixtures/inbox/${2:-fahrenheit-question.md}" "$RX/inbox/$1.md"
  claim "$1"
  ID=$1
}
work() { "$KIT/work.sh" "$ID" >"$SB/work.out" 2>&1; }
last_run() { tail -1 "$RX/log/runs.jsonl" | jq -r ".$1"; }
arg_of() { grep -A1 "^arg=$2\$" "$1" | tail -1 | sed 's/^arg=//'; } # value after a flag in a call log
FIX='printf '"'"'[ "$(cat lib/value.txt)" = 3 ]\n'"'"' >tests/test_value.sh; echo 3 >lib/value.txt'

echo "answer"
new_case a1
triage_json answer "README.md:1" "" "The value is in README.md."
act_json replied "Yes — README.md:1 says where the value lives (lines 1–2)."
work
check "outbox reply written" test -f "$RX/outbox/a1.md"
check "picked-up marker (:eyes:) written, no 'on it' text" grep -q ":eyes:" "$RX/outbox/a1.ack.md"
check "answered marker (:white_check_mark:) added after the reply" grep -q ":white_check_mark:" "$RX/outbox/a1.ack.md"
check "reply carries no cost or minutes" sh -c "! grep -qE '\\\$[0-9]|[0-9] min' '$RX/outbox/a1.md'"
check "reply header: signature and route in bold" sh -c "head -1 '$RX/outbox/a1.md' | grep -qF \"🤖 Tester's agent: **answer**\""
check "reply body after a blank line" sh -c "sed -n 3p '$RX/outbox/a1.md' | grep -q '^Yes'"
check "footer in italics" sh -c "tail -1 '$RX/outbox/a1.md' | grep -qxF '_React 🔕 to stop me in this thread._'"
check "reply ends with the 🔕 footer" sh -c "tail -1 '$RX/outbox/a1.md' | grep -qF 'React 🔕 to stop me in this thread.'"
T=$(calls_with triage)
A=$(calls_with act)
SID=$(cat "$RX/state/claims/a1/session")
check "triage runs with --session-id <pre-assigned uuid>" test "$(arg_of "$T" --session-id)" = "$SID"
check "act resumes the same session (--resume)" test "$(arg_of "$A" --resume)" = "$SID"
check "triage has no write tools" test "$(arg_of "$T" --tools)" = "Read,Grep,Glob,Bash,WebSearch"
check "triage cannot fetch URLs (WebFetch can carry data out)" test "$(arg_of "$T" --disallowedTools)" = "WebFetch"
check "answer act gets read tools and web search only" test "$(arg_of "$A" --tools)" = "Read,Grep,Glob,Bash,WebSearch"
check "runs happen in a worktree, not the owner's checkout" grep -q "^cwd=$TARGET/.worktrees/a1\$" "$T"
check "inbox lane drops all MCP servers (--strict-mcp-config)" grep -q '^arg=--strict-mcp-config$' "$T"
check "target settings passed explicitly (--settings)" test "$(arg_of "$T" --settings)" = "$TARGET/.claude/settings.json"
check "act budget = per-thread budget minus triage cost" test "$(arg_of "$A" --max-budget-usd)" = "0.9800"
check "no em-dashes or en-dashes reach the outbox" sh -c "! grep -q '[—–]' '$RX/outbox/a1.md'"
check "runs.jsonl: route answer, status sent" test "$(last_run route)/$(last_run status)" = "answer/sent"

echo "live logs"
new_case l1
mkdir -p "$TARGET/logs"
echo '{"path":"/forecast"}' >"$TARGET/logs/app.log"
triage_json answer "README.md:1" "" "README.md"
act_json replied "README.md"
work
check "the owner's live logs dir is added read-only (--add-dir)" test "$(arg_of "$(calls_with triage)" --add-dir)" = "$TARGET/logs"
check "triage prompt points at the live logs" grep -q "$TARGET/logs/ (the running service" "$(calls_with triage)"

echo "answer that cites nothing real"
new_case a2
triage_json answer "src/nowhere.py:3" "" "See src/nowhere.py."
act_json investigated "I looked."
work
check "downgraded to investigate" test "$(last_run route)" = investigate
check "investigate act gets Bash but no Edit/Write" test "$(arg_of "$(calls_with act)" --tools)" = "Read,Grep,Glob,Bash"

echo "fix_pr with ALLOW_PR=false"
new_case f0
echo 'ALLOW_PR=false' >>"$OWNER_ENV"
triage_json fix_pr "lib/value.txt:1" "tests/test_value.sh" "value is wrong"
act_json investigated "value is 2, expected 3"
work
check "downgraded to investigate" test "$(last_run route)" = investigate
check "no branch created" sh -c "! git -C '$TARGET' rev-parse --verify -q agent/f0 >/dev/null"

echo "fix_pr, real fix: red on base, green on head"
new_case f1
triage_json fix_pr "lib/value.txt:1" "tests/test_value.sh" "value is wrong"
act_json fixed "value was 2, now 3; tests/test_value.sh proves it" tests/test_value.sh
echo "$FIX" >"$FAKE_DIR/act.sh"
work
check "fix act gets Edit and Write" test "$(arg_of "$(calls_with act)" --tools)" = "Read,Grep,Glob,Bash,Edit,Write"
check "act cannot fetch, push, commit or call gh" test "$(arg_of "$(calls_with act)" --disallowedTools)" = "WebFetch,Bash(git push *),Bash(git commit *),Bash(gh *)"
check "PR body drafted in outbox" test -f "$RX/outbox/f1.pr.md"
check "PR body: red on base, by the script" grep -q "red on base .* exited 1" "$RX/outbox/f1.pr.md"
check "PR body: green on head" grep -q "green on head .* exited 0" "$RX/outbox/f1.pr.md"
check "PR footer carries claude --resume <session>" grep -qF "claude --resume $(cat "$RX/state/claims/f1/session")" "$RX/outbox/f1.pr.md"
check "branch agent/f1 has the commit" test "$(git -C "$TARGET" log -1 --format=%s agent/f1)" = "fix: value should be 3"
check "reply links the PR" grep -qF -- "- **PR:** outbox/f1.pr.md" "$RX/outbox/f1.md"
check "resume command in backticks" grep -qF -- "- **Resume:** \`claude --resume" "$RX/outbox/f1.md"
check "owner's main is untouched" test "$(git -C "$TARGET" rev-parse main)" = "$(cat "$RX/state/claims/f1/base")"
check "owner's working tree is clean" test -z "$(git -C "$TARGET" status --porcelain)"
check "runs.jsonl: route fix_pr, verdict fixed" test "$(last_run route)/$(last_run verdict)" = "fix_pr/fixed"

echo "fix_pr whose test is not red on base"
new_case f2
triage_json fix_pr "lib/value.txt:1" "tests/test_value.sh" "value is wrong"
act_json fixed "fixed" tests/test_value.sh
echo 'printf '"'"'[ "$(cat lib/value.txt)" = 2 ]\n'"'"' >tests/test_value.sh' >"$FAKE_DIR/act.sh"
work
check "gate fails: downgraded to investigate" test "$(last_run route)" = investigate
check "no PR body" test ! -f "$RX/outbox/f2.pr.md"
check "reply says no PR" grep -q "no PR" "$RX/outbox/f2.md"

echo "fix_pr over the diff cap"
new_case f3
echo 'DIFF_MAX_LINES=3' >>"$OWNER_ENV"
triage_json fix_pr "lib/value.txt:1" "tests/test_value.sh" "value is wrong"
act_json fixed "fixed" tests/test_value.sh
echo "$FIX; seq 1 50 >lib/noise.txt" >"$FAKE_DIR/act.sh"
work
check "diff over cap: downgraded, no PR" test "$(last_run route)" = investigate -a ! -f "$RX/outbox/f3.pr.md"
check "gate evidence names the cap" grep -q "cap 3 / 5" "$RX/state/claims/f3/gate.txt"

echo "reply that leaks a .env value"
new_case s1 injection.md
triage_json decline "README.md:1" "" "no"
act_json declined "Sure, the token is supersecretvalue123"
work
check "reply blocked by slack-guard, nothing in outbox" test ! -f "$RX/outbox/s1.md" -a -f "$RX/outbox/s1.blocked.md"
check "blocked note does not repeat the secret" sh -c "! grep -q supersecretvalue123 '$RX/outbox/s1.blocked.md'"
check "deny logged" grep -q "contains a value from .env" "$RX/log/denies.log"

echo "edited after approval"
new_case e1 edited-after-approval.md
work
check "declined by the script, no model call" test ! -f "$FAKE_DIR/phases.log"
check "reply asks the owner to re-approve" grep -q "re-approve" "$RX/outbox/e1.md"

echo "muted before work"
new_case m1
touch "$RX/inbox/m1.no_bell"
work
check "🔕: no model call, nothing in outbox" test ! -f "$FAKE_DIR/phases.log" -a ! -f "$RX/outbox/m1.md"

echo "muted between triage and act"
new_case m2
triage_json answer "README.md:1" "" "README.md"
echo "touch '$RX/inbox/m2.no_bell'" >"$FAKE_DIR/triage.sh"
work
check "🔕 after triage: act never runs" test "$(grep -c act "$FAKE_DIR/phases.log")" -eq 0
check "🔕 after triage: no reply" test ! -f "$RX/outbox/m2.md"

echo "PAUSED mid-flight"
new_case p1
triage_json answer "README.md:1" "" "README.md"
echo "touch '$RX/PAUSED'" >"$FAKE_DIR/triage.sh"
work
check "PAUSED after triage: act never runs" test "$(grep -c act "$FAKE_DIR/phases.log")" -eq 0

echo "triage fails (budget)"
new_case t1
echo '{"type":"result","subtype":"error_max_budget_usd","total_cost_usd":1.0}' >"$FAKE_DIR/triage.json"
work
check "escalates to the owner" grep -q "<@UOWNER>" "$RX/outbox/t1.md"
check "no act run" test "$(grep -c act "$FAKE_DIR/phases.log")" -eq 0

echo "showcase extras: extra route + memory"
new_case x1
mkdir -p "$SB/extra"
echo "Route: needs_info. Ask one question." >"$SB/extra/act-needs_info.md"
echo "- needs_info: one question, then stop." >"$SB/extra/routes.md"
echo '{"ts":"2026-09-29","id":"old","route":"fix_pr","summary":"Bergen sunny in rain","pr":"#14"}' >"$SB/memory.jsonl"
printf 'EXTRA_ROUTES="needs_info"\nEXTRA_PROMPTS_DIR=%s\nMEMORY_FILE=%s\n' "$SB/extra" "$SB/memory.jsonl" >>"$OWNER_ENV"
triage_json needs_info "README.md:1" "" "Which city?"
act_json replied "Which city and which day?"
work
T=$(calls_with triage)
check "router schema includes the extra route" sh -c "grep '^arg=' '$T' | grep -q 'needs_info'"
check "triage prompt includes thread memory" grep -q "Bergen sunny in rain" "$T"
check "triage prompt includes the extra route text" grep -q "one question, then stop" "$T"
check "extra route accepted and acted on" test "$(last_run route)" = needs_info
check "memory appended after the thread" test "$(wc -l <"$SB/memory.jsonl" | tr -d ' ')" -eq 2

echo "triage forgets its JSON once"
new_case r1
echo '{"type":"result","subtype":"success","total_cost_usd":0.01,"result":"I already called StructuredOutput."}' >"$FAKE_DIR/triage.first.json"
triage_json answer "README.md:1" "" "README.md"
act_json replied "README.md says it"
work
check "one retry on the same session recovers the route" test "$(last_run route)" = answer
check "the retry resumes the triage session" test "$(arg_of "$(grep -l 'did not return the JSON' "$FAKE_DIR"/call-*.log)" --resume)" = "$(cat "$RX/state/claims/r1/session")"

echo "unknown route"
new_case u1
triage_json yolo_deploy "README.md:1" "" "deploying"
work
check "unknown route becomes escalate" test "$(last_run route)" = escalate

rm -rf "$SB"
summary
