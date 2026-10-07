#!/bin/sh
# Checks that kb_check.py and its Perl twin kb_check.pl print exactly the same thing, on a fresh
# template, a filled-in workbench with a linked repo, and one with planted problems.
#   sh 0-meta/scripts/test-kb-check.sh       (needs python3 and perl: run it where both exist)
set -u
SRC=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
compare() { # label dir
  for mode in "" --brief --report; do
    a=$(cd "$2" && HOME=$TMP/home python3 0-meta/scripts/kb_check.py $mode 2>&1; echo "exit=$?")
    b=$(cd "$2" && HOME=$TMP/home perl 0-meta/scripts/kb_check.pl $mode 2>&1; echo "exit=$?")
    if [ "$a" = "$b" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "DIFF $1 ${mode:-full}"; printf '%s\n' "$a" > "$TMP/a"; printf '%s\n' "$b" > "$TMP/b"; diff "$TMP/a" "$TMP/b" | head -10; fi
  done
}
mkdir -p "$TMP/home"
copy() { mkdir -p "$1"; (cd "$SRC" && tar cf - --exclude=.git --exclude=__pycache__ .) | (cd "$1" && tar xf -); }

copy "$TMP/fresh"; compare fresh "$TMP/fresh"

copy "$TMP/filled"; W=$TMP/filled; R=$TMP/repo; D=$(date +%F)
mkdir -p "$R/.claude/hooks" "$R/.claude/agents" "$R/.claude/golden" "$R/.claude/skills/release"; echo "# repo" > "$R/AGENTS.md"
touch "$R/.claude/hooks/guard.pl" "$R/.claude/agents/reviewer.md" "$R/.claude/golden/refund.md" "$R/.claude/golden/example.md"
printf -- '---\nname: release\ndescription: x\n---\n' > "$R/.claude/skills/release/SKILL.md"
mkdir -p "$W/2-work/orders" && printf -- '---\nkind: repo\n---\n# Orders\n- Repo: `%s`\n' "$R" > "$W/2-work/orders/README.md"
printf -- '---\nupdated: %s\n---\n# s\n' "$D" > "$W/2-work/orders/state.md"
sed -i.bak "s/updated: YYYY-MM-DD/updated: $D/" "$W/NOW.md" && sed -i.bak "s/^owner: TODO-your-name/owner: demo/" "$W/0-meta/kb.yaml"
printf -- '- Role: dev\n- Stack: py\n- Ask before schema changes\n' >> "$W/1-me/profile.md"
mkdir -p "$TMP/home/.claude" && printf '{"permissions":{"disableBypassPermissionsMode":"disable"}}' > "$TMP/home/.claude/settings.json"
find "$W" -name '*.bak' -delete
compare filled "$W"
rm -rf "$TMP/home/.claude"

copy "$TMP/bad"; B=$TMP/bad
printf 'token = "%s"\n' "ghp_$(printf 'b%.0s' $(seq 1 36))" > "$B/1-me/leak.md"
printf 'nice\342\200\213sneaky\nsee [x](missing.md)\n' > "$B/1-me/sneaky.md"
printf -- '---\nname: wrong-name\n---\n' > "$B/.claude/skills/kb-tidy/SKILL.md"
mkdir -p "$B/2-work/old" && printf -- '---\nupdated: 2020-01-01\n---\n' > "$B/2-work/old/state.md"
compare bad "$B"

echo "kb_check twins: $pass identical, $fail different"
[ "$fail" = 0 ]
