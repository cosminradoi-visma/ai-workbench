#!/usr/bin/env python3
"""UserPromptSubmit guard for Claude Code. Standard library only.

Stops a prompt before it reaches the model if it contains something that looks like a
secret (API tokens, private keys, passwords in connection strings) or a real IBAN
(checksum-validated, so random digits don't trigger it).

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
IBAN = re.compile(r"\b([A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?)\b")


def valid_iban(raw):
    s = raw.replace(" ", "")
    if not 15 <= len(s) <= 34:
        return False
    digits = "".join(str(int(c, 36)) for c in s[4:] + s[:4])
    return int(digits) % 97 == 1


def main():
    try:
        prompt = json.load(sys.stdin).get("prompt", "")
    except ValueError:
        sys.exit(0)
    if prompt.lstrip().lower().startswith("synthetic:"):
        sys.exit(0)
    found = [label for pattern, label in PATTERNS if re.search(pattern, prompt)]
    if any(valid_iban(m.group(1)) for m in IBAN.finditer(prompt)):
        found.append("a valid IBAN")
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
    main()
