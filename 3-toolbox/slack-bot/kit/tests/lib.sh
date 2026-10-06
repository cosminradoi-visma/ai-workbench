# Helpers for the offline tests. POSIX sh. No network, no model calls.
TESTS=$(cd "$(dirname "$0")" && pwd)
KIT=$(dirname "$TESTS")
T_PASS=0
T_FAIL=0
GIT_AUTHOR_NAME=kit-test GIT_AUTHOR_EMAIL=kit-test@example.invalid
GIT_COMMITTER_NAME=kit-test GIT_COMMITTER_EMAIL=kit-test@example.invalid
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

ok() { T_PASS=$((T_PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { T_FAIL=$((T_FAIL + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }
check() { _d=$1; shift; if "$@"; then ok "$_d"; else bad "$_d"; fi; }
summary() { printf '  %s: %d passed, %d failed\n' "$(basename "$0")" "$T_PASS" "$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }

# A throwaway reception folder + a tiny target repo with a planted bug (lib/value.txt is 2, should be 3).
mk_sandbox() {
  SB=$(mktemp -d)
  TARGET=$SB/repo
  RX=$SB/rx
  mkdir -p "$TARGET/lib" "$TARGET/tests" "$TARGET/.claude" "$SB/fake"
  echo 2 >"$TARGET/lib/value.txt"
  echo 'exit 0' >"$TARGET/tests/test_ok.sh"
  printf 'for t in tests/test_*.sh; do sh "$t" || exit 1; done\necho "all passed"\n' >"$TARGET/tests/run_all.sh"
  echo 'The value lives in lib/value.txt.' >"$TARGET/README.md"
  echo '{"permissions":{"deny":["Read(.env*)"]}}' >"$TARGET/.claude/settings.json"
  printf '%s=%s\n' TOKEN supersecretvalue123 >"$TARGET/.env"   # fake; built at runtime so the KB secret check stays quiet
  git -C "$TARGET" init -q -b main
  git -C "$TARGET" add -A
  git -C "$TARGET" commit -q -m init
  cat >"$SB/owner.env" <<EOT
OWNER_ID=UOWNER
OWNER_NAME=Tester
SIGNATURE="🤖 Tester's agent:"
SOURCE=inbox
CHANNEL_ID=CTEST
CHANNEL_NAME=test
TARGET_REPO=$TARGET
ALLOW_PR=true
RECEPTION_DIR=$RX
CLAUDE_BIN=$TESTS/fake-claude.sh
TEST_CMD=sh
TEST_ALL_CMD="sh tests/run_all.sh"
WORK_BUDGET_USD=1
EOT
  OWNER_ENV=$SB/owner.env
  FAKE_DIR=$SB/fake
  export OWNER_ENV FAKE_DIR
  mkdir -p "$RX/state/claims" "$RX/inbox" "$RX/outbox" "$RX/log"
}

arm() { cksum <"$TARGET/.claude/settings.json" | awk '{print $1}' >"$RX/state/armed"; }

# claim ID [source] [ts]: what watch.sh does before calling work.sh
claim() {
  mkdir -p "$RX/state/claims/$1"
  echo "${2:-inbox}" >"$RX/state/claims/$1/source"
  echo "${3:-$1}" >"$RX/state/claims/$1/ts"
  echo "$RX/inbox/$1.md" >"$RX/state/claims/$1/message_path"
}

triage_json() { # route evidence_ref failing_test draft
  jq -nc --arg r "$1" --arg e "$2" --arg f "$3" --arg d "$4" \
    '{type: "result", subtype: "success", total_cost_usd: 0.02, structured_output: {route: $r, reason: "test reason",
      confidence: "high", evidence: [{kind: "file", ref: $e}], draft_reply: $d,
      failing_test: (if $f == "" then null else $f end), open_questions: []}}' >"$FAKE_DIR/triage.json"
}
act_json() { # verdict reply failing_test
  jq -nc --arg v "$1" --arg r "$2" --arg f "${3:-}" \
    '{type: "result", subtype: "success", total_cost_usd: 0.07, structured_output: {verdict: $v, reply: $r,
      failing_test: (if $f == "" then null else $f end), pr_title: "fix: value should be 3",
      pr_body: "The value was 2.", notes: ""}}' >"$FAKE_DIR/act.json"
}
calls_with() { grep -l "^phase=$1" "$FAKE_DIR"/call-*.log 2>/dev/null | head -1; }
