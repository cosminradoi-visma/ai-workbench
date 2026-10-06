#!/bin/sh
# Self-DM mode: only the owner's own DM counts, and the workbench is handed over only in that mode.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh
OWNER_ENV=$PWD/owner.env.example
. lib/common.sh 2>/dev/null
OWNER_ID=UOWNER CHANNEL_ID=D1 TRIGGER=robot_face
F=tests/fixtures/witness-selfdm.txt
if self_dm_ok 1700000000.000100 "$F"; then ok "the owner's own DM is accepted"; else bad "the owner's own DM is accepted"; fi
if self_dm_ok 1700000000.000200 "$F"; then bad "a DM with someone else is rejected"; else ok "a DM with someone else is rejected"; fi
if self_dm_ok 1700000000.999999 "$F"; then bad "an unknown ts is rejected"; else ok "an unknown ts is rejected"; fi

SELF_DM=true
case "$(trigger_query)" in "in:<#D1> from:<@UOWNER> hasmy::robot_face: after:"*) ok "self-DM query adds from:<@owner>" ;; *) bad "self-DM query adds from:<@owner> (got $(trigger_query))" ;; esac
SELF_DM=false
case "$(trigger_query)" in "in:<#D1> hasmy::robot_face: after:"*) ok "channel query unchanged" ;; *) bad "channel query unchanged (got $(trigger_query))" ;; esac

WORKBENCH_DIR=$PWD/tests/fixtures/workbench WORK_ITEM=demo
SELF_DM=true;  ctx=$(workbench_context)
case "$ctx" in *"fixing Bergen"*) ok "self-DM: NOW.md is handed over" ;; *) bad "self-DM: NOW.md is handed over" ;; esac
case "$ctx" in *"file:line"*) ok "self-DM: how-i-work.md is handed over" ;; *) bad "self-DM: how-i-work.md is handed over" ;; esac
case "$ctx" in *"half done"*) ok "self-DM: the work item's state.md is handed over" ;; *) bad "self-DM: the work item's state.md is handed over" ;; esac
SELF_DM=false; ctx=$(workbench_context slack)
[ -z "$ctx" ] && ok "team-channel mode (slack, not self-DM): no workbench, ever" || bad "team-channel mode (slack, not self-DM): no workbench, ever"
ctx=$(workbench_context inbox)
case "$ctx" in *"fixing Bergen"*) ok "inbox lane: the drawers are handed over (USE_WORKBENCH=true)" ;; *) bad "inbox lane: the drawers are handed over" ;; esac
USE_WORKBENCH=false; ctx=$(workbench_context inbox)
[ -z "$ctx" ] && ok "USE_WORKBENCH=false: no drawers in the inbox lane" || bad "USE_WORKBENCH=false: no drawers in the inbox lane"
SELF_DM=true; ctx=$(workbench_context slack)
[ -z "$ctx" ] && ok "USE_WORKBENCH=false: no drawers in self-DM either" || bad "USE_WORKBENCH=false: no drawers in self-DM either"
USE_WORKBENCH=true; WORKBENCH_MAX_BYTES=300; ctx=$(workbench_context inbox)
[ "${#ctx}" -lt 1200 ] && ok "drawers are size-capped (WORKBENCH_MAX_BYTES)" || bad "drawers are size-capped (got ${#ctx} chars)"
WORKBENCH_MAX_BYTES=20000

# owner.env saved with Windows line endings (CRLF): values must come out clean.
T=$(mktemp -d)
printf 'OWNER_ID=UCRLF\r\nSOURCE=inbox\r\nOWNER_NAME="Ana Pop"\r\nTARGET_REPO=%s\r\n' "$T" >"$T/owner.env"
got=$(KIT=$PWD OWNER_ENV=$T/owner.env sh -c '. lib/common.sh; printf "%s|%s|%s" "$OWNER_ID" "$SOURCE" "$OWNER_NAME"')
[ "$got" = "UCRLF|inbox|Ana Pop" ] && ok "CRLF owner.env: no \\r in the values" || bad "CRLF owner.env: no \\r in the values (got $(printf '%s' "$got" | od -c | head -2 | tr -s ' '))"
rm -rf "$T"

T=$(mktemp -d); mkdir -p "$T/.claude"; RECEPTION_DIR=$T/rx; mkdir -p "$RECEPTION_DIR"; TARGET_REPO=$T
stop_reason >/dev/null && bad "no switch: not stopped" || ok "no switch: not stopped"
: >"$T/.claude/STOP";      stop_reason >/dev/null && ok ".claude/STOP in the target repo stops it" || bad ".claude/STOP stops it"
rm "$T/.claude/STOP"; : >"$RECEPTION_DIR/PAUSED"; stop_reason >/dev/null && ok "PAUSED stops it" || bad "PAUSED stops it"
rm -rf "$T"
summary
