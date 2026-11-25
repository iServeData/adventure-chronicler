# Changelog

## 0.1.1 (prototype, unreleased)

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
