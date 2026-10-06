#!/bin/sh
# Reset the showcase stage for a new rehearsal. Local only: closes nothing remote, pushes nothing.
#   - removes the agent worktrees (.worktrees/*) and agent/* branches in weather-api
#   - clears claims, witness files, outbox, logs and inbox
#   - restores the thread memory from memory/threads.seed.jsonl
#   - keeps state/armed (no need to re-run install.sh unless .claude/settings.json changed)
#   - removes PAUSED
cd "$(dirname "$0")" || exit 1
HERE=$PWD
REPO=$(cd ../weather-api && pwd)
for wt in "$REPO"/.worktrees/*; do
  [ -d "$wt" ] || continue
  git -C "$REPO" worktree remove --force "$wt" && echo "removed worktree $(basename "$wt")"
done
git -C "$REPO" worktree prune
for b in $(git -C "$REPO" for-each-ref --format='%(refname:short)' 'refs/heads/agent/*'); do
  git -C "$REPO" branch -q -D "$b" && echo "deleted branch $b"
done
git -C "$REPO" bisect reset >/dev/null 2>&1
rm -rf "$HERE/state/claims" "$HERE/state/witness" "$HERE/state/seen" "$HERE/outbox" "$HERE/log" "$HERE/inbox"
mkdir -p "$HERE/state/claims" "$HERE/state/witness" "$HERE/state/seen" "$HERE/outbox" "$HERE/log" "$HERE/inbox"
cp "$HERE/memory/threads.seed.jsonl" "$HERE/memory/threads.jsonl"
rm -f "$HERE/PAUSED"
if [ -f "$HERE/state/armed" ]; then echo "still armed"; else echo "NOT armed: run OWNER_ENV=$HERE/owner.env ../kit/install.sh"; fi
echo "stage reset. weather-api main: $(git -C "$REPO" log -1 --format='%h %s')"
