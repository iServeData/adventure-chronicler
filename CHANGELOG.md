# Changelog

## 0.2.6 (prototype, unreleased)

- The REC / PAUSED indicator has a row of small buttons: Add note, Bookmark, Pause (Resume while paused),
  Stop (asks first), Export and Review. Each has a tooltip. `/ac set buttons off` hides the row.

## 0.2.5 (prototype, unreleased)

- Sessions can be renamed in the review window, including stopped ones: click the title or Rename, type, and
  press Enter (Escape keeps the old name). Only the title changes.
- The Open QuestersBoard button now has a default address, the placeholder `https://example.com/import`,
  so it works before you set your own. `/ac link https://...` still replaces it, and `/ac link clear` goes
  back to the default.

## 0.2.4 (prototype, unreleased)

- The export window has a Format row: Import code (the checked code QuestersBoard reads, as before),
  Markdown, Text and JSON. The last three are readable copies to keep as a file. WoW doesn't let add-ons
  save files, so the window suggests a file name (for example `adventure_2026-11-24_evening_run.md`) for you
  to paste into. Only the import code can be imported.
- The readable copies follow the same privacy settings as the import code: no chat, no other players, and no
  character name unless you turned it on. Notes are written out in full, and paused or missing time is shown.
- An Open QuestersBoard button. WoW doesn't let add-ons open a browser, so it shows your community's
  QuestersBoard address ready to copy. Set the address once with `/ac link https://...` (https only). It's
  saved with your settings on your computer; the add-on ships with no address.

## 0.2.3 (prototype, unreleased)

- A note opened while the export window is showing now comes up on top of it. Of the two, whichever was
  opened or clicked last is in front.
- The recorder's short list leaves out the repeat count, which got cut off ("[+1 re..."). The review window
  still shows it, now as "[+1 repeat]" or "[+2 repeats]".

## 0.2.2 (prototype, unreleased)

- The session title can be changed while recording: click it in the recorder, type, and press Enter
  (Escape keeps the old name). `/ac title <name>` does the same. Renaming doesn't change any observations.
- Boats, zeppelins and the moment after a reload no longer log the continent (for example "Arrived in Eastern Kingdoms") as a place you
  arrived in. The next real zone is logged instead.
- A death is logged once even when the client reports it twice. Another death is logged only after you've
  been alive in between (released and came back, or were resurrected).
- A bookmark with no label shows as "Bookmark" in the review list, without a trailing colon.

## 0.2.1 (prototype, unreleased)

- The recorder, review, note and export windows now use the add-on's own look from the mock instead of the
  stock frames: dark panel with a double gold border, compass emblem, serif titles, weathered parchment for
  the session title, a gold timeline with icons, and tall Add note, Stop (red) and Export buttons.
- The artwork is drawn by `tools/gen_textures.py` and shipped as TGA files in `media/`. Nothing is copied from
  the mock or from Blizzard files.
- Long timeline entries are cut short with "..." inside the window instead of running past the edge.

## 0.2.0 (prototype, unreleased)

- New recorder window, following panel 1 of the approved mock. `/ac` on its own, the REC indicator and the
  add-on menu open it. It shows whether recording is on, the session title, recorded time and the latest
  three entries, with Add note, Stop and Export, plus Pause, Bookmark and Review all. With no session open
  you can name one and press Start.
- Stop now asks first, because a stopped session can't be resumed.
- `/ac help` lists the commands. `/ac review` still opens the full review window.

## 0.1.1 (prototype, unreleased)

- Taking a flight path no longer logs the same zone arrival twice.
- The export window stays on top of the review window instead of letting its rows show through.
- The screenshot message uses the time the screenshot was requested, so it matches the file name more closely.

From the first in-game test on Windows (WoW Forever 1.60.1, build 71091):

- Clean scene now also hides the minimap and the names shown above characters, pets and NPCs. It restores
  the exact previous values afterwards. A minimap you'd already hidden stays hidden.
- After each screenshot, a chat message says it was saved and roughly when, so the file is easy to find in
  the Screenshots folder inside `_forever_`.
- Review no longer shows a bookmark twice.

## 0.1.0 (prototype, unreleased)

- First prototype for WoW Forever (interface 16001). It hasn't been tested in the game client yet.
- Sessions you start yourself: start, pause, resume, stop, crash and reload recovery, and honest gaps.
- Records zones, instances, encounters, quest turn-ins and reward choices, battleground results and your own
  deaths. Personal loot is off by default.
- Notes and bookmarks that are never silently cut off. Review window with deletion.
- Screenshots: "as seen" and "clean scene". Clean scene restores the interface exactly afterwards.
- ACX1 export with CRC-32, a versioned JSON schema, a reference validator and a deterministic story scaffold.
