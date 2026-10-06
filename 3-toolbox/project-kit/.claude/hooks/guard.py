#!/usr/bin/env python3
"""PreToolUse guard for Claude Code. Standard library only.

  DENY (exit 2, reason goes to the model): secret files, force-push to protected branches,
       --no-verify, pipe-to-shell, uploading files with curl, destructive SQL, rm -rf on / or ~.
  ASK  (JSON permissionDecision "ask"): installing named packages (slopsquatting check),
       sudo, and edits to files that change how agents behave in this repo.
  STOP anyone can stop every agent in this repo: `touch .claude/STOP`. Remove it to resume.
  UNATTENDED (only if .claude/unattended.json exists, for bots and scheduled runs):
       - private_paths: never read (a bot answers from the repo half, never your 1-me/ or NOW.md)
       - send_tools + max_sends_per_hour: a post budget on the tools that talk to people

Short and readable on purpose: extend the lists for your repo. A hook is one layer, not
the wall. See 3-toolbox/safety.md. If the input can't be parsed, it allows the call
(fail-open), so the agent never gets stuck on a broken hook.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import time

SECRET_PATH = (
    r"(\.env(\.(?!example\b|sample\b|template\b|dist\b)[\w-]+)*(?=$|[\s'\"/;|&)])"
    r"|\bid_(rsa|ed25519|ecdsa)\b|\.pem\b|\.pfx\b|\.p12\b|\.key\b"
    r"|\.aws/credentials|\.kube/config|\.npmrc\b|\.pypirc\b|\.netrc\b|\.claude\.json\b"
    r"|\bcredentials\.json\b|\bsecrets?\.(json|ya?ml)\b)"
)
READERS = r"\b(cat|less|more|head|tail|bat|nl|strings|xxd|od|base64|grep|egrep|rg|awk|sed|cp|mv|scp|rsync|tar|zip|type|get-content|source)\b"
PROTECTED = r"\b(main|master|prod\w*|release\w*)\b"

DENY_BASH = [
    (READERS + r"[^|;&]*" + SECRET_PATH, "reading or copying a secrets file"),
    (r"\bgit\s+push\b(?=.*(--force(?!-with-lease)|\s-f\b|\s\+))(?=.*" + PROTECTED + ")", "force-push to a protected branch"),
    (r"\bgit\s+(commit|push|merge|rebase)\b.*--no-verify\b", "skipping git hooks with --no-verify"),
    (r"\b(curl|wget|iwr|invoke-webrequest)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh|python3?|node|iex)\b", "piping a download into a shell"),
    (r"\bcurl\b.*(\s(-d|--data(-binary|-raw|-urlencode)?|-F|--form)\s*['\"]?([\w.\[\]-]+=)?@|\s(-T|--upload-file)\s)", "uploading a local file with curl"),
    (r"\b(drop\s+(database|schema|table)|truncate\s+table)\b", "destructive SQL"),
    (r"\brm\s+(-[a-z]*r[a-z]*f?|-[a-z]*f[a-z]*r)[a-z]*\s+(/|~|\$HOME|\.\.)(/\*?)?(\s|$)", "recursive delete of /, ~ or a parent folder"),
]
ASK_BASH = [
    (r"\b(npm|pnpm|yarn|bun)\s+(i|install|add)\s+(?!-)[@\w]", "installs a named package"),
    (r"\b(pip3?|uv\s+pip)\s+install\s+(?!-r\b|-e\b|\.)[\w]", "installs a named package"),
    (r"\b(uv|poetry|cargo)\s+add\s+\w|\bgo\s+get\s+\w|\bdotnet\s+add\s+(\S+\s+)?package\b", "installs a named package"),
    (r"(^|[;&|]\s*)sudo\b", "runs with sudo"),
]
AGENT_CONFIG = re.compile(
    r"(^|[\\/])(\.claude[\\/](settings[\w.]*\.json|hooks[\\/]|skills[\\/]|agents[\\/]|rules[\\/]|golden[\\/]|unattended\.json$)"
    r"|\.mcp\.json$|\.cursor[\\/]|\.github[\\/](workflows|hooks)[\\/]|CLAUDE(\.local)?\.md$|AGENTS\.md$)"
)


def deny(reason):
    print(f"Blocked by .claude/hooks/guard.py: {reason}. If it is really needed, ask the user to run it themselves.", file=sys.stderr)
    sys.exit(2)


def ask(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": f"guard.py: {reason}",
    }}))
    sys.exit(0)


def main_checkout(project):
    """Bots run in git worktrees. STOP and the post budget live in the MAIN checkout,
    so stopping the repo stops every worktree, and the budget is per repo, not per thread."""
    try:
        common = subprocess.run(["git", "-C", str(project), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return project
    return pathlib.Path(common).parent if common.endswith(".git") else project


def unattended(project, tool, args):
    try:
        cfg = json.loads((project / ".claude" / "unattended.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    text = " ".join(str(v) for v in args.values())
    for raw in cfg.get("private_paths", []):
        full = os.path.expanduser(raw).rstrip("/")
        if full and (full in text or raw.rstrip("/") in text):
            deny(f"{raw} is private: an unattended agent answers from this repo only")
    send = cfg.get("send_tools")
    if send and re.search(send, tool, re.I):
        limit = int(cfg.get("max_sends_per_hour", 10))
        log = main_checkout(project) / ".claude" / "state" / "sends.log"
        now = time.time()
        try:
            recent = [float(t) for t in log.read_text().split() if now - float(t) < 3600]
        except (OSError, ValueError):
            recent = []
        if len(recent) >= limit:
            deny(f"post budget reached: {limit} sends in the last hour")
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(" ".join(str(t) for t in recent + [now]))


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        sys.exit(0)
    tool = event.get("tool_name", "")
    args = event.get("tool_input") or {}
    project = pathlib.Path(os.environ.get("CLAUDE_PROJECT_DIR") or event.get("cwd") or ".")
    if any((p / ".claude" / "STOP").exists() for p in {project, main_checkout(project)}):
        deny("this repo is stopped (.claude/STOP exists). Remove that file to resume")
    unattended(project, tool, args)

    if tool == "Bash":
        cmd = args.get("command", "")
        for pattern, reason in DENY_BASH:
            if re.search(pattern, cmd, re.I):
                deny(reason)
        for pattern, reason in ASK_BASH:
            if re.search(pattern, cmd, re.I):
                if "package" in reason:
                    reason += ": check it exists, is the one you meant, and isn't brand new (models invent package names)"
                ask(reason)
    elif tool in ("Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "Grep"):
        path = args.get("file_path") or args.get("notebook_path") or args.get("path") or ""
        if re.search(SECRET_PATH + r"$", path, re.I):
            deny(f"access to a secrets file ({path})")
        if tool != "Read" and tool != "Grep" and AGENT_CONFIG.search(path):
            ask(f"edits {path}, which changes how agents behave in this repo")
    sys.exit(0)


if __name__ == "__main__":
    main()
