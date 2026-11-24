#!/usr/bin/env python3
"""Builds dist/AdventureChronicler-<version>.zip containing only the addon folder.

The zip is reproducible (fixed timestamps, sorted entries) and contains no tests, tools or docs.
Version is read from the .toc file.
"""
import os
import re
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ADDON = os.path.join(ROOT, "addon", "AdventureChronicler")
TOC = os.path.join(ADDON, "AdventureChronicler.toc")
ALLOWED = (".lua", ".toc", ".xml", ".md", ".txt", ".tga", ".blp")


def main() -> int:
    with open(TOC, encoding="utf-8") as fh:
        toc = fh.read()
    m = re.search(r"^## Version: (\S+)", toc, re.M)
    if not m:
        print("no version in .toc", file=sys.stderr)
        return 1
    listed = {ln.strip().replace("\\", "/") for ln in toc.splitlines() if ln.strip() and not ln.startswith("#")}
    for f in listed:
        if not os.path.isfile(os.path.join(ADDON, f)):
            print(f".toc lists a missing file: {f}", file=sys.stderr)
            return 1
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", f"AdventureChronicler-{m.group(1)}.zip")
    entries = []
    for dirpath, _, names in os.walk(ADDON):
        for n in names:
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, os.path.dirname(ADDON)).replace(os.sep, "/")
            if n.endswith(ALLOWED):
                entries.append((rel, full))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, full in sorted(entries):
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())
    print(f"wrote {os.path.relpath(out, ROOT)} ({len(entries)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
