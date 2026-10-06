#!/bin/sh
# W3 bot lab: one-time setup. From this folder:
#   sh setup.sh                      # practice repo: weather-api, cloned with its git history into ~/w3
#   sh setup.sh --repo ~/code/mine   # your own repo instead (link it from your workbench first: /kb-link-repo)
# Then: ./kit/find-self-dm.sh, ./kit/install.sh, and ./kit/watch.sh --wait (details: ../slack-bot.md).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=$HOME/w3
REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=$2; shift 2 ;;
    --dest) DEST=$2; shift 2 ;;
    *) echo "usage: sh setup.sh [--repo <path>] [--dest <dir>]" >&2; exit 2 ;;
  esac
done
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)" >&2; exit 1; }; }
need git "https://git-scm.com"
need jq "brew install jq / apt install jq"
need claude "Claude Code, v2.1.259 or later"
mkdir -p "$DEST"

# 1. The bot.
if [ -d "$DEST/kit" ]; then echo "kit: $DEST/kit already there, kept"; else cp -R "$HERE/kit" "$DEST/kit"; fi
chmod +x "$DEST"/kit/*.sh "$DEST"/kit/hooks/*.sh "$DEST"/kit/lib/*.sh "$DEST"/kit/tests/*.sh "$DEST"/kit/tests/slack-lane/run.sh 2>/dev/null || true
echo "kit: offline tests (no model, no Slack)..."
sh "$DEST/kit/tests/run.sh" | tail -1

# 2. The repo it works on.
if [ -z "$REPO" ]; then
  need uv "https://docs.astral.sh/uv/"
  if [ -d "$DEST/weather-api/.git" ]; then echo "weather-api: already cloned, kept"
  else git clone -q -b main "$HERE/weather-api.bundle" "$DEST/weather-api" && git -C "$DEST/weather-api" remote remove origin; fi
  chmod +x "$DEST"/weather-api/scripts/*.sh
  (cd "$DEST/weather-api" && uv sync -q && uv run pytest -q | tail -1)
  TARGET=$DEST/weather-api
  echo "weather-api: $(git -C "$TARGET" log --oneline | wc -l | tr -d ' ') commits, try: git -C $TARGET log --oneline"
else
  TARGET=$(cd "$REPO" && pwd)
  [ -d "$TARGET/.git" ] || { echo "$TARGET is not a git repo" >&2; exit 1; }
  [ -f "$TARGET/AGENTS.md" ] || echo "note: $TARGET has no AGENTS.md. Run /kb-link-repo from your workbench first (Cosmin's part)."
  grep -q '^## Operate' "$TARGET/AGENTS.md" 2>/dev/null || echo "note: AGENTS.md has no '## Operate' section. Ask your agent to write one, like weather-api's."
  echo "your repo: $TARGET. Set TEST_CMD / TEST_ALL_CMD in kit/owner.env if it does not use 'uv run pytest'."
fi

# 3. The bot's config: your repo and your workbench. find-self-dm.sh fills in the Slack part.
ENVF=$DEST/kit/owner.env
[ -f "$ENVF" ] || cp "$DEST/kit/owner.env.example" "$ENVF"
set_kv() { if grep -q "^$1=" "$ENVF"; then sed -i.bak "s|^$1=.*|$1=$2|" "$ENVF" && rm -f "$ENVF.bak"; else printf '%s=%s\n' "$1" "$2" >>"$ENVF"; fi; }
set_kv TARGET_REPO "$TARGET"
if [ -d "$HOME/workbench" ]; then set_kv WORKBENCH_DIR "$HOME/workbench"; echo "workbench: $HOME/workbench (self-DM mode reads NOW.md and 1-me/ from it)"
else echo "workbench: not found at ~/workbench. Set WORKBENCH_DIR in $ENVF if it lives elsewhere."; fi

cat <<EOF

Done. Next, from $DEST:
  ./kit/find-self-dm.sh    # sends you ONE Slack message, fills OWNER_ID, CHANNEL_ID, SELF_DM=true, MCP_DENY
  ./kit/install.sh         # writes the deny rules into $TARGET/.claude/settings.json, arms the bot
  ./kit/watch.sh --wait    # one tick. Then post a question to yourself in Slack, react :robot_face:, tick again
Stop it any time: touch $DEST/kit/PAUSED   (or $TARGET/.claude/STOP)
EOF
