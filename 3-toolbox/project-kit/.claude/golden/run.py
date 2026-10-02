#!/usr/bin/env python3
"""Golden tasks: does the agent actually do good work in this repo?

Each task in .claude/golden/*.md is a real, small job with a check the agent can't
influence. The runner gives every task a clean throwaway checkout (a git worktree of
HEAD), runs Claude headless on it, then runs the check. You get a pass count and what
it cost. Run it after you change AGENTS.md, a skill, a rule or the model.

    python3 .claude/golden/run.py            run every task
    python3 .claude/golden/run.py refund     only tasks whose name contains "refund"
    python3 .claude/golden/run.py --list     show tasks, run nothing
    python3 .claude/golden/run.py --keep     keep the worktrees to inspect what it did

A task file:

    ---
    check: npm test -- refund          # exit 0 = pass. Runs after the agent, in its checkout
    protect: test/**, *.snap           # the agent editing any of these = fail ("evidence it can't edit")
    max_turns: 15
    tools: Read,Edit,Write,Grep,Glob,Bash(npm test *)
    ---
    Reject refunds larger than the order total with a 422, and add a test.

Standard library only. Needs git and the claude CLI. Costs real tokens: start with three tasks.
"""
import fnmatch
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_TOOLS = "Read,Edit,Write,Grep,Glob"
TIMEOUT = 900  # seconds per task


def parse(path):
    text = path.read_text(encoding="utf-8")
    meta, body = {}, text
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if m:
        body = m.group(2)
        for line in m.group(1).splitlines():
            k, _, v = line.partition(":")
            if k.strip():
                meta[k.strip()] = re.sub(r"\s+#.*$", "", v).strip()
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S).strip()
    return meta, body


def sh(cmd, cwd, timeout=TIMEOUT):
    return subprocess.run(cmd, cwd=cwd, shell=isinstance(cmd, str), capture_output=True, text=True, timeout=timeout)


def run_task(root, path, keep):
    meta, prompt = parse(path)
    name = path.stem
    if not meta.get("check") or not prompt:
        return {"name": name, "ok": False, "why": "task needs a 'check:' and a prompt", "cost": 0, "turns": 0, "secs": 0}
    work = pathlib.Path(tempfile.mkdtemp(prefix=f"golden-{name}-"))
    shutil.rmtree(work)
    sh(["git", "worktree", "add", "--detach", "--quiet", str(work), "HEAD"], root)
    started = time.time()
    result = {"name": name, "ok": False, "why": "", "cost": 0.0, "turns": 0}
    try:
        cmd = ["claude", "-p", prompt, "--output-format", "json", "--permission-mode", "acceptEdits",
               "--max-turns", str(meta.get("max_turns", "15")), "--allowedTools", meta.get("tools", DEFAULT_TOOLS)]
        run = sh(cmd, work)
        try:
            out = json.loads(run.stdout)
        except ValueError:
            out = {}
        result["cost"] = float(out.get("total_cost_usd") or 0)
        result["turns"] = int(out.get("num_turns") or 0)
        if out.get("is_error") or out.get("subtype") not in (None, "success"):
            result["why"] = f"agent stopped: {out.get('subtype', 'no output')}"
        changed = sh(["git", "status", "--porcelain"], work).stdout.splitlines()
        changed = [line[3:].strip() for line in changed]
        protected = [g.strip() for g in meta.get("protect", "").split(",") if g.strip()]
        touched = [f for f in changed if any(fnmatch.fnmatch(f, g) for g in protected)]
        if touched:
            result["why"] = f"edited protected file(s): {', '.join(touched[:3])}"
        elif not result["why"]:
            check = sh(meta["check"], work)
            result["ok"] = check.returncode == 0
            if not result["ok"]:
                tail = (check.stdout + check.stderr).strip().splitlines()[-1:] or ["(no output)"]
                result["why"] = f"check failed: {tail[0][:80]}"
    except subprocess.TimeoutExpired:
        result["why"] = f"timed out after {TIMEOUT}s"
    finally:
        result["secs"] = round(time.time() - started)
        if keep:
            result["why"] = (result["why"] + f" (kept: {work})").strip()
        else:
            sh(["git", "worktree", "remove", "--force", str(work)], root)
    return result


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keep, listing = "--keep" in sys.argv, "--list" in sys.argv
    root = pathlib.Path(sh(["git", "rev-parse", "--show-toplevel"], HERE).stdout.strip() or ".")
    tasks = sorted(p for p in HERE.glob("*.md") if p.name.lower() != "readme.md")
    if args:
        tasks = [t for t in tasks if any(a in t.stem for a in args)]
    if not tasks:
        print("No golden tasks yet. Copy .claude/golden/example.md and make it real.")
        return 1
    if listing:
        for t in tasks:
            print(f"  {t.stem:<28} check: {parse(t)[0].get('check', '?')}")
        return 0
    if sh(["git", "status", "--porcelain"], root).stdout.strip():
        print("Note: uncommitted changes are NOT in the runs. Tasks run against HEAD.\n")
    results = []
    for t in tasks:
        print(f"  … {t.stem}", flush=True)
        results.append(run_task(root, t, keep))
    passed = sum(r["ok"] for r in results)
    cost = sum(r["cost"] for r in results)
    print(f"\n  {'task':<28} {'result':<6} {'turns':>5} {'cost':>7} {'time':>6}")
    for r in results:
        print(f"  {r['name']:<28} {'pass' if r['ok'] else 'FAIL':<6} {r['turns']:>5} {'$%.2f' % r['cost']:>7} {r['secs']:>5}s  {r['why']}")
    per = f" · ${cost / passed:.2f} per pass" if passed else ""
    print(f"\n  {passed}/{len(results)} passed · ${cost:.2f} total{per}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
