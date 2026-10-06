#!/bin/sh
# After the lab: remove what the bot kept. Usage: cleanup.sh [--days N] [--yes]
#   default    everything, after a confirm prompt
#   --days N   only what is older than N days (claims, threads, witness, outbox files, worktrees, memory lines)
#   --yes      no prompt
# Removes, for the TARGET_REPO and reception folder in owner.env:
#   <repo>/.worktrees/<id> worktrees and agent/<id> branches, state/claims, state/threads, state/sessions,
#   state/witness, state/seen, state/workers, outbox/, inbox/, MEMORY_FILE, log/, and the bot's own Claude Code
#   session transcripts (~/.claude/projects/<repo>-.worktrees-*: they hold the drawers and the threads).
# Keeps: owner.env, bot-settings.json and state/armed (no need to re-run install.sh), and your own checkout.
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
. "$KIT/lib/common.sh"
DAYS=""
YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS=$2; shift 2 ;;
    --yes) YES=1; shift ;;
    *) echo "usage: cleanup.sh [--days N] [--yes]" >&2; exit 2 ;;
  esac
done
case "$DAYS" in '' | *[!0-9]*) [ -z "$DAYS" ] || { echo "--days needs a number" >&2; exit 2; } ;; esac

# old PATH: true if PATH should go (always without --days; else last modified more than DAYS days ago).
old() { [ -z "$DAYS" ] || [ -n "$(find "$1" -maxdepth 0 -mtime +"$DAYS" 2>/dev/null)" ]; }

WT_ROOT=${TARGET_REPO:+$TARGET_REPO/.worktrees}
ENC=""
[ -n "$WT_ROOT" ] && ENC=$(printf '%s' "$WT_ROOT" | sed 's/[^A-Za-z0-9]/-/g')
echo "cleanup ${DAYS:+(older than $DAYS days) }in:"
echo "  reception folder: $RECEPTION_DIR (claims, threads, sessions, witness, outbox, inbox, log)"
[ -n "$WT_ROOT" ] && echo "  target repo:      $WT_ROOT/* worktrees and agent/* branches"
[ -n "${MEMORY_FILE:-}" ] && echo "  memory:           $MEMORY_FILE"
[ -n "$ENC" ] && echo "  transcripts:      $HOME/.claude/projects/$ENC*"
if [ "$YES" != 1 ]; then
  printf 'Remove these? [y/N] '
  read -r ans || ans=""
  case "$ans" in y | Y | yes) ;; *) echo "nothing removed"; exit 1 ;; esac
fi

n=0
if [ -n "$WT_ROOT" ] && [ -d "$WT_ROOT" ]; then
  for wt in "$WT_ROOT"/*; do
    [ -d "$wt" ] && old "$wt" || continue
    git -C "$TARGET_REPO" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
    n=$((n + 1))
  done
  git -C "$TARGET_REPO" worktree prune 2>/dev/null
fi
if [ -n "${TARGET_REPO:-}" ] && [ -d "$TARGET_REPO/.git" ]; then
  for b in $(git -C "$TARGET_REPO" for-each-ref --format='%(refname:short)' 'refs/heads/agent/*'); do
    if [ -n "$DAYS" ]; then
      _t=$(git -C "$TARGET_REPO" log -1 --format=%ct "$b" 2>/dev/null || echo 0)
      [ $(( $(date +%s) - _t )) -gt $((DAYS * 86400)) ] || continue
    fi
    git -C "$TARGET_REPO" branch -q -D "$b" && n=$((n + 1))
  done
fi
for d in "$STATE/claims" "$STATE/threads" "$STATE/sessions" "$STATE/witness" "$STATE/seen" "$STATE/workers" "$OUTBOX" "$INBOX" "$LOGDIR"; do
  [ -d "$d" ] || continue
  for f in "$d"/* "$d"/.[!.]*; do
    [ -e "$f" ] && old "$f" || continue
    rm -rf "$f" && n=$((n + 1))
  done
done
if [ -n "${MEMORY_FILE:-}" ] && [ -f "$MEMORY_FILE" ]; then
  if [ -z "$DAYS" ]; then rm -f "$MEMORY_FILE"; n=$((n + 1))
  else
    cut=$(date -u -d "-$DAYS days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$DAYS"d +%Y-%m-%dT%H:%M:%SZ)
    jq -c --arg cut "$cut" 'select((.ts // "") >= $cut)' "$MEMORY_FILE" >"$MEMORY_FILE.tmp" && mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
  fi
fi
if [ -n "$ENC" ]; then
  for p in "$HOME/.claude/projects/$ENC"*; do
    [ -d "$p" ] && old "$p" || continue
    rm -rf "$p" && n=$((n + 1))
  done
fi
mkdir -p "$STATE/claims" "$OUTBOX" "$INBOX" "$LOGDIR"
echo "cleanup: $n item(s) removed. Kept: owner.env, bot-settings.json, state/armed."
