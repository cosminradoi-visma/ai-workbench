# The fix_pr gate. The script runs these, never the model. Source after lib/common.sh.

# diffcap WT BASE: prints "N lines, M files"; returns 1 if over DIFF_MAX_LINES / DIFF_MAX_FILES.
diffcap() {
  _stat=$(git -C "$1" diff --numstat "$2" HEAD | awk '{ l += $1 + $2; f++ } END { printf "%d %d", l, f }')
  _lines=${_stat% *}
  _files=${_stat#* }
  echo "$_lines lines, $_files files (cap $DIFF_MAX_LINES / $DIFF_MAX_FILES)"
  [ "$_files" -gt 0 ] && [ "$_lines" -le "$DIFF_MAX_LINES" ] && [ "$_files" -le "$DIFF_MAX_FILES" ]
}

_in_list() { for _x in $2; do [ "$_x" = "$1" ] && return 0; done; return 1; }

# redgreen WT BASE TEST: the test must FAIL on BASE (with the branch's test files copied in)
# and PASS on HEAD, and the full suite must pass on HEAD. Prints one evidence line per check.
redgreen() {
  _wt=$1 _base=$2 _test=$3
  _file=${_test%%::*}
  _head=$(git -C "$_wt" rev-parse HEAD)
  if [ ! -f "$_wt/$_file" ]; then echo "failing test file $_file does not exist on head"; return 1; fi
  _changed=$(git -C "$_wt" diff --name-only "$_base" HEAD | grep -E '(^|/)tests?/|(^|/)test_[^/]*$|_test\.[A-Za-z]+$')
  if ! printf '%s\n' "$_changed" | grep -qxF "$_file"; then
    echo "failing test $_file is not added or changed by this branch"
    return 1
  fi
  _tmp=$(mktemp -d)
  git -C "$_wt" worktree add -q --detach "$_tmp/base" "$_base" >/dev/null 2>&1 || { echo "could not create base worktree"; rm -rf "$_tmp"; return 1; }
  for _f in $_changed; do
    [ -f "$_wt/$_f" ] && git -C "$_tmp/base" checkout -q "$_head" -- "$_f"
  done
  (cd "$_tmp/base" && sh -c "$TEST_CMD \"\$1\"" _ "$_test") >"$_tmp/red.log" 2>&1
  _rc_base=$?
  (cd "$_wt" && sh -c "$TEST_CMD \"\$1\"" _ "$_test") >"$_tmp/green.log" 2>&1
  _rc_head=$?
  (cd "$_wt" && sh -c "$TEST_ALL_CMD") >"$_tmp/all.log" 2>&1
  _rc_all=$?
  git -C "$_wt" worktree remove --force "$_tmp/base" >/dev/null 2>&1
  _short_base=$(git -C "$_wt" rev-parse --short "$_base")
  _short_head=$(git -C "$_wt" rev-parse --short HEAD)
  echo "red on base $_short_base: \`$TEST_CMD $_test\` exited $_rc_base ($(grep -E 'passed|failed|error' "$_tmp/red.log" | tail -1))"
  echo "green on head $_short_head: same command exited $_rc_head ($(grep -E 'passed|failed|error' "$_tmp/green.log" | tail -1))"
  echo "full suite on head: \`$TEST_ALL_CMD\` exited $_rc_all ($(grep -E 'passed|failed|error' "$_tmp/all.log" | tail -1))"
  rm -rf "$_tmp"
  _in_list "$_rc_base" "$RED_EXIT_CODES" && [ "$_rc_head" -eq 0 ] && [ "$_rc_all" -eq 0 ]
}
