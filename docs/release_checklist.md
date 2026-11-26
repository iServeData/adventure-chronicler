# Release checklist

Every step that needs approval stops until it's given.

1. All mocked tests pass in CI on `prototype`.
2. The in-game checklist ([testing.md](testing.md)) is done on Windows and on Mac, with the results recorded.
3. `python3 tools/hygiene_check.py --blocklist <private file outside the repo>` is clean, and gitleaks across
   the full history is clean.
4. The diff from `main` has been reviewed by a person. There are no real IDs, names, domains, hosts or
   exports in it.
5. The change is added to `changelog.toml`, `python3 tools/build_changelog.py` has rebuilt CHANGELOG.md, and the version is updated in the `.toc` file.
6. `python3 tools/build_zip.py` builds the public zip. A community's own zip is built with
   `python3 tools/build_zip.py --community <file outside the repo>`; it stops if any file mentions a host in
   `forbid_hosts`. Check it with `unzip -l` before sharing.
7. **Approval:** merge `prototype` into `main`.
8. **Approval, as a separate decision:** licence.
9. **Approval, as a separate decision:** name and branding. Check the name hasn't been taken. No trademark
   claims.
10. **Approval:** any public listing (for example on an addon site). Listings are free, link to the visible
    source, and contain no donation prompts.
11. **Approval, as a separate decision:** any QuestersBoard import feature. It's built and reviewed in the
    QuestersBoard repository, not here.
