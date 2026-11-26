"""Mocked tests for tools/build_zip.py --community: the community file fills core/community.lua in the zip only."""
import importlib.util
import os
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
spec = importlib.util.spec_from_file_location("build_zip", os.path.join(ROOT, "tools", "build_zip.py"))
build_zip = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_zip)
with open(os.path.join(ROOT, "addon", "AdventureChronicler", "core", "community.lua"), encoding="utf-8") as fh:
    TEMPLATE = fh.read()


def fill(text):
    with tempfile.NamedTemporaryFile("w", suffix=".toml", delete=False) as fh:
        fh.write(text)
    try:
        return build_zip.community_lua(fh.name, TEMPLATE)
    finally:
        os.unlink(fh.name)


class CommunityBuild(unittest.TestCase):
    def test_public_source_is_community_neutral(self):
        for key in build_zip.COMMUNITY_KEYS:
            self.assertIn(f'  {key} = ""', TEMPLATE)

    def test_fills_values(self):
        out, forbid = fill('name = "Example Community"\ninvite = "https://example.com/invite"\n'
                           'import_url = "https://example.com/wow/quester/chronicle/import"\n'
                           'forbid_hosts = ["Example.org"]\n')
        self.assertIn('name = "Example Community"', out)
        self.assertIn('invite = "https://example.com/invite"', out)
        self.assertIn('board_url = ""', out)
        self.assertIn("issues_url", out)
        self.assertEqual(["example.org"], forbid)

    def test_refuses_unsafe_values(self):
        for bad in ('invite = "http://example.com/x"', 'invite = "https://example.com/x\\"..os.exit()"',
                    'name = "a|cffff0000b"', 'surprise = "x"', 'board_url = "javascript:alert(1)"'):
            with self.assertRaises(ValueError, msg=bad):
                fill(bad + "\n")


if __name__ == "__main__":
    unittest.main()
