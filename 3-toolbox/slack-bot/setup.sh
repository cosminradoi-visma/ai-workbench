#!/bin/sh
# W3 bot lab: one-time setup. From this folder:
#   sh setup.sh --check [--live]     # preflight only: one ✓/✗ line per tool; changes nothing (run it at break 1)
#   sh setup.sh                      # practice repo: weather-api, cloned with its git history into ~/w3
#   sh setup.sh --repo ~/code/mine   # your own repo instead (link it from your workbench first: /kb-link-repo)
# Then: ./kit/find-self-dm.sh, ./kit/install.sh, and ./kit/watch.sh --wait (details: ../slack-bot.md).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=$HOME/w3
REPO=""
CHECK=0
LIVE=0
MIN_CLAUDE=2.1.259
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=$2; shift 2 ;;
    --dest) DEST=$2; shift 2 ;;
    --check) CHECK=1; shift ;;
    --live) LIVE=1; shift ;;
    *) echo "usage: sh setup.sh [--check [--live]] [--repo <path>] [--dest <dir>]" >&2; exit 2 ;;
  esac
done

# ---------- preflight ----------
FAILED=0
yes_() { printf '  \342\234\223 %s\n' "$1"; }                       # ✓
no_() { printf '  \342\234\227 %s\n' "$1"; [ "${2:-required}" = required ] && FAILED=$((FAILED + 1)); return 0; }   # ✗
# ver_ge A B: is version A >= version B (dotted numbers)?
ver_ge() { awk -v a="$1" -v b="$2" 'BEGIN { n = split(a, x, "."); split(b, y, ".")
  for (i = 1; i <= 3; i++) { if ((x[i] + 0) > (y[i] + 0)) exit 0; if ((x[i] + 0) < (y[i] + 0)) exit 1 } exit 0 }'; }
preflight() {
  echo "preflight:"
  if command -v git >/dev/null 2>&1; then yes_ "git $(git --version | awk '{print $3}')"; else no_ "git: missing (https://git-scm.com)"; fi
  if command -v jq >/dev/null 2>&1; then yes_ "jq $(jq --version 2>/dev/null)"; else no_ "jq: missing (brew install jq / apt install jq / winget install jqlang.jq). Without it the bot's Slack hooks deny every Slack call"; fi
  if command -v uv >/dev/null 2>&1; then yes_ "uv $(uv --version 2>/dev/null | awk '{print $2}')"
  else no_ "uv: missing (https://docs.astral.sh/uv/), needed for weather-api"; fi
  # python3: a real interpreter, not the Windows Store stub (WindowsApps\python3.exe opens the Store and prints nothing).
  _py=$(command -v python3 2>/dev/null || true)
  if [ -n "$_py" ] && _pv=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null) && [ -n "$_pv" ]; then
    case "$_py" in *WindowsApps*) no_ "python3 at $_py is the Windows Store stub: install Python, or let uv provide one (uv python install)" ;;
      *) yes_ "python3 $_pv" ;; esac
  else
    no_ "python3: missing or the Windows Store stub (install Python 3, or run: uv python install)"
  fi
  if command -v claude >/dev/null 2>&1; then
    _cv=$(claude --version 2>/dev/null | awk '{print $1}')
    if [ -n "$_cv" ] && ver_ge "$_cv" "$MIN_CLAUDE"; then yes_ "claude $_cv (>= $MIN_CLAUDE)"
    else no_ "claude ${_cv:-?}: need $MIN_CLAUDE or later (claude update)"; fi
    if [ "$LIVE" = 1 ]; then
      _out=$(claude -p "Reply with the single word OK." --model haiku --max-turns 1 --tools "" --setting-sources project \
        --strict-mcp-config --no-session-persistence --output-format json </dev/null 2>/dev/null || true)
      if printf '%s' "$_out" | grep -q '"subtype": *"success"'; then yes_ "claude -p works (one Haiku turn)"
      else no_ "claude -p failed: run claude once and log in (/login)"; fi
    else
      if claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; then yes_ "claude logged in (add --live for a real one-turn claude -p call)"
      else no_ "claude is not logged in: run claude, then /login"; fi
    fi
    _mcp=$(claude mcp list 2>/dev/null || true)
    if printf '%s\n' "$_mcp" | grep -q '^claude\.ai Slack:.*Connected'; then yes_ "Slack connector: claude.ai Slack connected"
    elif printf '%s\n' "$_mcp" | grep -q '^claude\.ai Slack:'; then no_ "Slack connector: listed but not connected (claude, /mcp, claude.ai Slack, authenticate). The inbox lane still works" optional
    else no_ "Slack connector: not visible (connect Slack at claude.ai > Settings > Connectors, then check /mcp). The inbox lane still works" optional; fi
  else
    no_ "claude: missing (Claude Code $MIN_CLAUDE or later)"
  fi
  # The OS sandbox is the extra boundary around the commands the bot runs. Not required: the fences hold without it.
  case "$(uname -s 2>/dev/null)" in
    Darwin) yes_ "sandbox: macOS (built in)" ;;
    Linux)
      if command -v bwrap >/dev/null 2>&1 && command -v socat >/dev/null 2>&1; then yes_ "sandbox: bubblewrap + socat"
      else no_ "sandbox: not available (needs bubblewrap AND socat: sudo apt install bubblewrap socat). Optional: the bot's commands then run unsandboxed" optional; fi ;;
    *) no_ "sandbox: not available on native Windows (use WSL2 for it). Optional: the bot's commands then run unsandboxed" optional ;;
  esac
  if [ "$FAILED" -gt 0 ]; then echo "preflight: $FAILED required check(s) failed"; return 1; fi
  echo "preflight: ready"
}

if [ "$CHECK" = 1 ]; then
  preflight
  exit $?
fi
preflight || { echo "fix the ✗ lines above first (sh setup.sh --check to re-run them)" >&2; exit 1; }
mkdir -p "$DEST"

# 1. The bot.
if [ -d "$DEST/kit" ]; then echo "kit: $DEST/kit already there, kept"; else cp -R "$HERE/kit" "$DEST/kit"; fi
chmod +x "$DEST"/kit/*.sh "$DEST"/kit/hooks/*.sh "$DEST"/kit/lib/*.sh "$DEST"/kit/tests/*.sh "$DEST"/kit/tests/slack-lane/run.sh 2>/dev/null || true
echo "kit: offline tests (no model, no Slack)..."
sh "$DEST/kit/tests/run.sh" | tail -1

# 2. The repo it works on.
if [ -z "$REPO" ]; then
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

# 3. The bot's config: your name, your repo and your workbench. find-self-dm.sh fills in the Slack part.
ENVF=$DEST/kit/owner.env
[ -f "$ENVF" ] || cp "$DEST/kit/owner.env.example" "$ENVF"
# set_kv KEY VALUE: replace KEY=... (or append it), value double-quoted. No sed, so any character in VALUE is safe.
set_kv() {
  _v=$(printf '%s' "$2" | sed -e 's/[\\"$`]/\\&/g')
  awk -v k="$1" -v line="$1=\"$_v\"" 'BEGIN { done = 0 }
    index($0, k "=") == 1 { if (!done) print line; done = 1; next } { print }
    END { if (!done) print line }' "$ENVF" >"$ENVF.tmp" && mv "$ENVF.tmp" "$ENVF"
}
get_kv() { sed -n "s/^$1=//p" "$ENVF" | sed -e 's/[[:space:]]*#.*$//' -e 's/^"//' -e 's/"$//' | tr -d '\r' | tail -1; }
set_kv TARGET_REPO "$TARGET"
NAME=$(git config user.name 2>/dev/null || true)
if [ -z "$(get_kv OWNER_NAME)" ]; then
  if [ -n "$NAME" ]; then set_kv OWNER_NAME "$NAME"; echo "name: $NAME (from git config user.name)"
  else echo "name: git config user.name is empty. Set OWNER_NAME and SIGNATURE in $ENVF"; fi
fi
if [ -z "$(get_kv SIGNATURE)" ] && [ -n "$(get_kv OWNER_NAME)" ]; then
  set_kv SIGNATURE "🤖 $(get_kv OWNER_NAME)'s agent:"
  echo "signature: $(get_kv SIGNATURE)"
fi
if [ -d "$HOME/workbench" ]; then set_kv WORKBENCH_DIR "$HOME/workbench"; echo "workbench: $HOME/workbench (the script hands the bot NOW.md and 1-me/; the bot itself cannot read it)"
else echo "workbench: not found at ~/workbench. Set WORKBENCH_DIR in $ENVF if it lives elsewhere."; fi

cat <<EOF

Done. Next, from $DEST:
  ./kit/find-self-dm.sh    # sends you ONE Slack message, fills OWNER_ID, CHANNEL_ID, SELF_DM=true, MCP_DENY
  ./kit/install.sh         # deny rules + bot-settings.json, a self-test (about \$0.03), arms the bot
  ./kit/watch.sh --wait    # one tick. Then post a question to yourself in Slack, react :robot_face:, tick again
Stop it any time, even mid-run: touch $DEST/kit/PAUSED   (or $TARGET/.claude/STOP)
After the lab: ./kit/cleanup.sh   (removes worktrees, agent/* branches, claims, outbox, memory)
EOF
