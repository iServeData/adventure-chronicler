# Testing

There are two kinds of testing, and they're reported separately.

## 1. Mocked tests (automated)

These run without the game. They use a fake game API, so they show the logic works as designed. They
**don't** show that the real client behaves the way the fake one does.

| Suite | Command | Covers |
| --- | --- | --- |
| Lua (busted) | `busted` | Session lifecycle, reload and offline gaps, dedupe, out-of-order times, limits and retention, Unicode and long notes, quest log cases (accepted quests and objectives, progress merging, Start snapshot, quest text consent), quest reward cases (no choice, choices, cancelled, changed choice, repeated window, rapid turn-ins, uncached items), encounters with restricted values, PvP and deaths, loot defaults, screenshot restoration, JSON, CRC-32, envelope, privacy defaults, a fixed export fixture, and a stubbed load of every `.toc` file |
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
| 33 | Open the export window before setting an address | "2. Paste the code at:" shows the community's import page (public build: `https://example.com/import`); clicking the field selects it |
| 34 | `/ac link http://example.org`, then `/ac link https://example.org`, look at the export window, then `/ac link clear` | The http address is refused. The https one shows selected and Ctrl+C copies it. After clear, the default is back |
| 35 | In `/ac review`, pick a stopped session, click its title (or Rename), type a new name and press Enter; then try Escape on another | The new name shows in the list and the header, and in a new export. Escape keeps the old name |
| 36 | While recording, use each small button under REC: Note, Bookmark, Pause (then Resume), Export, Review, Stop | Each does the same as its command. Pause turns into Resume and back. Stop asks first. `/ac set buttons off` hides the row and `on` brings it back |
| 37 | While recording, accept a quest with a kill or collect objective | "Accepted <quest> (1 objective)". The export's `quest.accepted` has the objective text and the summary, and no `description` |
| 38 | Make progress on that objective several times in a row, then turn it in | One "Progress on <quest>: ... n/n (done)" line with the last count, then "Turned in ..." |
| 39 | Progress, die (or bookmark), then progress again | Two progress lines, with the death or bookmark in between |
| 40 | Press Start with quests already in the log (including one under a collapsed header) | "Quest log at start: N quests already in progress (seen)". Note whether quests under collapsed headers were counted |
| 41 | `/ac set questtext on`, accept a quest, export; then `/ac set questtext off` and export again | The first export has the quest giver's text in `description`; the second doesn't. Both validate |
| 42 | With the quest log open and a quest selected, accept another quest | Your selection in the quest log doesn't change |
| 43 | While recording, press the compass button at the start of the mini recorder's row | The Adventure Recorder opens and the mini recorder steps aside |
| 44 | With no session, close the Adventure Recorder; start a session, then close the Adventure Recorder | With no session nothing but the minimap compass is left. While recording, the mini recorder appears (REC and the time; PAUSED and a gold dot while paused) |
| 45 | While recording: press the mini recorder's x, then the minimap compass, then the compass again, then once more | x hides it (compass keeps its red dot). Compass brings the mini recorder back, then opens the Adventure Recorder (mini recorder hides), then closes it (mini recorder back) |
| 46 | Close the mini recorder with x, then `/reload`; then `/ac set minimap off` and close it twice | After the reload the mini recorder shows again. With the minimap button off, chat says "Still recording, /ac to open." once. `/ac set indicator hide` says the setting is gone |
| 47 | Look at the minimap with no session, then while recording and while paused | A compass button on the minimap edge: no dot, then a red dot, then a gold dot. The tooltip says what a click will do and how to drag and hide it. Note whether the round border lines up |
| 48 | Drag the minimap button around the edge, then `/reload` | It follows the edge and stays where you left it |
| 49 | `/ac set minimap off`, then `on` | The button disappears and comes back |
| 50 | `/ac shot clean` with the minimap button showing | The button is not in the image (it hides with the minimap) |
| 51 | On WoW Forever, accept a quest with a kill or collect objective, then export | `quest.accepted` has `objectives` (and `summary` if the game gives it). Note whether the summary is there |
| 52 | With `/ac set loot on`, loot several corpses (with and without auto loot), then export | One `loot.seen` per corpse, not two |
| 53 | Turn in a quest with a reward you've never seen before | The reward window line names the items, or the name appears within a few seconds in review and the export |
| 54 | On WoW Forever, accept The Corrupter (or any quest whose objectives were missing in 0.3.2), then export | `quest.accepted` has its objectives, filled in within about 10 seconds; still one Accepted line in the log (0.3.3) |
| 55 | Update from 0.3.3 and log in; then `/reload` | What's new opens once, on 0.3.4. Newer/Older page through versions. After the reload it doesn't open again (0.3.4) |
| 56 | `/ac settings`; click each tab (Community, Export, Options, Help) and each Options category | The version shows next to the close button. Categories run A-Z. Tick boxes change the setting at once and survive `/reload` |
| 57 | On Options, type "quest" in the search box, then clear it | Only matching settings show, from every category; clearing brings the category list back |
| 58 | Change some Loot settings, then press Defaults | Only that category goes back to its defaults |
| 59 | With loot on, set lowest quality to Uncommon and tick "Leave out trade goods" and "Leave out junk you sell to vendors"; loot corpses with grey, white, trade good and quest items, then export | Only Uncommon and better, and quest items, are in `loot.seen`. Tick "Leave out quest items" and quest items go too. Note whether any item's quality or type was missing |
| 60 | In `/ac review`, open Filter on a session with loot: untick types, untick qualities, tick Hide "seen" if received, then press the red x | The badge counts the filters and the status line under the title says "showing X of Y". The red x clears them all. After `/reload` the filter is clear |
| 61 | `/ac report`; type more than 200 letters; copy the report | The counter stops at 200. The report has versions, recording state, settings and last error, and no names. "3. Paste it at:" shows the community invite (public build: the issue page) |
| 62 | Settings > Community in the community build | The community's name and the addresses from its community file, and no host listed in `forbid_hosts`; each field copies with Ctrl+C |
| 63 | Settings > Export: save your own address, then press "Use the add-on's" | The export window follows each change |
| 64 | Open `/ac review` on a session with a few events, then on a long one | Under the title: state, time recorded, events, notes and "export N KB of 512 KB". The title is no longer cut off by the Filter button |
| 65 | While recording with review open, do things for a minute | The size updates within about 15 seconds; no stutter when events arrive |
| 66 | Hover an item event (Received, Chose a reward), then a loot window event | The game's own item tooltip with the recorded lines under it; for loot, each item in its quality colour. An item the game hasn't loaded yet fills in after a moment |
| 67 | Hover a quest event (Accepted, Progress, Turned in) | Note whether WoW Forever shows its own quest tooltip. Either way, level and objectives as recorded |
| 68 | Click an event; hover and Shift-click an item in the panel with the chat box open; click the event again | The panel opens beside the review window (left side if there's no room on the right) with what was recorded; missing things say "not recorded". Shift-click puts the item link in chat. Clicking again or the x closes it |
| 69 | Go in and out of an instance portal | "Entered <instance> [+2 enter/leave lines]" as one row where the game reported several in a second. Its tooltip lists them all; its x deletes them all; the export still has every line |
| 70 | Scroll the session list, the timeline and What's new with the mouse wheel and by dragging the gold bar | Slim gold bars only when there's more to scroll; no dark squares |
| 71 | `/ac stop` a session; in `/ac review` select it and press Continue, then Continue in the question | It asks first. The same session records again (no new session in the list); the Recorder opens; a "Continued after stopping (stopped …)" line shows in the timeline; the stopped time counts as paused, not recorded (0.3.6) |
| 72 | Start another session, then try Continue on the stopped one; stop it, `/reload` and `/ac continue` | Continue is greyed out with "Stop the current session first." on hover. After the reload, `/ac continue` asks about the one stopped last |
| 73 | Import a session to QuestersBoard, continue it in game, then export and paste it again | The board offers "Update the log" on the same story, not a second story. The export window said "Already imported it? …" |
| 74 | Open the quest log at Start in the details panel; with the chat box open, Shift-click a quest there, a quest's "Quest:" row, and an Accepted timeline row | Each puts the quest in chat. Note whether WoW Forever makes a real quest link or the plain [Name] text |
| 75 | Shift-click a Received or Chose a reward row in the timeline, and an item the game hasn't loaded yet | The item link goes into chat; the unloaded one after a moment, or as [Name] |
| 76 | Open the Recorder, Settings, What's new and Report a problem | Each says Adventure Chronicler at the top with its own name under it in smaller gold text, nothing cut off (the Recorder is the narrowest). Review, Export and Note keep one line: "Adventure Chronicler: review" and so on |
| 77 | Open `/ac review`, then click Settings in the Recorder; open What's new and Report a problem from Settings | Each window opens in front of the others; clicking a window brings it to the front (0.3.7) |
| 78 | Open an event's details panel, then delete every session in the review window | The details panel closes; Rename and Filter are hidden while there are no sessions, and come back when you start one |

Record the results in a copy of this table and add a summary to [test_results.md](test_results.md). Don't commit real exports or saved data.
