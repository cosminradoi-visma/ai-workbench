#!/usr/bin/env python3
"""UserPromptSubmit guard for Claude Code. Standard library only.

Stops a prompt before it reaches the model if it contains something that looks like a
secret (API tokens, private keys, passwords in connection strings), a real IBAN or a Romanian
CNP (both checksum-validated, so random digits don't trigger it).

Test data on purpose? Start the prompt with "synthetic:" and it passes. Extend PATTERNS
with the identifiers your product handles (national ID formats, customer numbers).
"""
import json
import re
import sys

PATTERNS = [
    (r"AKIA[0-9A-Z]{16}", "an AWS access key"),
    (r"gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}", "a GitHub token"),
    (r"sk-(ant-)?[A-Za-z0-9_-]{20,}", "an API key"),
    (r"xox[abprs]-[A-Za-z0-9-]{10,}", "a Slack token"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "a private key"),
    (r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}", "a JWT"),
    (r"(?i)(postgres(ql)?|mysql|mongodb(\+srv)?|sqlserver|redis|amqp)://[^\s:/@]+:[^\s@]+@", "a connection string with a password"),
    (r"(?i)(AccountKey|SharedAccessSignature|Password|Pwd)=[^;\s]{8,}", "a connection string secret"),
]
CNP = re.compile(r"\b([1-9]\d{12})\b")  # Romanian personal numeric code (CNP)
SYNTHETIC = re.compile(r"[ \t\r\n]*synthetic:", re.I | re.A)  # ASCII only, same as the .pl twin
IBAN = re.compile(r"\b([A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?)\b")


def valid_iban(raw):
    s = raw.replace(" ", "")
    if not 15 <= len(s) <= 34:
        return False
    digits = "".join(str(int(c, 36)) for c in s[4:] + s[:4])
    return int(digits) % 97 == 1


def valid_cnp(s):
    weights = "279146358279"
    total = sum(int(d) * int(w) for d, w in zip(s[:12], weights))
    check = total % 11
    month, day = int(s[3:5]), int(s[5:7])
    return (1 if check == 10 else check) == int(s[12]) and 1 <= month <= 12 and 1 <= day <= 31


def no_constants(name):
    raise ValueError(f"{name} is not JSON")  # NaN, Infinity: Python accepts them, JSON (and the .pl twin) do not


def main():
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # Windows would use cp1252
    raw = sys.stdin.buffer.read()
    try:
        event = json.loads(raw.decode("utf-8", "replace"), parse_constant=no_constants)
    except ValueError:
        if raw.lstrip().startswith(b"{"):
            print("Prompt not sent: the prompt guard could not read it (malformed input). Try again.", file=sys.stderr)
            sys.exit(2)
        sys.exit(0)
    prompt = event.get("prompt") if isinstance(event, dict) else None
    if not isinstance(prompt, str):
        sys.exit(0)
    if SYNTHETIC.match(prompt):
        sys.exit(0)
    found = [label for pattern, label in PATTERNS if re.search(pattern, prompt)]
    if any(valid_iban(m.group(1)) for m in IBAN.finditer(prompt)):
        found.append("a valid IBAN")
    if any(valid_cnp(m.group(1)) for m in CNP.finditer(prompt)):
        found.append("a Romanian personal numeric code (CNP)")
    if found:
        print(
            f"Prompt not sent: it contains what looks like {', '.join(found)}. "
            "Remove it, or use synthetic data. If this is test data on purpose, start the prompt with 'synthetic:'. "
            "If a real secret was pasted anywhere, rotate it.",
            file=sys.stderr,
        )
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # say so, but don't lock the user out of prompting (exit 1 is shown, not blocking)
        print(f"prompt_guard.py failed ({type(exc).__name__}: {exc}): this prompt was NOT checked.", file=sys.stderr)
        sys.exit(1)
