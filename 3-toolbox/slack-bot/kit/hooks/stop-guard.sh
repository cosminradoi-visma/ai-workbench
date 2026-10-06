#!/bin/sh
# PreToolUse, matcher ".*" (every tool), in every bot run (bot-settings.json, written by install.sh).
# Usage (from install.sh, absolute paths): stop-guard.sh <RECEPTION_DIR>/PAUSED <TARGET_REPO>/.claude/STOP
# "Anyone can stop it", mid-run: the moment either file exists, every further tool call is blocked.
# Also checks .claude/STOP in the session's own checkout and, when that is a git worktree, in the main repo.
# No jq, no owner.env: nothing here can fail open.
cat >/dev/null 2>&1   # the hook input is not needed
for f in "$@"; do
  [ -e "$f" ] && { echo "stopped: $f exists. Do nothing else; end the run now." >&2; exit 2; }
done
[ -e "$PWD/.claude/STOP" ] && { echo "stopped: $PWD/.claude/STOP exists. End the run now." >&2; exit 2; }
common=$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(dirname "$common")
[ -e "$main/.claude/STOP" ] && { echo "stopped: $main/.claude/STOP exists. End the run now." >&2; exit 2; }
exit 0
