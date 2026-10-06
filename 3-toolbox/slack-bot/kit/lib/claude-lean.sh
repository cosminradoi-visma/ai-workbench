#!/bin/sh
# Every bot run loads only what it needs: the owner's other connectors (MCP_DENY, written by find-self-dm.sh)
# are removed from the run. Seen 6 Oct: with ~200 connector tools loaded, one triage run read 216k tokens and hit
# its budget. A --disallowedTools server name ("mcp__claude_ai_Gmail") removes that server's tools; repeated
# --disallowedTools flags add up, so the runs' own deny lists still apply.
[ -n "${MCP_DENY:-}" ] && exec "${REAL_CLAUDE:-claude}" --disallowedTools "$MCP_DENY" "$@"
exec "${REAL_CLAUDE:-claude}" "$@"
