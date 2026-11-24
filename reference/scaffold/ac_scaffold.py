#!/usr/bin/env python3
"""Deterministic story scaffold for a validated Adventure Chronicler export.

Turns the timeline into a starting draft shaped like a QuestersBoard Chronicle entry. It uses no
AI service and invents nothing: no dialogue, feelings, loot, companions or victories. Anything the
recording does not show stays a bracketed placeholder for the author to fill in. Outcome is always
"unknown" until the author chooses one. The same input always produces the same output.

Usage:
    python3 ac_scaffold.py FILE [--format md|txt|html|json]
"""
from __future__ import annotations

import datetime as _dt
import html
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "validator"))
from ac_validate import ValidationError, validate  # noqa: E402

FIELD_MAX = 8000  # QuestersBoard max_body_chars, applied to every long field
TITLE_MIN, TITLE_MAX = 3, 140

PLACEHOLDER_PLAN = "[What did you set out to do?]"
PLACEHOLDER_STORY = "[Tell the story in your own words. Who was with you, what it felt like, what you'd remember.]"
PLACEHOLDER_MOMENTS = "[Add the moments you want to remember.]"

CERTAINTY = {"confirmed": "", "seen": " (seen)", "inferred": " (probably)", "uncertain": " (uncertain)"}


def _clock(t: int) -> str:
    return _dt.datetime.fromtimestamp(t, _dt.timezone.utc).strftime("%H:%M")


def _day(t: int) -> str:
    return _dt.datetime.fromtimestamp(t, _dt.timezone.utc).strftime("%Y-%m-%d")


def _q(d):
    return d.get("title") or f"quest {d.get('quest_id', '?')}"


def _inst(d):
    return (d.get("instance") or {}).get("name") or d.get("name") or "an instance"


def describe(o: dict) -> str | None:
    """Plain wording for one observation. Mirrors addon/AdventureChronicler/core/describe.lua."""
    d, t = o["data"], o["type"]
    if t == "zone.enter":
        s = "Arrived in " + (d.get("zone") or d.get("map") or "an unknown place")
    elif t == "instance.enter":
        s = "Entered " + _inst(d)
    elif t == "instance.leave":
        s = "Left " + _inst(d)
    elif t == "encounter.start":
        return None  # the end of an encounter carries the result; starts would only add noise
    elif t == "encounter.end":
        r = {"success": "defeated", "wipe_or_reset": "not defeated (wipe or reset)"}.get(d.get("result"),
                                                                                         "result unknown")
        s = f"Encounter ended: {d.get('name') or 'unknown'}, {r}"
    elif t == "quest.rewards_offered":
        return None
    elif t == "quest.reward_selected":
        s = "Chose a reward: " + (d.get("name") or "unknown item")
    elif t == "quest.turned_in":
        s = "Turned in " + _q(d)
    elif t == "item.received":
        n = d.get("count_delta") or 1
        s = "Received " + (d.get("name") or f"item {d.get('item_id')}") + (f" x{n}" if n > 1 else "")
    elif t == "loot.seen":
        s = f"Loot window showed {len(d.get('items') or [])} item(s)"
    elif t == "pvp.battleground_enter":
        s = "Entered battleground " + (d.get("name") or "")
    elif t == "pvp.battleground_leave":
        s = "Left battleground " + (d.get("name") or "")
    elif t == "pvp.battleground_result":
        r = {"won": "won", "lost": "lost"}.get(d.get("outcome"), "result unknown")
        s = f"Battleground {d.get('name') or ''} ended: {r}"
    elif t == "player.death":
        s = "You died"
    else:  # markers are shown as moments instead
        return None
    s = s.strip() + CERTAINTY.get(o["certainty"], "")
    if o.get("repeats"):
        s += f" (repeated {o['repeats']} more times)"
    return s


def _fit(lines: list[str], what: str, limit: int = FIELD_MAX) -> str:
    """Join lines; if they don't fit, keep whole lines and say exactly how many were left out."""
    text = "\n".join(lines)
    if len(text) <= limit:
        return text
    kept = []
    for i, line in enumerate(lines):
        rest = len(lines) - i
        tail = f"[...and {rest} more {what} not shown here; they are still in the export.]"
        candidate = "\n".join(kept + [line])
        if len(candidate) + 1 + len(tail) > limit:
            return "\n".join(kept + [tail])
        kept.append(line)
    return "\n".join(kept)


def suggest_activity(doc: dict) -> str:
    """A suggestion only; the author picks the activity type on the import form."""
    types = {o["type"] for o in doc["observations"]}
    kinds = {(o["data"].get("instance") or {}).get("type") for o in doc["observations"]
             if o["type"] == "instance.enter"}
    if "pvp.battleground_enter" in types:
        return "battleground"
    if "raid" in kinds:
        return "raid"
    if "party" in kinds:
        return "dungeon"
    if "quest.turned_in" in types:
        return "quest"
    return "custom"


def scaffold(doc: dict) -> dict:
    s = doc["session"]
    title = (s["title"] or "").strip() or f"Adventure on {_day(s['started_at'])}"
    title = title[:TITLE_MAX]
    if len(title) < TITLE_MIN:
        title = f"Adventure on {_day(s['started_at'])}"

    happened = []  # (time, order, line): gaps sort before events at the same second
    for seg in s["segments"]:
        if seg["kind"] == "gap" and seg["reason"] != "reload":
            happened.append((seg["start"], 0, f"- {_clock(seg['start'])}  [Recording stopped here until "
                             f"{_clock(seg['finish'])}; what happened in between is not known.]"))
    for o in doc["observations"]:
        line = describe(o)
        if line:
            happened.append((o["t"], 1, f"- {_clock(o['t'])}  {line}"))
    happened.sort(key=lambda x: (x[0], x[1]))
    events = [h[2] for h in happened]
    if not events:
        events = ["[The recording has no events. Describe what happened.]"]
    if doc["integrity"]["observations_dropped"]:
        events.append(f"[{doc['integrity']['observations_dropped']} later events were not kept because the "
                      "session was full.]")

    moments, notes = [], []
    for n in doc["author"]["notes"]:
        if n["kind"] == "bookmark":
            moments.append(f"- {_clock(n['t'])}  {n['text'] or '[Bookmark: what happened here?]'}")
        else:
            notes.append(n["text"])
    for o in doc["observations"]:
        if o["type"] == "marker.screenshot" and o["data"].get("status") == "succeeded":
            moments.append(f"- {_clock(o['t'])}  [Screenshot taken; add it if you want to share it.]")
    moments.sort()

    body_parts = [PLACEHOLDER_STORY]
    if notes:
        body_parts += ["", "Your notes from the session:", ""] + notes
    return {
        "title": title,
        "attempted": PLACEHOLDER_PLAN,
        "happened": _fit(events, "events"),
        "outcome": "unknown",
        "moments": _fit(moments, "moments") if moments else PLACEHOLDER_MOMENTS,
        "body": _fit(body_parts, "note lines"),
        "activity_type_suggestion": suggest_activity(doc),
        "visibility": "private_draft",
        "source": {"session_id": s["id"], "interrupted": s["interrupted"], "self_reported": True},
    }


LABELS = [("attempted", "The plan"), ("happened", "What happened"), ("outcome", "Outcome"),
          ("moments", "Best moments"), ("body", "The story")]


def render(sc: dict, fmt: str) -> str:
    if fmt == "json":
        return json.dumps(sc, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    note = "Private draft. Nothing here has been shared. Bracketed text is for you to replace."
    if fmt == "md":
        out = [f"# {sc['title']}", "", note, ""]
        for key, label in LABELS:
            out += [f"## {label}", "", sc[key], ""]
        return "\n".join(out)
    if fmt == "txt":
        out = [sc["title"], "=" * len(sc["title"]), "", note, ""]
        for key, label in LABELS:
            out += [label, "-" * len(label), sc[key], ""]
        return "\n".join(out)
    if fmt == "html":
        e = html.escape
        out = ["<!doctype html>", '<html lang="en"><head><meta charset="utf-8">',
               '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'">',
               f"<title>{e(sc['title'])}</title>",
               "<style>body{font-family:system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem;"
               "line-height:1.5}pre{white-space:pre-wrap;font:inherit}</style></head><body>",
               f"<h1>{e(sc['title'])}</h1>", f"<p>{e(note)}</p>"]
        for key, label in LABELS:
            out += [f"<h2>{e(label)}</h2>", f"<pre>{e(sc[key])}</pre>"]
        out.append("</body></html>")
        return "\n".join(out) + "\n"
    raise ValueError("format must be md, txt, html or json")


def main(argv: list[str]) -> int:
    fmt = "md"
    if "--format" in argv:
        i = argv.index("--format")
        fmt = argv[i + 1] if i + 1 < len(argv) else ""
        argv = argv[:i] + argv[i + 2:]
    if len(argv) != 1 or fmt not in ("md", "txt", "html", "json"):
        print("usage: ac_scaffold.py FILE [--format md|txt|html|json]", file=sys.stderr)
        return 2
    with open(argv[0], "rb") as fh:
        raw = fh.read(1024 * 1024 + 1)
    try:
        doc, _ = validate(raw)
    except ValidationError as exc:
        print(f"invalid: {exc}", file=sys.stderr)
        return 1
    sys.stdout.write(render(scaffold(doc), fmt))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
