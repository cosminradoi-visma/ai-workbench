#!/bin/sh
# Runs the golden tasks on whatever this laptop has (Python, else the Perl twin run.pl):
#   sh .claude/golden/run.sh            every task
#   sh .claude/golden/run.sh refund     only tasks whose name contains "refund"
#   sh .claude/golden/run.sh --list     show tasks, run nothing
#   sh .claude/golden/run.sh --keep     keep the worktrees to inspect what it did
d=$(dirname "$0")
exec sh "$d/../hooks/py" "$d/run.py" "$@"
