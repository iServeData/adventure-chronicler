# Testing

There are two kinds of testing, and they're reported separately.

## 1. Mocked tests (automated)

These run without the game. They use a fake game API, so they show the logic works as designed. They
**don't** show that the real client behaves the way the fake one does.

| Suite | Command | Covers |
| --- | --- | --- |
| Lua (busted) | `busted` | Session lifecycle, reload and offline gaps, dedupe, out-of-order times, limits and retention, Unicode and long notes, quest reward cases (no choice, choices, cancelled, changed choice, repeated window, rapid turn-ins, uncached items), encounters with restricted values, PvP and deaths, loot defaults, screenshot restoration, JSON, CRC-32, envelope, privacy defaults, a fixed export fixture, and a stubbed load of every `.toc` file |
| Lua lint | `luacheck .` | Undeclared globals and common mistakes |
| Python | `python3 -m unittest discover -s reference/tests -v` | Envelope, strict parsing, schema, duplicates, scaffold determinism, no invented outcomes, truncation summaries, HTML escaping |
| Schema | `python3 tools/gen_schema.py --check` | The schema file matches the validator |
| Hygiene | `python3 tools/hygiene_check.py` (+ gitleaks in CI) | Secrets and identifying details |

CI runs the Lua suites on Linux with Lua 5.1, the version WoW uses. It runs the Python suites on Linux,
Windows and macOS.

## 2. In-game checklist (manual)

The player runs these in WoW Forever on **Windows and on Mac**, and records the client version, build and
result for each item. Until this is done, **no in-game behaviour is confirmed.**

Setup: install as in [install.md](install.md). Turn on Lua errors with `/console scriptErrors 1`.

| # | Check | Expected |
| --- | --- | --- |
| 1 | Log in | No Lua errors. `/ac version` shows the current version |
| 2 | `/ac start Test` | REC indicator appears and the time counts up |
| 3 | Move to a new zone | "Arrived in ..." appears in `/ac review` |
| 4 | Turn in a quest with no reward choice | "Turned in ..." appears, with no reward line |
| 5 | Turn in a quest with reward choices, change the selection, then complete | Reward window line, "Chose a reward: <final choice> (probably)", then "Received ..." once it's in your bags |
| 6 | Open a reward window and close it without completing | Only the reward window line |
| 7 | Enter a dungeon | "Entered ...". Nothing says it was cleared |
| 8 | Kill one boss | "Encounter ended: <boss>, defeated" |
| 9 | Wipe on a boss (if practical) | "not defeated", or "result unknown (uncertain)" |
| 10 | `/ac pause`, do something, then `/ac resume` | Nothing is recorded while paused. Indicator shows PAUSED |
| 11 | `/ac note` with no text | Editor opens. Paste over 4,000 characters: the counter turns red, Save is disabled, and the text stays |
| 12 | `/ac mark Big moment` | Bookmark appears in review |
| 13 | `/ac shot` | Screenshot saved. Marker shows it succeeded |
| 14 | Note your nameplate, name and minimap settings, then `/ac shot clean` out of combat | The image has no interface, minimap, nameplates or names above characters. Afterwards, everything comes back exactly as before |
| 15 | `/ac shot clean` in combat | Refused with a message, and nothing changes |
| 16 | `/reload` while recording | Recording continues, and review shows a reload gap |
| 17 | Quit the game, wait 20 minutes, log back in | Session is paused and marked interrupted. A message explains |
| 18 | Battleground: enter, finish and leave | Entry, result (won or lost) and exit. No other player names |
| 19 | Die once | "You died" |
| 20 | `/ac stop`, then `/ac export` | Dialog shows "Character name is not included". Copy, save to a file, and run the validator: valid |
| 21 | Run the scaffold on that file | Markdown draft, with outcome "unknown" and your notes word for word |
| 22 | Review: delete one event, then delete the session | Each one asks or acts as expected. A session with notes that were never exported gives a warning |
| 23 | With another addon that uses `/ac` (if available) | `/advchron` still works |
| 24 | Check the saved-data file | No chat, no other player names, no Battle.net identifiers |
| 25 | `/ac` with no session, name it and press Start | Recorder window shows "Recording locally", the title and the time counting up |
| 26 | In the recorder: Add note, Bookmark, Pause and Resume | Each one works, and the latest three entries update |
| 27 | Press Stop in the recorder | It asks first. After Stop, the window offers Start again |
| 28 | While recording, click the session title, type a new name and press Enter; then try Escape | The new name shows in the recorder and in review. Escape keeps the old name |
| 29 | Take a boat or zeppelin to another continent | No "Arrived in" line for the continent itself, only the zones |
| 30 | With an export window open, press Add note | The note window opens on top of the export window |
| 31 | In the export window, click Markdown, Text, JSON, then Import code | Each shows its copy and a suggested file name; the chosen format is highlighted. Import code still validates |
| 32 | Copy the Markdown into a new `.md` file and open it | Title, details, timeline and your notes in full. No character name unless turned on |
| 33 | Press Open QuestersBoard before setting an address | It shows `https://example.com/import`, selected |
| 34 | `/ac link http://example.org`, then `/ac link https://example.org`, press the button, then `/ac link clear` | The http address is refused. The https one shows selected and Ctrl+C copies it. After clear, the default is back |
| 35 | In `/ac review`, pick a stopped session, click its title (or Rename), type a new name and press Enter; then try Escape on another | The new name shows in the list and the header, and in a new export. Escape keeps the old name |

Record the results in a copy of this table and add a summary to [test_results.md](test_results.md). Don't commit real exports or saved data.
