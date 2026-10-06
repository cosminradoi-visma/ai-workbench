#!/bin/sh
# watch.sh, inbox lane: arming, claims, idempotency, PAUSED, owner-only approval, concurrent ticks.
# work.sh is replaced by a stub (WORK_CMD) that records which ids it was called with.
. "$(dirname "$0")/lib.sh"
mk_sandbox
STUB=$SB/work-stub.sh
printf '#!/bin/sh\necho "$1" >>"%s/work-calls.log"\n' "$SB" >"$STUB"
chmod +x "$STUB"
WORK_CMD=$STUB
export WORK_CMD
tick() { "$KIT/watch.sh" --wait >"$SB/tick.out" 2>&1; }
calls() { if [ -f "$SB/work-calls.log" ]; then wc -l <"$SB/work-calls.log" | tr -d ' '; else echo 0; fi; }

echo "watch.sh (inbox lane)"
cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/q1.md"
tick
rc=$?
check "not armed: refuses (exit 3)" test "$rc" -eq 3
check "not armed: says NOT ARMED" grep -q "NOT ARMED" "$SB/tick.out"
check "not armed: claims nothing" test ! -d "$RX/state/claims/q1"

arm
cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/q2.md"
tick
check "armed: both messages claimed" test -d "$RX/state/claims/q1" -a -d "$RX/state/claims/q2"
check "armed: work.sh called once per message" test "$(calls)" -eq 2
check "claim records source, ts and message path" test "$(cat "$RX/state/claims/q1/source")" = inbox -a -s "$RX/state/claims/q1/message_path"

tick
check "second tick: nothing new, nothing re-run (idempotent)" test "$(calls)" -eq 2

cp "$KIT/tests/fixtures/inbox/neighbour-approved.md" "$RX/inbox/n1.md"
tick
tick
check "approved by someone else: not claimed (silence)" test ! -d "$RX/state/claims/n1"
check "approved by someone else: logged once, not every tick" test "$(grep -c 'n1 ignored' "$RX/log/reception.log")" -eq 1
check "approved by someone else: work.sh not called" test "$(calls)" -eq 2

touch "$RX/PAUSED"
cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/q3.md"
tick
check "PAUSED: tick does nothing" test ! -d "$RX/state/claims/q3"
check "PAUSED: says stopped, and why" grep -q "stopped: PAUSED" "$SB/tick.out"
rm -f "$RX/PAUSED"
tick
check "unpaused: the waiting message is picked up" test -d "$RX/state/claims/q3"

cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/weird name!.md"
tick
check "file names become safe claim ids" test -d "$RX/state/claims/weird_name_"

echo '{"permissions":{"deny":[]}}' >"$TARGET/.claude/settings.json"
cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/q4.md"
tick
rc=$?
check "settings changed after arming: refuses until install.sh runs again" test "$rc" -eq 3 -a ! -d "$RX/state/claims/q4"
arm

echo "MAX_WORKERS"
echo 'MAX_WORKERS=1' >>"$OWNER_ENV"
mkdir -p "$RX/state/workers/1"; echo $$ >"$RX/state/workers/1/pid"   # a live worker holds the only slot
cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/b1.md"
before=$(calls)
tick
check "all slots busy: nothing claimed, the message waits" test ! -d "$RX/state/claims/b1" -a "$(calls)" -eq "$before"
check "all slots busy: says so" grep -q "workers busy" "$SB/tick.out"
sh -c 'exit 0' & dead=$!; wait "$dead"; echo "$dead" >"$RX/state/workers/1/pid"   # that worker died
tick
check "a dead worker's slot is freed and reused" test -d "$RX/state/claims/b1"
check "a foreground worker frees its slot afterwards" test ! -d "$RX/state/workers/1"
STUB2=$SB/slow-stub.sh
printf '#!/bin/sh\necho "$1" >>"%s/work-calls.log"\nsleep 2\n' "$SB" >"$STUB2"; chmod +x "$STUB2"
for i in 1 2 3; do cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/burst$i.md"; done
WORK_CMD=$STUB2 "$KIT/watch.sh" >"$SB/tick.out" 2>&1   # background workers
check "a burst of 3 with MAX_WORKERS=1: one background worker started" test "$(ls -d "$RX"/state/claims/burst* 2>/dev/null | wc -l | tr -d ' ')" -eq 1
sleep 3
WORK_CMD=$STUB2 "$KIT/watch.sh" >"$SB/tick.out" 2>&1
check "after it ends, the next tick starts the next one" test "$(ls -d "$RX"/state/claims/burst* 2>/dev/null | wc -l | tr -d ' ')" -eq 2
sleep 3
WORK_CMD=$STUB2 "$KIT/watch.sh" --wait >/dev/null 2>&1
sed -i.bak '/^MAX_WORKERS=1$/d' "$OWNER_ENV"; echo 'MAX_WORKERS=10' >>"$OWNER_ENV"

echo "claims under concurrency"
rm -f "$SB/work-calls.log"
for i in 1 2 3 4 5 6; do cp "$KIT/tests/fixtures/inbox/fahrenheit-question.md" "$RX/inbox/c$i.md"; done
for i in 1 2 3 4 5; do "$KIT/watch.sh" --wait >/dev/null 2>&1 & done
wait
dupes=$(sort "$SB/work-calls.log" | uniq -d | wc -l | tr -d ' ')
check "5 parallel ticks, 6 new messages (c1..c6): each worked exactly once" test "$(calls)" -eq 6 -a "$dupes" -eq 0

rm -rf "$SB"
summary
