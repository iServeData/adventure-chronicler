# Changelog

Built from `changelog.toml` by `tools/build_changelog.py`; edit that file, not this one.

## 0.3.6 · 2026-11-26 · Continue a stopped session, Shift-click quests (prototype, unreleased)

- **New** (Review): Continue a session you stopped: select it in the review window and click Continue, or type /ac continue for the one you stopped last. It asks first, then the same session records again. The time it was stopped shows as a pause, a "Continued after stopping" line marks where it picks up, and nothing is assumed about the time in between.
- **Improved** (Export): A session you continue keeps its session ID, so if you already imported it, pasting the new code at the same address offers to update that story's log instead of making a second story. The export window says so.
- **Fixed** (Review): Shift-click now works on quests as well as items, in the details panel (including the quest log list at Start) and on timeline rows about one item or quest. It puts the game's link in chat where the game makes one, otherwise the name in brackets.
- **Improved** (Windows): Every main window now says Adventure Chronicler at the top. The Recorder, Settings, What's new and Report a problem windows show their own name under it in smaller text; the slim Review, Export and Note windows keep one line.

## 0.3.5 · 2026-11-26 · Event details in review, export size (prototype, unreleased)

- **New** (Review): Under the session's title, a status line with the state, time recorded, events and notes, and the export size, for example "export 6.2 KB of 512 KB". It turns amber from 400 KB and red if the session is too large to export.
- **New** (Review): Hover over an event to see more. Items show the game's own item tooltip; quests show the game's quest tooltip where WoW Forever has one, or what was recorded (level, objectives). Loot windows list each item in its quality colour.
- **New** (Review): Click an event for a details panel beside the review window with everything recorded for it: zone, instance and difficulty, quest objectives, reward choices, items and certainty. Anything not recorded says so. Shift-click an item to put its link in chat. Click the event again, or the x, to close it.
- **Improved** (Review): Instance portals that report Entered, Left, Entered within a second now show as one row, for example "Entered Scarlet Monastery [+2 enter/leave lines]". Every line is still kept and exported; the tooltip and details panel list them all, and the row's x deletes all of them.
- **Fixed** (Review): The review and What's new windows' scroll bars showed as plain dark squares on WoW Forever. They are now slim gold bars that only appear when there is more to scroll, and the mouse wheel scrolls.

## 0.3.4 · 2026-11-26 · Settings window, loot filter and What's new (prototype, unreleased)

- **Improved** (Export): The export window shows two steps: 1. Copy the code, 2. Paste the code at, with the import address in a field to copy. The Open QuestersBoard button and its second window are gone, since add-ons can't open a browser.
- **New** (Settings): A settings window (`/ac settings`, or Settings in the Adventure Recorder) with Community, Export, Options and Help tabs and the version in the corner. Options lists every setting as a tick box in categories (Export, Loot, Minimap, Privacy, Recording, Windows), with a search box and Defaults. `/ac set` still works.
- **New** (Settings): Loot filter for recording: the lowest item quality to record, and boxes to leave out quest items, trade goods or grey junk. Left-out items are not recorded at all, from then on; nothing already recorded changes. When the game doesn't say an item's type or quality, the item is kept.
- **New** (Settings): Community tab: your community's name, its invite to copy and its QuestersBoard address. A community's own build fills these in; anyone can set an invite with `/ac community https://...`.
- **New** (Review): A Filter in the review window, like the profession filter: hide entry types (Check all, Uncheck all), loot by quality (Unknown quality for items the game hasn't loaded) and "seen" loot you then received. It only hides rows; nothing is deleted and exports keep everything. The button shows how many filters are on, and its red x clears them.
- **New** (Windows): Report a problem (Help tab or `/ac report`): a short report to copy with the add-on and game versions, which settings are on and the last error the add-on caught, plus a line you type. No log, import code or names. It says where to paste it: your community's invite, or this project's GitHub issues.
- **New** (Windows): What's new (Help tab or `/ac whatsnew`): every version's changes, newest first, with Newer and Older. It opens once after an update; turn that off in Options, Windows.

## 0.3.3 · 2026-11-26 · Mini recorder and compass (prototype, unreleased)

- **Improved** (Windows): Closing the Adventure Recorder while recording now leaves the mini recorder (REC or PAUSED, the time and the small buttons) on screen. With no session open, closing it leaves only the compass on the minimap.
- **Improved** (Windows): The compass on the minimap opens the Adventure Recorder, or while a session is open, the mini recorder; from the mini recorder it opens the Adventure Recorder. Its red or gold dot still shows when recording or paused.
- **Improved** (Windows): The mini recorder's x hides it; the compass brings it back, and it shows again after a login or /reload while a session is open. If the minimap button is off, chat says once that it's still recording.
- **Improved** (Settings): The small tab and /ac set indicator hide are gone, since closing the mini recorder does the same. The chat reminders that went with them are gone too.
- **Fixed** (Recorder): On WoW Forever, a quest whose objectives weren't in the quest log yet when you accepted it gets them filled in from the next quest log updates (for up to 10 seconds). Nothing is added that the log doesn't show.

## 0.3.2 · 2026-11-25 · Forever quest log, loot and reward name fixes (prototype, unreleased)

- **Fixed** (Recorder): On WoW Forever, accepted quests now record their objectives and progress, and Start lists the quests already in your log. The add-on now reads the quest log the way Forever provides it.
- **Fixed** (Recorder): Each loot window is recorded once. Forever reported every window twice, so loot was listed twice.
- **Fixed** (Recorder): Reward items the game hadn't loaded yet get their names filled in when the game sends them, instead of staying "name not loaded yet".

## 0.3.1 · 2026-11-24 · Smaller indicator and a minimap button (prototype, unreleased)

- **New** (Recorder): The REC indicator has an x button that shrinks it to a small tab with a red (recording) or gold (paused) dot and the time. Click the tab to bring the full window back; the choice is remembered.
- **New** (Recorder): A compass button at the start of the indicator's row (and on the small tab) opens the recorder, so you don't have to type /ac.
- **New** (Windows): A compass button on the minimap opens the recorder at any time, shows a red or gold dot while a session is open, and can be dragged around the minimap. /ac set minimap off hides it.
- **New** (Settings): /ac set indicator hide hides the REC indicator completely (off by default). Chat then reminds you when recording starts, resumes or continues after login; /ac set indicator show brings it back.

## 0.3.0 · 2026-11-24 · Quest objectives and progress (prototype, unreleased)

- **New** (Recorder): Accepting a quest records its title, objectives (for example "Fixture Wolf slain: 0/8") and short objective summary. Objective progress is recorded as it changes; changes in a row for the same objective become one entry with the last count.
- **New** (Recorder): Pressing Start lists the quests already in your log, marked "already in progress".
- **New** (Settings): `/ac set questtext on` also keeps the quest giver's full text. It's off by default and left out of exports unless it's on when you export.
- **Improved** (Export): Exports use schema version 2, which adds the quest log entries. Readers that know version 2 still accept version 1 files.

## 0.2.6 · 2026-11-24 · Quick buttons on the recording indicator (prototype, unreleased)

- **New** (Recorder): The REC / PAUSED indicator has a row of small buttons: Add note, Bookmark, Pause (Resume while paused), Stop (asks first), Export and Review, each with a tooltip. `/ac set buttons off` hides the row.

## 0.2.5 · 2026-11-24 · Rename sessions in Review (prototype, unreleased)

- **New** (Review): Sessions can be renamed in the review window, including stopped ones: click the title or Rename, type, and press Enter (Escape keeps the old name). Only the title changes.
- **Improved** (Export): The Open QuestersBoard button has a default address, the placeholder `https://example.com/import`, so it works before you set your own. `/ac link https://...` replaces it and `/ac link clear` goes back to the default.

## 0.2.4 · 2026-11-24 · Export as Markdown, Text or JSON (prototype, unreleased)

- **New** (Export): The export window has a Format row: Import code (the checked code QuestersBoard reads), Markdown, Text and JSON. The last three are readable copies to keep as a file; WoW doesn't let add-ons save files, so the window suggests a file name for you to paste into. Only the import code can be imported.
- **New** (Export): The readable copies follow the same privacy settings as the import code: no chat, no other players, and no character name unless you turned it on. Notes are written out in full, and paused or missing time is shown.
- **New** (Export): An Open QuestersBoard button. WoW doesn't let add-ons open a browser, so it shows your community's QuestersBoard address ready to copy. Set it once with `/ac link https://...` (https only); it's saved with your settings on your computer.

## 0.2.3 · 2026-11-24 · Notes open on top (prototype, unreleased)

- **Fixed** (Notes): A note opened while the export window is showing comes up on top of it. Of the two, whichever was opened or clicked last is in front.
- **Fixed** (Recorder): The recorder's short list leaves out the repeat count, which got cut off ("[+1 re..."). The review window still shows it, as "[+1 repeat]" or "[+2 repeats]".

## 0.2.2 · 2026-11-24 · Rename while recording, one death at a time (prototype, unreleased)

- **New** (Recorder): The session title can be changed while recording: click it in the recorder, type, and press Enter (Escape keeps the old name). `/ac title <name>` does the same. Renaming doesn't change any observations.
- **Fixed** (Recorder): Boats, zeppelins and the moment after a reload no longer log the continent (for example "Arrived in Eastern Kingdoms") as a place you arrived in. The next real zone is logged instead.
- **Fixed** (Recorder): A death is logged once even when the client reports it twice. Another death is logged only after you've been alive in between (released and came back, or were resurrected).
- **Fixed** (Review): A bookmark with no label shows as "Bookmark" in the review list, without a trailing colon.

## 0.2.1 · 2026-11-24 · The add-on's own look (prototype, unreleased)

- **Improved** (Windows): The recorder, review, note and export windows use the add-on's own look from the mock instead of the stock frames: dark panel with a double gold border, compass emblem, serif titles, weathered parchment for the session title, a gold timeline with icons, and tall Add note, Stop (red) and Export buttons.
- **Improved** (Windows): The artwork is drawn by `tools/gen_textures.py` and shipped as TGA files in `media/`. Nothing is copied from the mock or from Blizzard files.
- **Fixed** (Windows): Long timeline entries end with "..." inside the window instead of running past the edge.

## 0.2.0 · 2026-11-24 · Recorder window (prototype, unreleased)

- **New** (Recorder): A recorder window, following panel 1 of the approved mock. `/ac` on its own, the REC indicator and the add-on menu open it. It shows whether recording is on, the session title, recorded time and the latest three entries, with Add note, Stop and Export, plus Pause, Bookmark and Review all. With no session open you can name one and press Start.
- **Improved** (Recorder): Stop asks first, because a stopped session can't be resumed.
- **New** (Settings): `/ac help` lists the commands. `/ac review` still opens the full review window.

## 0.1.1 · 2026-11-24 · Fixes from the first in-game tests (prototype, unreleased)

- **Fixed** (Recorder): Taking a flight path no longer logs the same zone arrival twice.
- **Fixed** (Export): The export window stays on top of the review window instead of letting its rows show through.
- **Improved** (Screenshots): Clean scene also hides the minimap and the names shown above characters, pets and NPCs, and restores the exact previous values afterwards. A minimap you'd already hidden stays hidden.
- **New** (Screenshots): After each screenshot, a chat message says it was saved and roughly when (the time it was requested), so the file is easy to find in the Screenshots folder.
- **Fixed** (Review): Review no longer shows a bookmark twice.

## 0.1.0 · 2026-11-24 · First prototype (prototype, unreleased)

- **New** (Recorder): First prototype for WoW Forever (interface 16001). Sessions you start yourself: start, pause, resume, stop, crash and reload recovery, and honest gaps for time that wasn't recorded.
- **New** (Recorder): Records zones, instances, encounters, quest turn-ins and reward choices, battleground results and your own deaths. Personal loot is off by default.
- **New** (Notes): Notes and bookmarks that are never silently cut off, and a review window where you can delete entries.
- **New** (Screenshots): Screenshots "as seen" and "clean scene". Clean scene restores the interface exactly afterwards.
- **New** (Export): The ACX1 export with a CRC-32 checksum, a versioned JSON schema, a reference validator and a fixed story scaffold.
