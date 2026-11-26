#!/usr/bin/env python3
"""Builds dist/AdventureChronicler-<version>.zip containing only the addon folder.

The zip is reproducible (fixed timestamps, sorted entries) and contains no tests, tools or docs.
Version is read from the .toc file.

A community's own build:  python3 tools/build_zip.py --community PATH/community.toml
The file is kept outside the repository. Its values replace the empty ones in core/community.lua inside the
zip only (the repository copy is never changed):

    name = "Example Community"
    invite = "https://example.com/invite"
    import_url = "https://example.com/wow/quester/chronicle/import"
    board_url = "https://example.com/wow/quester"
    # Optional. Hosts that must not appear anywhere in the zip (for example a long domain that should only be
    # shown through a short one). The build stops if any file in the zip mentions one.
    forbid_hosts = ["example.org"]
"""
import os
import re
import sys
import tomllib
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ADDON = os.path.join(ROOT, "addon", "AdventureChronicler")
TOC = os.path.join(ADDON, "AdventureChronicler.toc")
ALLOWED = (".lua", ".toc", ".xml", ".md", ".txt", ".tga", ".blp")
COMMUNITY_FILE = "AdventureChronicler/core/community.lua"
COMMUNITY_KEYS = ("name", "invite", "import_url", "board_url")
URL = re.compile(r"^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[A-Za-z0-9._~/%-]*)?$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9 ._'&-]{1,40}$")


def community_lua(path, template):
    """core/community.lua with the community's values filled in. Raises ValueError on anything unexpected."""
    with open(path, "rb") as fh:
        cfg = tomllib.load(fh)
    unknown = set(cfg) - set(COMMUNITY_KEYS) - {"forbid_hosts"}
    if unknown:
        raise ValueError(f"community file: unknown keys {sorted(unknown)}")
    out = template
    for key in COMMUNITY_KEYS:
        value = str(cfg.get(key, "")).strip()
        if value:
            ok = SAFE_NAME.match(value) if key == "name" else (URL.match(value) and len(value) <= 200)
            if not ok:
                raise ValueError(f"community file: {key} must be " + ("a plain name" if key == "name" else
                                 "a plain https:// address"))
        line = re.compile(rf'^(  {key} = )"[^"]*"', re.M)
        if not line.search(out):
            raise ValueError(f"core/community.lua has no {key} line")
        out = line.sub(lambda m: m.group(1) + '"' + value + '"', out, count=1)
    forbid = [str(h).lower() for h in cfg.get("forbid_hosts", [])]
    return out, forbid


def main(argv) -> int:
    community = None
    if "--community" in argv:
        i = argv.index("--community")
        if i + 1 >= len(argv):
            print("--community needs a file", file=sys.stderr)
            return 1
        community = argv[i + 1]
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
    contents = {}
    for rel, full in entries:
        with open(full, "rb") as fh:
            contents[rel] = fh.read()
    forbid = []
    if community:
        try:
            filled, forbid = community_lua(community, contents[COMMUNITY_FILE].decode("utf-8"))
        except (OSError, ValueError, tomllib.TOMLDecodeError) as e:
            print(f"community build stopped: {e}", file=sys.stderr)
            return 1
        contents[COMMUNITY_FILE] = filled.encode("utf-8")
    for rel, data in contents.items():
        low = data.lower()
        for host in forbid:
            if host.encode() in low:
                print(f"community build stopped: {rel} mentions a forbidden host", file=sys.stderr)
                return 1
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(contents):
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, contents[rel])
    kind = " (community build)" if community else ""
    print(f"wrote {os.path.relpath(out, ROOT)} ({len(entries)} files){kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
