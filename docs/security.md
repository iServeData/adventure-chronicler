# Security and threat model

## What's being protected

- The player's privacy: what's recorded, and what leaves the game only when they choose.
- Importers, such as QuestersBoard or anyone using the reference tools, from harmful or malformed input.
- Fairness: an export must never be enough to grant attendance, clears, achievements or XP.

## Threats and how they're handled

| Threat | How it's handled |
| --- | --- |
| A malicious export (very large, deeply nested, duplicate keys, odd numbers) | 1 MiB cap, strict JSON parsing with duplicate keys and NaN/Infinity rejected, a depth limit, and an exact field list. See `reference/tests`. |
| Code execution through an upload | Importers only parse the ACX1 JSON envelope. They never run Lua or SavedVariables files, and never use `eval` or anything like it. |
| Script injection in an imported title, note or item name | All text is treated as plain text. The scaffold's HTML output escapes everything and includes a restrictive Content-Security-Policy. The addon also escapes `<`, `>` and `&` in its JSON. |
| A forged or edited export claiming a clear | Exports are self-reported (`integrity.self_reported: true`). The CRC isn't a signature. Imports create private drafts only, and awards follow the importer's normal review. |
| Repeated imports to farm rewards | One draft per session id. Duplicates and revisions are detected by session id plus SHA-256. Importing never awards anything. |
| Recording more than the player expects | Recording is opt-in per session, with a visible indicator. Sensitive categories are off by default. No chat, no other players. See [privacy.md](privacy.md). |
| Leaving the interface changed after a screenshot | Restores the exact previous values, retries after combat, and has a 5-second timeout. Settings are never changed permanently. |
| Secrets or private details committed to the repository | `tools/hygiene_check.py`, with an optional private blocklist kept outside the repository, and gitleaks across the whole history in CI. Synthetic fixtures only. |
| A compromised CI dependency | Actions pinned by commit SHA, the gitleaks download checked by SHA-256, read-only workflow permissions, and Dependabot for action updates. |
| Text in repository files, uploaded logs, item names or notes that looks like instructions | Treated as data. The tools never act on it. |

## Out of scope

The addon doesn't read game memory, inject into processes, intercept network traffic, automate gameplay or
bypass any restriction. Values the game marks as restricted are dropped, not worked around.
