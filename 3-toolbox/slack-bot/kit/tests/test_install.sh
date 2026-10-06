#!/bin/sh
# install.sh: merges denies, arms only when the self-test shows the deny holds. Fake claude, no model.
. "$(dirname "$0")/lib.sh"
mk_sandbox
echo '{"permissions":{"allow":["Bash(make *)"],"deny":["Read(.env*)"]},"model":"sonnet"}' >"$TARGET/.claude/settings.json"

echo "install.sh"
FAKE_INSTALL=leak "$KIT/install.sh" >"$SB/out" 2>&1
rc=$?
check "self-test sees a leak: NOT ARMED, exit 1" test "$rc" -eq 1 -a ! -f "$RX/state/armed"
check "says NOT ARMED" grep -q "NOT ARMED" "$SB/out"
check "canary files removed afterwards" test ! -f "$TARGET/.env.w3canary" -a ! -f "$TARGET/w3canary-secret.txt"

FAKE_INSTALL=deny "$KIT/install.sh" >"$SB/out" 2>&1
rc=$?
check "self-test denied: ARMED, exit 0" test "$rc" -eq 0 -a -f "$RX/state/armed"
S=$TARGET/.claude/settings.json
for rule in 'Read(.env*)' 'Read(**/*secret*)' 'Edit(.claude/**)' 'Bash(git push * main)' 'Bash(gh pr merge *)' 'Bash(rm -rf *)'; do
  check "deny written: $rule" sh -c "jq -e --arg r '$rule' '.permissions.deny | index(\$r)' '$S' >/dev/null"
done
check "existing settings kept (allow rule, model)" sh -c "jq -e '.permissions.allow[0] == \"Bash(make *)\" and .model == \"sonnet\"' '$S' >/dev/null"
check "no duplicate denies" test "$(jq '.permissions.deny | length' "$S")" -eq "$(jq '.permissions.deny | unique | length' "$S")"
check ".worktrees/ excluded from git locally" grep -qxF '.worktrees/' "$TARGET/.git/info/exclude"

"$KIT/install.sh" --no-selftest >"$SB/out" 2>&1
check "--no-selftest never arms" test ! -f "$RX/state/armed"

rm -rf "$SB"
summary
