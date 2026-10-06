#!/bin/sh
# All offline tests. No network, no model calls, no Slack. Exit 0 only if everything passes.
cd "$(dirname "$0")" || exit 1
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
rc=0
for t in test_hooks.sh test_watch.sh test_work.sh test_install.sh test_witness.sh test_selfdm.sh test_cleanup.sh; do
  echo "== $t"
  sh "$t" || rc=1
done
[ "$rc" = 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $rc
