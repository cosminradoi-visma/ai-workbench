#!/bin/sh
# Checks that the golden runner run.py and its Perl twin run.pl give the same results, using a
# stub `claude` (no tokens spent): a pass, a cheat on a protected file, a decline, a failing check, a bad task, a compound check.
#   sh 0-meta/scripts/test-golden.sh       (needs python3 and perl: run it where both exist)
set -u
G=$(cd "$(dirname "$0")/../.." && pwd)/3-toolbox/project-kit/.claude/golden
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/repo/.claude/golden" "$TMP/repo/tests"
cat > "$TMP/bin/claude" <<'STUB'
#!/bin/sh
case "$2" in *cheat*) echo x > tests/t.sh ;; *) mkdir -p src; echo ok > src/ok ;; esac
printf '{"result":"I cannot do that, done","total_cost_usd":0.12,"num_turns":3,"subtype":"success"}'
STUB
chmod +x "$TMP/bin/claude"
cd "$TMP/repo" && git init -q && echo 'test -f src/ok' > tests/t.sh
cp "$G/run.py" "$G/run.pl" .claude/golden/
printf -- '---\ncheck: sh tests/t.sh\nprotect: tests/*\n---\nfix it\n' > .claude/golden/a-fix.md
printf -- '---\ncheck: sh tests/t.sh\nprotect: tests/*\n---\ncheat please\n' > .claude/golden/b-cheat.md
printf -- '---\ncheck: grep -q cannot .golden-output.txt\n---\nsay no\n' > .claude/golden/c-decline.md
printf -- '---\ncheck: grep -q never .golden-output.txt\n---\nsay yes\n' > .claude/golden/d-fails.md
printf -- '---\nmax_turns: 3\n---\nno check\n' > .claude/golden/e-bad.md
printf -- '---\ncheck: OK=1 sh -c "test \\$OK = 1" && cd tests && test -f ../src/ok\n---\nfix it too\n' > .claude/golden/f-compound.md
git add -A && git -c user.email=t@t -c user.name=t commit -qm init
same=0; diff=0
for a in --list "" fix; do
  p=$(PATH=$TMP/bin:$PATH python3 .claude/golden/run.py $a 2>&1; echo "exit=$?")
  l=$(PATH=$TMP/bin:$PATH perl .claude/golden/run.pl $a 2>&1; echo "exit=$?")
  p=$(printf '%s' "$p" | sed -E 's/ [0-9]+s  / Ns  /'); l=$(printf '%s' "$l" | sed -E 's/ [0-9]+s  / Ns  /')
  if [ "$p" = "$l" ]; then same=$((same + 1)); else diff=$((diff + 1)); echo "DIFF [$a]"; printf '%s\n---\n%s\n' "$p" "$l"; fi
done
left=$(git worktree list | wc -l)
[ "$left" = 1 ] || { echo "worktrees left behind: $left"; diff=$((diff + 1)); }
echo "golden runner twins: $same identical, $diff different"
[ "$diff" = 0 ]
