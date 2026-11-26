#!/usr/bin/env python3
"""Builds CHANGELOG.md from changelog.toml, the one place changes are written down.

The layout of each entry follows the QuestersBoard changelog: a version with its date and headline, then one
line per change tagged New, Improved or Fixed and the part of the add-on it touches.

It also writes addon/AdventureChronicler/core/changelog_data.lua, which the add-on's What's new window reads,
so the window, CHANGELOG.md and the QuestersBoard add-on page always say the same thing.

Run: python3 tools/build_changelog.py          (writes CHANGELOG.md and changelog_data.lua)
     python3 tools/build_changelog.py --check  (fails if either is out of date or changelog.toml is invalid)
"""
import os
import re
import sys
import tomllib
from datetime import date

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "changelog.toml")
OUT = os.path.join(ROOT, "CHANGELOG.md")
LUA_OUT = os.path.join(ROOT, "addon", "AdventureChronicler", "core", "changelog_data.lua")
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


def lua_string(value):
    """A double-quoted Lua 5.1 string. Only backslash, quote and line breaks need escaping."""
    v = str(value).strip().replace("\\", "\\\\").replace('"', '\\"').replace("\r", "").replace("\n", "\\n")
    return f'"{v}"'


def lua(releases):
    lines = ["-- Adventure Chronicler: the changelog for the What's new window.",
             "-- Built from changelog.toml by tools/build_changelog.py; edit that file, not this one.",
             "local _, ns = ...", "ns = ns or {}", "", "ns.CHANGELOG = {"]
    for r in releases:
        lines.append(f"  {{ version = {lua_string(r['version'])}, date = {lua_string(r['date'].isoformat())}, "
                     f"status = {lua_string(STATUSES[r['status']])},")
        lines.append(f"    title = {lua_string(r['title'])},")
        lines.append("    changes = {")
        for c in r["changes"]:
            lines.append(f"      {{ kind = {lua_string(KINDS[c['kind']])}, area = {lua_string(c['area'])},")
            lines.append(f"        text = {lua_string(c['text'])} }},")
        lines.append("    },")
        lines.append("  },")
    lines += ["}", "", "return ns.CHANGELOG", ""]
    return "\n".join(lines)


def main(argv):
    with open(SRC, encoding="utf-8") as f:
        releases = load(f.read())
    outputs = [(OUT, markdown(releases)), (LUA_OUT, lua(releases))]
    if "--check" in argv:
        stale = []
        for path, text in outputs:
            try:
                with open(path, encoding="utf-8") as f:
                    current = f.read()
            except OSError:
                current = None
            if current != text:
                stale.append(os.path.relpath(path, ROOT))
        if stale:
            print(f"{', '.join(stale)} out of date: run python3 tools/build_changelog.py", file=sys.stderr)
            return 1
        print("CHANGELOG.md and changelog_data.lua are up to date")
        return 0
    for path, text in outputs:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"wrote {os.path.relpath(path, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
