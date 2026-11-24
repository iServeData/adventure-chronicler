#!/usr/bin/env python3
"""Repository hygiene check: looks for secrets and identifying details before they are committed.

Checks every tracked file (or the files given) for:
  * credential patterns (tokens, private keys, secret-bearing URLs)
  * Discord-style IDs (17-20 digit numbers), IPv4 addresses outside documentation ranges
  * email addresses other than example/noreply addresses
  * terms from an optional PRIVATE blocklist kept outside the repository, one term per line,
    given with --blocklist PATH or the AC_HYGIENE_BLOCKLIST environment variable

Exits 1 if anything is found. The blocklist's contents are never printed.
"""
from __future__ import annotations

import ipaddress
import os
import re
import subprocess
import sys

PATTERNS = {
    "private key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "GitHub token": re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b"),
    "Discord bot token": re.compile(r"\b[MNO][A-Za-z0-9_-]{23,25}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}\b"),
    "Discord webhook": re.compile(r"discord(?:app)?\.com/api/webhooks/\d+/[\w-]+", re.I),
    "AWS key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "Slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    "Blizzard/OAuth client secret": re.compile(r"client_secret\s*[:=]\s*['\"]?[A-Za-z0-9]{16,}", re.I),
    "password assignment": re.compile(r"\b(password|passwd|secret|api_key|token)\s*[:=]\s*['\"][^'\"\s]{8,}['\"]",
                                      re.I),
    "credentials in URL": re.compile(r"[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@", re.I),
    "Discord-style ID": re.compile(r"(?<![\d.])\d{17,20}(?![\d.])"),
}
IPV4 = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(?![\d.])")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
ALLOWED_EMAIL = re.compile(r"(@example\.(com|org|net)$|noreply|no-reply)", re.I)
DOC_NETS = [ipaddress.ip_network(n) for n in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24",
                                               "127.0.0.0/8", "0.0.0.0/8")]
SKIP_SUFFIXES = (".png", ".jpg", ".jpeg", ".gif", ".zip", ".tga", ".blp")
SELF = os.path.relpath(__file__)


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], check=True, capture_output=True).stdout
    return [p for p in out.decode().split("\0") if p]


def load_blocklist(path: str | None) -> list[str]:
    if not path:
        return []
    with open(path, encoding="utf-8") as fh:
        return [ln.strip().lower() for ln in fh if ln.strip() and not ln.startswith("#")]


def scan(path: str, text: str, blocklist: list[str]) -> list[str]:
    problems = []
    for n, line in enumerate(text.splitlines(), 1):
        if "hygiene: allow" in line:
            continue
        for name, rx in PATTERNS.items():
            if path == SELF and name != "private key":
                continue
            if rx.search(line):
                problems.append(f"{path}:{n}: possible {name}")
        for m in IPV4.finditer(line):
            try:
                ip = ipaddress.ip_address(m.group(1))
            except ValueError:
                continue
            if not any(ip in net for net in DOC_NETS):
                problems.append(f"{path}:{n}: IP address outside documentation ranges")
        for m in EMAIL.finditer(line):
            if not ALLOWED_EMAIL.search(m.group(0)):
                problems.append(f"{path}:{n}: email address")
        low = line.lower()
        for i, term in enumerate(blocklist, 1):
            if term in low:
                problems.append(f"{path}:{n}: matches private blocklist entry #{i}")
    return problems


def main(argv: list[str]) -> int:
    bl_path = os.environ.get("AC_HYGIENE_BLOCKLIST")
    if "--blocklist" in argv:
        i = argv.index("--blocklist")
        bl_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    blocklist = load_blocklist(bl_path)
    files = argv or tracked_files()
    problems = []
    for p in files:
        if p.lower().endswith(SKIP_SUFFIXES) or not os.path.isfile(p):
            continue
        with open(p, "rb") as fh:
            data = fh.read()
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            problems.append(f"{p}: not UTF-8 text")
            continue
        problems += scan(p, text, blocklist)
    for pr in problems:
        print(pr)
    print(f"hygiene: {len(files)} files checked, {len(problems)} problem(s)"
          + (f", private blocklist of {len(blocklist)} terms" if blocklist else ", no private blocklist"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
