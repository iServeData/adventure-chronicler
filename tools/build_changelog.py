#!/usr/bin/env python3
"""Builds CHANGELOG.md from changelog.toml, the one place changes are written down.

The layout of each entry follows the QuestersBoard changelog: a version with its date and headline, then one
line per change tagged New, Improved or Fixed and the part of the add-on it touches.

Run: python3 tools/build_changelog.py          (writes CHANGELOG.md)
     python3 tools/build_changelog.py --check  (fails if CHANGELOG.md is out of date or changelog.toml is invalid)
"""
import os
import re
import sys
import tomllib
from datetime import date

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "changelog.toml")
OUT = os.path.join(ROOT, "CHANGELOG.md")
AREAS = ("Recorder", "Notes", "Screenshots", "Review", "Export", "Windows", "Settings")
KINDS = {"new": "New", "improved": "Improved", "fixed": "Fixed"}
STATUSES = {"prototype": "prototype, unreleased", "released": "released"}
VERSION = re.compile(r"\d+\.\d+\.\d+")


def load(text):
    releases = tomllib.loads(text).get("release", [])
    seen = set()
    out = []
    for r in releases:
        v = str(r.get("version", ""))
        if not VERSION.fullmatch(v) or v in seen:
            raise ValueError(f"changelog: each release needs a new version X.Y.Z (got {v!r})")
        seen.add(v)
        d = r.get("date")
        d = d if isinstance(d, date) else date.fromisoformat(str(d))
        if r.get("status") not in STATUSES:
            raise ValueError(f"changelog {v}: status must be one of {tuple(STATUSES)}")
        title = str(r.get("title", "")).strip()
        if not title:
            raise ValueError(f"changelog {v}: a release needs a title")
        changes = r.get("change", [])
        if not changes:
            raise ValueError(f"changelog {v}: a release needs at least one change")
        for c in changes:
            if c.get("area") not in AREAS or c.get("kind") not in KINDS or not str(c.get("text", "")).strip():
                raise ValueError(f"changelog {v}: each change needs an area {AREAS}, a kind {tuple(KINDS)} and text")
        out.append({"version": v, "date": d, "title": title, "status": r["status"], "changes": changes})
    key = [tuple(int(x) for x in r["version"].split(".")) for r in out]
    if key != sorted(key, reverse=True):
        raise ValueError("changelog: list releases newest version first")
    return out


def markdown(releases):
    lines = ["# Changelog", "", "Built from `changelog.toml` by `tools/build_changelog.py`; edit that file, not this one.", ""]
    for r in releases:
        lines += [f"## {r['version']} · {r['date'].isoformat()} · {r['title']} ({STATUSES[r['status']]})", ""]
        for c in r["changes"]:
            lines.append(f"- **{KINDS[c['kind']]}** ({c['area']}): {c['text'].strip()}")
        lines.append("")
    return "\n".join(lines)


def main(argv):
    with open(SRC, encoding="utf-8") as f:
        text = markdown(load(f.read()))
    if "--check" in argv:
        try:
            with open(OUT, encoding="utf-8") as f:
                current = f.read()
        except OSError:
            current = None
        if current != text:
            print("CHANGELOG.md is out of date: run python3 tools/build_changelog.py", file=sys.stderr)
            return 1
        print("CHANGELOG.md is up to date")
        return 0
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote CHANGELOG.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
