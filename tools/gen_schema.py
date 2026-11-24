#!/usr/bin/env python3
"""Writes schema/chronicle-export.v1.schema.json (JSON Schema 2020-12) for the export body.

The reference validator (reference/validator/ac_validate.py) is the authority; this schema is a
portable description for other implementations. Regenerate after changing the validator.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "reference", "validator"))
import ac_validate as v  # noqa: E402

nint = {"type": ["integer", "null"]}
nstr = {"type": ["string", "null"], "maxLength": 200}
t = {"type": "integer", "minimum": v.TIME_MIN, "maximum": v.TIME_MAX}
nt = {"type": ["integer", "null"], "minimum": v.TIME_MIN, "maximum": v.TIME_MAX}


def obj(props, required=()):
    return {"type": "object", "additionalProperties": False, "properties": props, "required": list(required)}


item = obj({"index": {"type": "integer"}, "item_id": nint, "name": nstr, "count": {"type": "integer"},
            "name_pending": {"type": "boolean"}}, ["item_id"])
items = {"type": "array", "maxItems": v.LIMITS["list_items"], "items": item}
instance = obj({"id": nint, "name": nstr, "type": nstr, "difficulty_id": nint, "difficulty": nstr,
                "max_players": nint})


def enum(*vals):
    return {"enum": list(vals)}


DATA = {
    "zone.enter": {"map_id": nint, "map": nstr, "zone": nstr},
    "instance.enter": {"instance": instance}, "instance.leave": {"instance": instance},
    "encounter.start": {"encounter_id": nint, "name": nstr, "difficulty_id": nint, "group_size": nint,
                        "restricted_values": {"type": "boolean"}},
    "encounter.end": {"encounter_id": nint, "name": nstr, "difficulty_id": nint, "group_size": nint,
                      "result": enum("success", "wipe_or_reset", "unknown"), "duration": {"type": "integer"},
                      "restricted_values": {"type": "boolean"}},
    "quest.rewards_offered": {"quest_id": nint, "title": nstr, "choices": items, "guaranteed": items},
    "quest.reward_selected": {"quest_id": nint, "choice_index": {"type": "integer"}, "item_id": nint, "name": nstr},
    "quest.turned_in": {"quest_id": nint, "title": nstr, "xp": {"type": "integer"},
                        "money_copper": {"type": "integer"}},
    "item.received": {"quest_id": nint, "item_id": nint, "name": nstr, "count_delta": {"type": "integer"},
                      "basis": enum("bag_count_increase_after_turn_in")},
    "loot.seen": {"items": items},
    "pvp.battleground_enter": {"instance_id": nint, "name": nstr},
    "pvp.battleground_leave": {"instance_id": nint, "name": nstr, "result_recorded": {"type": "boolean"}},
    "pvp.battleground_result": {"instance_id": nint, "name": nstr, "winner": enum("Horde", "Alliance", "unknown"),
                                "player_faction": nstr, "outcome": enum("won", "lost", "unknown")},
    "player.death": {"context": {"type": "string"}, "zone": nstr},
    "marker.bookmark": {"note_id": {"type": "integer"}},
    "marker.screenshot": {"preset": enum("as_seen", "clean_scene"),
                          "status": enum("succeeded", "failed", "unconfirmed")},
}
assert set(DATA) == set(v.OBS_DATA), "schema and validator disagree on observation types"

observation = {
    "type": "object", "additionalProperties": False,
    "required": ["seq", "t", "type", "certainty", "data", "repeats", "clock_note"],
    "properties": {"seq": {"type": "integer", "minimum": 1}, "t": t, "type": enum(*sorted(DATA)),
                   "certainty": enum(*sorted(v.CERTAINTY)), "data": {"type": "object"},
                   "repeats": {"type": "integer", "minimum": 0},
                   "clock_note": {"enum": [None, "earlier_than_previous"]}},
    "allOf": [{"if": {"properties": {"type": {"const": k}}},
               "then": {"properties": {"data": obj(p)}}} for k, p in sorted(DATA.items())],
}

schema = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "urn:adventure-chronicler:chronicle-export:v1",
    "title": "Adventure Chronicler session export, schema version 1",
    "description": "Body of an ACX1 envelope (ACX1:<byte length>:<crc32 hex>:<json>). Self-reported data; "
                   "not proof of gameplay. See docs/schema.md.",
    **obj({
        "format": {"const": "adventure-chronicler.session"},
        "schema_version": {"const": 1},
        "recorder": obj({"name": {"const": "AdventureChronicler"}, "version": {"type": "string", "maxLength": 40}},
                        ["name", "version"]),
        "game": obj({"id": {"const": "wow"}, "flavor": {"type": "string"}, "client_version": nstr, "build": nstr,
                     "interface": nint, "locale": nstr},
                    ["id", "flavor", "client_version", "build", "interface", "locale"]),
        "consent": obj({k: {"type": "boolean"} for k in ("character_identity", "class_and_level", "personal_loot")},
                       ["character_identity", "class_and_level", "personal_loot"]),
        "character": obj({"name": nstr, "realm": nstr, "class": nstr, "level": nint}),
        "session": obj({
            "id": {"type": "string", "pattern": "^s-[0-9a-f]{8}-[0-9a-f]{12}$"},
            "title": {"type": "string", "maxLength": v.LIMITS["title_chars"]},
            "state": enum(*sorted(v.STATES)), "interrupted": {"type": "boolean"},
            "started_at": t, "ended_at": nt, "clock": {"const": "unix_seconds"},
            "segments": {"type": "array", "maxItems": v.LIMITS["segments"], "items": obj({
                "kind": enum(*sorted(v.SEGMENT_KINDS)), "start": t, "finish": nt,
                "reason": {"enum": [None, "player", "reload", "offline", "unknown", "auto_after_gap"]}},
                ["kind", "start", "finish", "reason"])},
        }, ["id", "title", "state", "interrupted", "started_at", "ended_at", "clock", "segments"]),
        "observations": {"type": "array", "maxItems": v.LIMITS["observations"], "items": observation},
        "author": obj({"notes": {"type": "array", "maxItems": v.LIMITS["notes"], "items": obj({
            "id": {"type": "integer", "minimum": 1}, "t": t, "kind": enum("bookmark", "note"),
            "text": {"type": "string", "maxLength": v.LIMITS["note_chars"]}, "edited_at": nt},
            ["id", "t", "kind", "text", "edited_at"])}}, ["notes"]),
        "integrity": obj({"observations_dropped": {"type": "integer", "minimum": 0},
                          "dropped_by_type": {"type": "object", "additionalProperties": {"type": "integer"}},
                          "merged_repeats": {"type": "integer", "minimum": 0},
                          "deleted_by_user": {"type": "integer", "minimum": 0},
                          "self_reported": {"const": True}},
                         ["observations_dropped", "dropped_by_type", "merged_repeats", "deleted_by_user",
                          "self_reported"]),
    }, ["format", "schema_version", "recorder", "game", "consent", "character", "session", "observations",
        "author", "integrity"]),
}

out = os.path.join(os.path.dirname(__file__), "..", "schema", "chronicle-export.v1.schema.json")
text = json.dumps(schema, indent=2, sort_keys=True) + "\n"
if "--check" in sys.argv:
    with open(out, encoding="utf-8") as fh:
        if fh.read() != text:
            sys.exit("schema/chronicle-export.v1.schema.json is out of date; run tools/gen_schema.py")
else:
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(text)
