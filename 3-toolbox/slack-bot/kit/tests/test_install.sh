#!/bin/sh
# install.sh: merges denies, arms only when the self-test shows the deny holds. Fake claude, no model.
. "$(dirname "$0")/lib.sh"
mk_sandbox
echo '{"permissions":{"allow":["Bash(make *)"],"deny":["Read(.env*)"]},"model":"sonnet"}' >"$TARGET/.claude/settings.json"

mkdir -p "$SB/wb/1-me"; echo "private" >"$SB/wb/NOW.md"
printf 'WORKBENCH_DIR=%s\n' "$SB/wb" >>"$OWNER_ENV"

echo "install.sh"
FAKE_INSTALL=leak "$KIT/install.sh" >"$SB/out" 2>&1
rc=$?
check "self-test sees a leak: NOT ARMED, exit 1" test "$rc" -eq 1 -a ! -f "$RX/state/armed"
check "says NOT ARMED" grep -q "NOT ARMED" "$SB/out"
check "canary files removed afterwards" test ! -f "$TARGET/.env.w3canary" -a ! -f "$TARGET/w3canary-secret.txt"
check "workbench canary removed afterwards" test ! -f "$SB/wb/w3canary-workbench.md"

FAKE_INSTALL=skip "$KIT/install.sh" >"$SB/out" 2>&1
check "a forbidden call never attempted: NOT ARMED" test "$?" -eq 1 -a ! -f "$RX/state/armed"
check "says which one was not attempted" grep -q "not-attempted" "$SB/out"

FAKE_INSTALL=output "$KIT/install.sh" >"$SB/out" 2>&1
check "git log --output allowed: NOT ARMED" test "$?" -eq 1 -a ! -f "$RX/state/armed"
check "the --output canary file is removed" test ! -f "$TARGET/w3canary-output.txt"

FAKE_INSTALL=deny "$KIT/install.sh" >"$SB/out" 2>&1
rc=$?
check "self-test denied: ARMED, exit 0" test "$rc" -eq 0 -a -f "$RX/state/armed"
P=$(calls_with none)
check "self-test asks for a Read of a workbench file" grep -q "Read tool: $SB/wb/w3canary-workbench.md" "$P"
check "self-test asks for cat of a workbench file" grep -q "Bash: cat $SB/wb/w3canary-workbench.md" "$P"
check "self-test asks for git log --output" grep -q "Bash: git log -1 --output=" "$P"
check "self-test runs with the bot's settings" grep -qx "arg=$RX/bot-settings.json" "$P"
check "self-test runs with --setting-sources project" grep -qx "arg=project" "$P"
B=$RX/bot-settings.json
check "bot-settings: blockReadsOutsideWorkingDirectories" jq -e '.permissions.blockReadsOutsideWorkingDirectories == true' "$B"
for rule in "Read(/$SB/wb/**)" 'Read(~/.claude/**)' 'Read(~/.ssh/**)' 'Read(~/.aws/**)' 'Read(~/.azure/**)' 'Read(~/.kube/**)' 'Read(~/.config/**)' "Read(/$OWNER_ENV)" 'Bash(git * --output*)' 'Bash(git *--output=*)' 'Read(.env*)'; do
  check "bot-settings deny: $rule" sh -c "jq -e --arg r '$rule' '.permissions.deny | index(\$r)' '$B' >/dev/null"
done
check "bot-settings: opportunistic sandbox, no unsandboxed retry, no auto-allow, no domains" jq -e '.sandbox | .enabled == true and .failIfUnavailable == false and .allowUnsandboxedCommands == false and .autoAllowBashIfSandboxed == false and .network.allowedDomains == []' "$B"
check "bot-settings: the target's allow rules are not copied" jq -e '.permissions.allow == null' "$B"
check "bot-settings: STOP hook on every tool, absolute paths" jq -e --arg p "$RX/PAUSED" '.hooks.PreToolUse[] | select(.matcher == ".*") | .hooks[0].command | contains($p)' "$B"
: >"$RX/PAUSED"
"$KIT/install.sh" >"$SB/out" 2>&1
check "PAUSED during install: refuses to self-test, NOT ARMED" test "$?" -eq 1 -a ! -f "$RX/state/armed"
rm -f "$RX/PAUSED"
FAKE_INSTALL=deny "$KIT/install.sh" >/dev/null 2>&1
echo '{"sandbox":{"enabled":false}}' >"$B.new"; cp "$B" "$B.keep"; mv "$B.new" "$B"
check "bot-settings changed after arming: not armed" sh -c "OWNER_ENV='$OWNER_ENV' KIT='$KIT' sh -c '. \"\$KIT/lib/common.sh\"; is_armed' && exit 1 || exit 0"
mv "$B.keep" "$B"
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
