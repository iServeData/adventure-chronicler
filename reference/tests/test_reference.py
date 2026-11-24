"""Tests for the reference validator and story scaffold (standard library unittest).

Run from the repository root:  python3 -m unittest discover -s reference/tests -v
"""
import copy
import json
import os
import sys
import unittest
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "reference", "validator"))
sys.path.insert(0, os.path.join(ROOT, "reference", "scaffold"))

import ac_scaffold  # noqa: E402
import ac_validate as v  # noqa: E402

FIXTURE = os.path.join(ROOT, "tests", "fixtures", "valid_session.acx.txt")


def load_fixture():
    with open(FIXTURE, "rb") as fh:
        return fh.read()


def wrap(body: str) -> str:
    b = body.encode("utf-8")
    return f"ACX1:{len(b)}:{zlib.crc32(b) & 0xFFFFFFFF:08x}:{body}"


def doc():
    return json.loads(load_fixture().decode().split(":", 3)[3])


def rewrap(d) -> str:
    return wrap(json.dumps(d, ensure_ascii=False, separators=(",", ":"), sort_keys=True))


class Envelope(unittest.TestCase):
    def test_fixture_is_valid(self):
        d, fp = v.validate(load_fixture())
        self.assertEqual(d["session"]["id"], fp["session_id"])
        self.assertEqual(64, len(fp["sha256"]))

    def test_tolerates_bom_and_surrounding_whitespace(self):
        v.validate(b"\xef\xbb\xbf  " + load_fixture() + b"\r\n\r\n")

    def test_rejects_missing_header(self):
        with self.assertRaisesRegex(v.ValidationError, "ACX1"):
            v.validate(b'{"format":"adventure-chronicler.session"}')

    def test_rejects_truncated_copy(self):
        with self.assertRaisesRegex(v.ValidationError, "incomplete"):
            v.validate(load_fixture().rstrip()[:-20])

    def test_rejects_changed_content(self):
        raw = load_fixture().replace(b"Synthetic Quest", b"Synthetic Quesu")
        with self.assertRaisesRegex(v.ValidationError, "checksum"):
            v.validate(raw)

    def test_rejects_oversized_input(self):
        with self.assertRaisesRegex(v.ValidationError, "1 MiB"):
            v.validate(b"ACX1:" + b"0" * (v.MAX_INPUT_BYTES + 1))

    def test_rejects_invalid_utf8(self):
        with self.assertRaisesRegex(v.ValidationError, "UTF-8"):
            v.validate(b"ACX1:1:00000000:\xff")


class Parsing(unittest.TestCase):
    def test_rejects_duplicate_keys(self):
        body = load_fixture().decode().strip().split(":", 3)[3]
        body = body.replace('{"author"', '{"format":"x","author"', 1)
        with self.assertRaisesRegex(v.ValidationError, "duplicate key"):
            v.validate(wrap(body))

    def test_rejects_nan_and_infinity(self):
        for bad in ("NaN", "Infinity", "-Infinity"):
            body = load_fixture().decode().strip().split(":", 3)[3].replace('"repeats":0', f'"repeats":{bad}', 1)
            with self.assertRaises(v.ValidationError):
                v.validate(wrap(body))

    def test_rejects_deep_nesting(self):
        with self.assertRaises(v.ValidationError):
            v.validate(wrap("[" * 5000 + "]" * 5000))
        with self.assertRaisesRegex(v.ValidationError, "nested"):
            v.validate(wrap("[" * 20 + "]" * 20))

    def test_does_not_execute_lua_or_savedvariables(self):
        lua = 'AdventureChroniclerCharDB = { ["sessions"] = {} } os.execute("echo pwned")'
        with self.assertRaisesRegex(v.ValidationError, "ACX1"):
            v.validate(lua)


class Schema(unittest.TestCase):
    def check_bad(self, mutate, pattern):
        d = doc()
        mutate(d)
        with self.assertRaisesRegex(v.ValidationError, pattern):
            v.validate(rewrap(d))

    def test_unknown_top_level_field(self):
        self.check_bad(lambda d: d.update(extra=1), "unknown field")

    def test_unknown_observation_field(self):
        self.check_bad(lambda d: d["observations"][0]["data"].update(cleared=True), "unknown field")

    def test_unknown_observation_type(self):
        self.check_bad(lambda d: d["observations"][0].update(type="dungeon.cleared"), "known observation type")

    def test_identity_without_consent(self):
        self.check_bad(lambda d: d["character"].update(name="Examplechar"), "without consent")

    def test_wrong_types(self):
        self.check_bad(lambda d: d["observations"][0].update(seq="1"), "whole number")
        self.check_bad(lambda d: d["observations"][0].update(seq=True), "whole number")
        self.check_bad(lambda d: d["session"].update(interrupted="no"), "true or false")

    def test_bad_certainty(self):
        self.check_bad(lambda d: d["observations"][0].update(certainty="definitely"), "unexpected value")

    def test_note_too_long(self):
        self.check_bad(lambda d: d["author"]["notes"][0].update(text="x" * 4001), "longer than")

    def test_segment_ends_before_start(self):
        self.check_bad(lambda d: d["session"]["segments"][0].update(finish=1700000000), "ends before")

    def test_self_reported_must_be_true(self):
        self.check_bad(lambda d: d["integrity"].update(self_reported=False), "self_reported")

    def test_repeated_seq(self):
        def m(d):
            d["observations"][1]["seq"] = 1
        self.check_bad(m, "repeated")

    def test_schema_version(self):
        self.check_bad(lambda d: d.update(schema_version=2), "schema version 1")


class Duplicates(unittest.TestCase):
    def test_classify(self):
        _, fp = v.validate(load_fixture())
        self.assertEqual("new", v.classify(fp, []))
        self.assertEqual("duplicate", v.classify(fp, [fp]))
        d = doc()
        d["author"]["notes"][0]["text"] = "Edited after export."
        _, fp2 = v.validate(rewrap(d))
        self.assertEqual("revision", v.classify(fp2, [fp]))


class Scaffold(unittest.TestCase):
    def test_outcome_is_never_guessed_and_draft_is_private(self):
        d, _ = v.validate(load_fixture())
        sc = ac_scaffold.scaffold(d)
        self.assertEqual("unknown", sc["outcome"])
        self.assertEqual("private_draft", sc["visibility"])
        self.assertEqual(ac_scaffold.PLACEHOLDER_PLAN, sc["attempted"])
        self.assertIn("We nearly wiped on the second pull.", sc["body"])

    def test_deterministic(self):
        d, _ = v.validate(load_fixture())
        outs = {ac_scaffold.render(ac_scaffold.scaffold(copy.deepcopy(d)), "md") for _ in range(5)}
        self.assertEqual(1, len(outs))

    def test_one_boss_kill_is_not_a_clear(self):
        d = doc()
        d["observations"].append({"seq": 3, "t": 1800000150, "type": "encounter.end", "certainty": "confirmed",
                                  "clock_note": None, "repeats": 0,
                                  "data": {"encounter_id": 1, "name": "Test Boss", "result": "success"}})
        dd, _ = v.validate(rewrap(d))
        sc = ac_scaffold.scaffold(dd)
        self.assertIn("Encounter ended: Test Boss, defeated", sc["happened"])
        for word in ("cleared", "completed the dungeon", "victory"):
            self.assertNotIn(word, json.dumps(sc).lower())

    def test_gap_is_shown_as_unknown(self):
        d = doc()
        d["session"]["interrupted"] = True
        d["session"]["segments"] = [
            {"kind": "recording", "start": 1800000000, "finish": 1800000060, "reason": None},
            {"kind": "gap", "start": 1800000060, "finish": 1800003660, "reason": "offline"},
            {"kind": "paused", "start": 1800003660, "finish": 1800003700, "reason": "auto_after_gap"}]
        dd, _ = v.validate(rewrap(d))
        self.assertIn("is not known", ac_scaffold.scaffold(dd)["happened"])

    def test_long_fields_say_what_was_left_out(self):
        d = doc()
        obs = []
        for i in range(1500):
            obs.append({"seq": i + 1, "t": 1800000000 + i, "type": "zone.enter", "certainty": "confirmed",
                        "clock_note": None, "repeats": 0, "data": {"zone": f"Example Zone {i}"}})
        d["observations"] = obs
        dd, _ = v.validate(rewrap(d))
        sc = ac_scaffold.scaffold(dd)
        self.assertLessEqual(len(sc["happened"]), ac_scaffold.FIELD_MAX)
        self.assertRegex(sc["happened"], r"\[\.\.\.and \d+ more events not shown")
        shown = sc["happened"].count("Arrived in")
        missing = int(sc["happened"].rsplit("and ", 1)[1].split(" ")[0])
        self.assertEqual(1500, shown + missing)

    def test_html_is_escaped(self):
        d = doc()
        d["session"]["title"] = "<script>alert(1)</script>"
        d["author"]["notes"][0]["text"] = '<img src=x onerror="alert(1)">'
        dd, _ = v.validate(rewrap(d))
        out = ac_scaffold.render(ac_scaffold.scaffold(dd), "html")
        self.assertNotIn("<script>", out)
        self.assertNotIn("<img", out)
        self.assertIn("&lt;script&gt;", out)

    def test_all_formats_render(self):
        d, _ = v.validate(load_fixture())
        sc = ac_scaffold.scaffold(d)
        for fmt in ("md", "txt", "html", "json"):
            self.assertIn("Synthetic evening", ac_scaffold.render(sc, fmt))


if __name__ == "__main__":
    unittest.main()
