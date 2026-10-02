#!/usr/bin/env python3
"""PreToolUse guard for Claude Code. Standard library only.

  DENY (exit 2, reason goes to the model): secret files, force-push to protected branches,
       --no-verify, pipe-to-shell, uploading files with curl, destructive SQL, rm -rf on / or ~.
  ASK  (JSON permissionDecision "ask"): installing named packages (slopsquatting check),
       sudo, and edits to files that change how agents behave in this repo.

Short and readable on purpose: extend the lists for your repo. A hook is one layer, not
the wall. See 3-toolbox/safety.md. If the input can't be parsed, it allows the call
(fail-open), so the agent never gets stuck on a broken hook.
"""
import json
import re
import sys

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
    (r"\bcurl\b.*(\s-d|\s--data(-binary|-raw)?|\s-F|\s--form|\s-T|\s--upload-file)\s*['\"]?@", "uploading a local file with curl"),
    (r"\b(drop\s+(database|schema|table)|truncate\s+table)\b", "destructive SQL"),
    (r"\brm\s+(-[a-z]*r[a-z]*f?|-[a-z]*f[a-z]*r)[a-z]*\s+(/|~|\$HOME|\.\.)(/\*?)?(\s|$)", "recursive delete of /, ~ or a parent folder"),
]
ASK_BASH = [
    (r"\b(npm|pnpm|yarn|bun)\s+(i|install|add)\s+(?!-)[@\w]", "installs a named package"),
    (r"\b(pip3?|uv\s+pip)\s+install\s+(?!-r\b|-e\b|\.)[\w]", "installs a named package"),
    (r"\b(uv|poetry|cargo)\s+add\s+\w|\bgo\s+get\s+\w|\bdotnet\s+add\s+\S+\s+package\b", "installs a named package"),
    (r"(^|[;&|]\s*)sudo\b", "runs with sudo"),
]
AGENT_CONFIG = re.compile(
    r"(^|[\\/])(\.claude[\\/](settings[\w.]*\.json|hooks[\\/]|skills[\\/]|agents[\\/]|rules[\\/])"
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


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        sys.exit(0)
    tool = event.get("tool_name", "")
    args = event.get("tool_input") or {}

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
