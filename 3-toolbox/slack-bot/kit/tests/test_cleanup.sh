#!/bin/sh
# cleanup.sh: the post-lab retention step. Removes worktrees, agent/* branches, claims, witness, outbox,
# memory and the bot's transcripts; keeps owner.env, bot-settings.json and state/armed.
. "$(dirname "$0")/lib.sh"
mk_sandbox
HOME=$SB/home
export HOME
printf 'MEMORY_FILE=%s\n' "$SB/memory.jsonl" >>"$OWNER_ENV"
seed() {
  git -C "$TARGET" worktree add -q -b agent/x1 "$TARGET/.worktrees/x1" HEAD
  mkdir -p "$RX/state/claims/x1" "$RX/state/threads/t1" "$RX/state/witness"
  echo hit >"$RX/state/witness/tick.txt"; echo reply >"$RX/outbox/x1.md"
  echo '{"ts":"2026-01-01T00:00:00Z","id":"old"}' >"$SB/memory.jsonl"
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"id\":\"new\"}" >>"$SB/memory.jsonl"
  ENC=$(printf '%s' "$TARGET/.worktrees" | sed 's/[^A-Za-z0-9]/-/g')
  mkdir -p "$HOME/.claude/projects/$ENC-x1" "$HOME/.claude/projects/-other-project"
}
arm
seed
echo "cleanup.sh"
printf 'n\n' | "$KIT/cleanup.sh" >"$SB/out" 2>&1
check "no confirm: nothing removed" test -d "$RX/state/claims/x1" -a -d "$TARGET/.worktrees/x1"
"$KIT/cleanup.sh" --days 1 --yes >"$SB/out" 2>&1
check "--days 1: today's claim is kept" test -d "$RX/state/claims/x1"
check "--days 1: old memory lines go, new ones stay" test "$(jq -r .id "$SB/memory.jsonl" | tr '\n' ' ')" = "new "
"$KIT/cleanup.sh" --yes >"$SB/out" 2>&1
check "worktree removed" test ! -d "$TARGET/.worktrees/x1"
check "agent/* branch deleted" sh -c "! git -C '$TARGET' rev-parse -q --verify agent/x1 >/dev/null"
check "claims, threads, witness, outbox cleared" test ! -e "$RX/state/claims/x1" -a ! -e "$RX/state/threads/t1" -a ! -e "$RX/state/witness/tick.txt" -a ! -e "$RX/outbox/x1.md"
check "memory removed" test ! -f "$SB/memory.jsonl"
check "the bot's transcripts removed, other projects kept" test ! -d "$HOME/.claude/projects/$ENC-x1" -a -d "$HOME/.claude/projects/-other-project"
check "kept: state/armed and bot-settings.json" test -f "$RX/state/armed" -a -f "$RX/bot-settings.json"
check "the owner's checkout is untouched" test -z "$(git -C "$TARGET" status --porcelain)"
rm -rf "$SB"
summary
