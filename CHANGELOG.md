# Changelog

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
