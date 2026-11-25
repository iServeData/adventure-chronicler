#!/usr/bin/env python3
"""Reference validator for Adventure Chronicler exports (schema versions 1 and 2).

Version 2 adds quest log observations (quest.accepted, quest.progress, quest.snapshot) and the
consent.quest_text flag. Version 1 files are still accepted unchanged.

Python standard library only. It never executes, imports or evaluates the input: the text is
parsed as JSON with strict limits, then checked field by field. Unknown fields are rejected.

A valid export is NOT proof of real gameplay. Exports are self-reported and can be edited by
anyone; the CRC-32 only catches accidental damage while copying.

Usage:
    python3 ac_validate.py FILE            # prints a summary, exit code 0 if valid
    python3 ac_validate.py --json FILE     # prints the validated document as JSON
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
import zlib

MAX_INPUT_BYTES = 1024 * 1024  # 1 MiB; the addon itself refuses anything over 512 KiB
MAX_DEPTH = 12
MAX_STRING = 8000
LIMITS = {"observations": 2000, "notes": 200, "segments": 2000, "note_chars": 4000,
          "title_chars": 120, "label_chars": 200, "list_items": 64}

ENVELOPE = re.compile(r"\AACX1:(\d{1,7}):([0-9a-f]{8}):", re.ASCII)
CERTAINTY = {"confirmed", "inferred", "seen", "uncertain"}
STATES = {"recording", "paused", "stopped"}
SEGMENT_KINDS = {"recording", "paused", "gap"}
SEGMENT_REASONS = {None, "player", "reload", "offline", "unknown", "auto_after_gap"}
SCHEMA_VERSIONS = (1, 2)
V2_TYPES = {"quest.accepted", "quest.progress", "quest.snapshot"}
CONSENT_KEYS = {1: ("character_identity", "class_and_level", "personal_loot"),
                2: ("character_identity", "class_and_level", "personal_loot", "quest_text")}
QUEST_LIMITS = {"objectives": 16, "snapshot_quests": 40, "summary_chars": 1000, "text_chars": 4000}


class ValidationError(ValueError):
    """The input is not a valid export. The message is safe to show to the person importing."""


# ------------------------------------------------------------------ parsing

def _no_duplicates(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise ValidationError(f"duplicate key {k!r}")
        out[k] = v
    return out


def _no_constants(name):
    raise ValidationError(f"{name} is not allowed")


def _depth(v, d=0):
    if d > MAX_DEPTH:
        raise ValidationError("data is nested too deeply")
    if isinstance(v, dict):
        for x in v.values():
            _depth(x, d + 1)
    elif isinstance(v, list):
        for x in v:
            _depth(x, d + 1)


def unwrap(raw: bytes | str) -> tuple[str, dict]:
    """Check size, envelope, length and CRC, then parse JSON strictly. Returns (body, document)."""
    if isinstance(raw, str):
        raw = raw.encode("utf-8")
    if len(raw) > MAX_INPUT_BYTES:
        raise ValidationError("file is larger than 1 MiB")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValidationError("file is not valid UTF-8") from exc
    text = text.lstrip("\ufeff").strip()
    m = ENVELOPE.match(text)
    if not m:
        raise ValidationError("not an Adventure Chronicler export (missing ACX1 header)")
    body = text[m.end():]
    body_bytes = body.encode("utf-8")
    if int(m.group(1)) != len(body_bytes):
        raise ValidationError("export is incomplete or was changed (length does not match); copy it again")
    if f"{zlib.crc32(body_bytes) & 0xFFFFFFFF:08x}" != m.group(2):
        raise ValidationError("export was damaged while copying (checksum does not match); copy it again")
    try:
        doc = json.loads(body, object_pairs_hook=_no_duplicates, parse_constant=_no_constants)
    except ValidationError:
        raise
    except (ValueError, RecursionError) as exc:
        raise ValidationError("export body is not valid JSON") from exc
    _depth(doc)
    return body, doc


# ------------------------------------------------------------------ field checks

def _obj(v, where, required, optional=()):
    if not isinstance(v, dict):
        raise ValidationError(f"{where} must be an object")
    allowed = set(required) | set(optional)
    extra = sorted(set(v) - allowed)
    if extra:
        raise ValidationError(f"{where} has unknown field(s): {', '.join(extra)}")
    missing = [k for k in required if k not in v]
    if missing:
        raise ValidationError(f"{where} is missing: {', '.join(missing)}")
    return v


def _int(v, where, lo=None, hi=None, nullable=False):
    if v is None and nullable:
        return
    if isinstance(v, bool) or not isinstance(v, int):
        raise ValidationError(f"{where} must be a whole number")
    if (lo is not None and v < lo) or (hi is not None and v > hi):
        raise ValidationError(f"{where} is out of range")


def _str(v, where, max_chars=MAX_STRING, nullable=False, choices=None):
    if v is None and nullable:
        return
    if not isinstance(v, str):
        raise ValidationError(f"{where} must be text")
    if len(v) > max_chars:
        raise ValidationError(f"{where} is longer than {max_chars} characters")
    if choices is not None and v not in choices:
        raise ValidationError(f"{where} has an unexpected value")


def _bool(v, where, nullable=False):
    if v is None and nullable:
        return
    if not isinstance(v, bool):
        raise ValidationError(f"{where} must be true or false")


def _list(v, where, limit):
    if not isinstance(v, list):
        raise ValidationError(f"{where} must be a list")
    if len(v) > limit:
        raise ValidationError(f"{where} has more than {limit} entries")
    return v


TIME_MIN, TIME_MAX = 946684800, 4102444800  # 2000-01-01 .. 2100-01-01


def _item(v, where, with_index):
    req = ("item_id",)
    opt = ("name", "count", "name_pending") + (("index",) if with_index else ())
    _obj(v, where, req, opt)
    _int(v["item_id"], where + ".item_id", 1, 10**9, nullable=True)
    _str(v.get("name"), where + ".name", 200, nullable=True)
    _int(v.get("count", 1), where + ".count", 0, 10**6)
    _bool(v.get("name_pending", False), where + ".name_pending")
    if with_index:
        _int(v.get("index", 1), where + ".index", 1, 64)


def _items(v, where, with_index=True):
    for i, it in enumerate(_list(v, where, LIMITS["list_items"])):
        _item(it, f"{where}[{i}]", with_index)


def _instance(v, where):
    _obj(v, where, (), ("id", "name", "type", "difficulty_id", "difficulty", "max_players"))
    _int(v.get("id"), where + ".id", 0, 10**9, nullable=True)
    _str(v.get("name"), where + ".name", 200, nullable=True)
    _str(v.get("type"), where + ".type", 20, nullable=True)
    _int(v.get("difficulty_id"), where + ".difficulty_id", 0, 10**6, nullable=True)
    _str(v.get("difficulty"), where + ".difficulty", 100, nullable=True)
    _int(v.get("max_players"), where + ".max_players", 0, 1000, nullable=True)


def _id(v, w):
    _int(v, w, 0, 10**9, nullable=True)


def _name(v, w):
    _str(v, w, 200, nullable=True)


def _count(v, w):
    _int(v, w, 0, 10**6, nullable=True)


def _objective(v, where):
    _obj(v, where, ("index",), ("text", "type", "fulfilled", "required", "finished"))
    _int(v["index"], where + ".index", 1, 64)
    _str(v.get("text"), where + ".text", 200, nullable=True)
    _str(v.get("type"), where + ".type", 40, nullable=True)
    _count(v.get("fulfilled"), where + ".fulfilled")
    _count(v.get("required"), where + ".required")
    _bool(v.get("finished", False), where + ".finished")


def _objectives(v, where):
    for i, o in enumerate(_list(v, where, QUEST_LIMITS["objectives"])):
        _objective(o, f"{where}[{i}]")


def _level(v, w):
    _int(v, w, 0, 1000, nullable=True)


def _snapshot_quests(v, where):
    for i, q in enumerate(_list(v, where, QUEST_LIMITS["snapshot_quests"])):
        w = f"{where}[{i}]"
        _obj(q, w, ("quest_id",), ("title", "level", "complete", "objectives"))
        _id(q["quest_id"], w + ".quest_id")
        _name(q.get("title"), w + ".title")
        _level(q.get("level"), w + ".level")
        _bool(q.get("complete", False), w + ".complete")
        if "objectives" in q:
            _objectives(q["objectives"], w + ".objectives")


# Per observation type: field -> checker. Every field is optional because the game may not supply it.
OBS_DATA = {
    "zone.enter": {"map_id": _id, "map": _name, "zone": _name},
    "instance.enter": {"instance": _instance},
    "instance.leave": {"instance": _instance},
    "encounter.start": {"encounter_id": _id, "name": _name, "difficulty_id": _id, "group_size": _id,
                        "restricted_values": _bool},
    "encounter.end": {"encounter_id": _id, "name": _name, "difficulty_id": _id, "group_size": _id,
                      "result": lambda v, w: _str(v, w, choices={"success", "wipe_or_reset", "unknown"}),
                      "duration": lambda v, w: _int(v, w, 0, 86400 * 7), "restricted_values": _bool},
    "quest.rewards_offered": {"quest_id": _id, "title": _name, "choices": _items, "guaranteed": _items},
    "quest.reward_selected": {"quest_id": _id, "choice_index": lambda v, w: _int(v, w, 0, 64),
                              "item_id": _id, "name": _name},
    "quest.turned_in": {"quest_id": _id, "title": _name, "xp": lambda v, w: _int(v, w, 0, 10**9),
                        "money_copper": lambda v, w: _int(v, w, 0, 10**12)},
    "quest.accepted": {"quest_id": _id, "title": _name, "level": _level, "objectives": _objectives,
                       "summary": lambda v, w: _str(v, w, QUEST_LIMITS["summary_chars"], nullable=True),
                       "description": lambda v, w: _str(v, w, QUEST_LIMITS["text_chars"], nullable=True),
                       "text_cut": _bool},
    "quest.progress": {"quest_id": _id, "title": _name, "index": lambda v, w: _int(v, w, 1, 64),
                       "text": lambda v, w: _str(v, w, 200, nullable=True), "fulfilled": _count,
                       "required": _count, "finished": _bool,
                       "updates": lambda v, w: _int(v, w, 0, 10**6),
                       "last_t": lambda v, w: _int(v, w, TIME_MIN, TIME_MAX)},
    "quest.snapshot": {"quests": _snapshot_quests, "listed": lambda v, w: _int(v, w, 0, 10**4),
                       "kept": lambda v, w: _int(v, w, 0, 10**4)},
    "item.received": {"quest_id": _id, "item_id": _id, "name": _name,
                      "count_delta": lambda v, w: _int(v, w, 1, 10**6),
                      "basis": lambda v, w: _str(v, w, choices={"bag_count_increase_after_turn_in"})},
    "loot.seen": {"items": lambda v, w: _items(v, w, with_index=False)},
    "pvp.battleground_enter": {"instance_id": _id, "name": _name},
    "pvp.battleground_leave": {"instance_id": _id, "name": _name, "result_recorded": _bool},
    "pvp.battleground_result": {"instance_id": _id, "name": _name,
                                "winner": lambda v, w: _str(v, w, choices={"Horde", "Alliance", "unknown"}),
                                "player_faction": lambda v, w: _str(v, w, 40, nullable=True),
                                "outcome": lambda v, w: _str(v, w, choices={"won", "lost", "unknown"})},
    "player.death": {"context": lambda v, w: _str(v, w, 40), "zone": _name},
    "marker.bookmark": {"note_id": lambda v, w: _int(v, w, 1, 10**6)},
    "marker.screenshot": {"preset": lambda v, w: _str(v, w, choices={"as_seen", "clean_scene"}),
                          "status": lambda v, w: _str(v, w, choices={"succeeded", "failed", "unconfirmed"})},
}


def _observation(o, where, version=2):
    _obj(o, where, ("seq", "t", "type", "certainty", "data", "repeats", "clock_note"))
    _int(o["seq"], where + ".seq", 1, 10**7)
    _int(o["t"], where + ".t", TIME_MIN, TIME_MAX)
    if o["type"] not in OBS_DATA or (version < 2 and o["type"] in V2_TYPES):
        raise ValidationError(f"{where}.type is not a known observation type")
    _str(o["certainty"], where + ".certainty", choices=CERTAINTY)
    _int(o["repeats"], where + ".repeats", 0, 10**6)
    _str(o["clock_note"], where + ".clock_note", nullable=True, choices={"earlier_than_previous"})
    fields = OBS_DATA[o["type"]]
    data = _obj(o["data"], where + ".data", (), tuple(fields))
    for k, v in data.items():
        fields[k](v, f"{where}.data.{k}")


def validate_document(doc: dict) -> dict:
    _obj(doc, "export", ("format", "schema_version", "recorder", "game", "consent", "character", "session",
                         "observations", "author", "integrity"))
    if doc["format"] != "adventure-chronicler.session":
        raise ValidationError("export.format is not adventure-chronicler.session")
    version = doc["schema_version"]
    if isinstance(version, bool) or version not in SCHEMA_VERSIONS:
        raise ValidationError("this validator only understands schema versions 1 and 2")
    r = _obj(doc["recorder"], "recorder", ("name", "version"))
    _str(r["name"], "recorder.name", 60, choices={"AdventureChronicler"})
    _str(r["version"], "recorder.version", 40)
    g = _obj(doc["game"], "game", ("id", "flavor", "client_version", "build", "interface", "locale"))
    _str(g["id"], "game.id", choices={"wow"})
    _str(g["flavor"], "game.flavor", 40)
    _str(g["client_version"], "game.client_version", 40, nullable=True)
    _str(g["build"], "game.build", 40, nullable=True)
    _int(g["interface"], "game.interface", 0, 10**7, nullable=True)
    _str(g["locale"], "game.locale", 10, nullable=True)
    c = _obj(doc["consent"], "consent", CONSENT_KEYS[version])
    for k in c:
        _bool(c[k], "consent." + k)
    ch = _obj(doc["character"], "character", (), ("name", "realm", "class", "level"))
    if ("name" in ch or "realm" in ch) and not c["character_identity"]:
        raise ValidationError("character name or realm present without consent")
    if ("class" in ch or "level" in ch) and not c["class_and_level"]:
        raise ValidationError("class or level present without consent")
    _str(ch.get("name"), "character.name", 60, nullable=True)
    _str(ch.get("realm"), "character.realm", 60, nullable=True)
    _str(ch.get("class"), "character.class", 40, nullable=True)
    _int(ch.get("level"), "character.level", 0, 1000, nullable=True)

    s = _obj(doc["session"], "session", ("id", "title", "state", "interrupted", "started_at", "ended_at",
                                         "clock", "segments"))
    if not isinstance(s["id"], str) or not re.fullmatch(r"s-[0-9a-f]{8}-[0-9a-f]{12}", s["id"]):
        raise ValidationError("session.id is not in the expected form")
    _str(s["title"], "session.title", LIMITS["title_chars"])
    _str(s["state"], "session.state", choices=STATES)
    _bool(s["interrupted"], "session.interrupted")
    _int(s["started_at"], "session.started_at", TIME_MIN, TIME_MAX)
    _int(s["ended_at"], "session.ended_at", TIME_MIN, TIME_MAX, nullable=True)
    if s["ended_at"] is not None and s["ended_at"] < s["started_at"]:
        raise ValidationError("session ends before it starts")
    _str(s["clock"], "session.clock", choices={"unix_seconds"})
    for i, seg in enumerate(_list(s["segments"], "session.segments", LIMITS["segments"])):
        w = f"session.segments[{i}]"
        _obj(seg, w, ("kind", "start", "finish", "reason"))
        _str(seg["kind"], w + ".kind", choices=SEGMENT_KINDS)
        _int(seg["start"], w + ".start", TIME_MIN, TIME_MAX)
        _int(seg["finish"], w + ".finish", TIME_MIN, TIME_MAX, nullable=True)
        if seg["finish"] is not None and seg["finish"] < seg["start"]:
            raise ValidationError(f"{w} ends before it starts")
        if seg["reason"] not in SEGMENT_REASONS:
            raise ValidationError(f"{w}.reason has an unexpected value")

    seqs = set()
    for i, o in enumerate(_list(doc["observations"], "observations", LIMITS["observations"])):
        _observation(o, f"observations[{i}]", version)
        if o["type"] == "quest.accepted" and o["data"].get("description") is not None \
                and not c.get("quest_text"):
            raise ValidationError(f"observations[{i}].data.description present without consent")
        if o["seq"] in seqs:
            raise ValidationError(f"observations[{i}].seq is repeated")
        seqs.add(o["seq"])

    a = _obj(doc["author"], "author", ("notes",))
    ids = set()
    for i, n in enumerate(_list(a["notes"], "author.notes", LIMITS["notes"])):
        w = f"author.notes[{i}]"
        _obj(n, w, ("id", "t", "kind", "text", "edited_at"))
        _int(n["id"], w + ".id", 1, 10**6)
        if n["id"] in ids:
            raise ValidationError(f"{w}.id is repeated")
        ids.add(n["id"])
        _int(n["t"], w + ".t", TIME_MIN, TIME_MAX)
        _str(n["kind"], w + ".kind", choices={"note", "bookmark"})
        _str(n["text"], w + ".text", LIMITS["note_chars"] if n["kind"] == "note" else LIMITS["label_chars"])
        _int(n["edited_at"], w + ".edited_at", TIME_MIN, TIME_MAX, nullable=True)

    it = _obj(doc["integrity"], "integrity", ("observations_dropped", "dropped_by_type", "merged_repeats",
                                               "deleted_by_user", "self_reported"))
    for k in ("observations_dropped", "merged_repeats", "deleted_by_user"):
        _int(it[k], "integrity." + k, 0, 10**7)
    dbt = it["dropped_by_type"]
    if not isinstance(dbt, dict) or len(dbt) > 64:
        raise ValidationError("integrity.dropped_by_type must be a small object")
    for k, v in dbt.items():
        _str(k, "integrity.dropped_by_type key", 60)
        _int(v, "integrity.dropped_by_type value", 0, 10**7)
    if it["self_reported"] is not True:
        raise ValidationError("integrity.self_reported must be true")
    return doc


def fingerprint(body: str, doc: dict) -> dict:
    """Identity for duplicate detection: same session id + same content hash = the same import."""
    return {"session_id": doc["session"]["id"],
            "sha256": hashlib.sha256(body.encode("utf-8")).hexdigest()}


def classify(fp: dict, seen: list[dict]) -> str:
    """'new', 'duplicate' (identical import) or 'revision' (same session, changed content).

    An importer should create at most one draft per session id. A revision updates that private
    draft; neither ever grants attendance, clears, achievements or XP by itself.
    """
    same = [s for s in seen if s.get("session_id") == fp["session_id"]]
    if not same:
        return "new"
    return "duplicate" if any(s.get("sha256") == fp["sha256"] for s in same) else "revision"


def validate(raw: bytes | str) -> tuple[dict, dict]:
    body, doc = unwrap(raw)
    validate_document(doc)
    return doc, fingerprint(body, doc)


def main(argv: list[str]) -> int:
    as_json = "--json" in argv
    paths = [a for a in argv if a != "--json"]
    if len(paths) != 1:
        print(__doc__.strip().splitlines()[-2].strip(), file=sys.stderr)
        return 2
    with open(paths[0], "rb") as fh:
        raw = fh.read(MAX_INPUT_BYTES + 1)
    try:
        doc, fp = validate(raw)
    except ValidationError as exc:
        print(f"invalid: {exc}", file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        s = doc["session"]
        print(f"valid: session {fp['session_id']} ({s['state']}), {len(doc['observations'])} observations, "
              f"{len(doc['author']['notes'])} notes, sha256 {fp['sha256'][:16]}")
        print("note: exports are self-reported; a valid file is not proof of gameplay.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
