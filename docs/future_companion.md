# Future desktop companion (design only, not planned for 0.1.0)

This is an optional, local-only helper that could read the addon's saved-data file after the game closes.
That would save the player from copying exports by hand. **Nothing here is being built now.**

Constraints, if it's ever built:

- It reads `AdventureChroniclerCharDB` from the `WTF` folder only while the game isn't running. It parses the
  file as data with a strict Lua-table-subset parser and never runs it.
- It never touches game memory, never injects into processes, never intercepts network traffic and never
  automates anything.
- It's local only, with no account, no telemetry and no uploads, unless the player chooses to send one file
  to a service they've signed in to.
- It produces the same ACX1 export as the addon and uses the same validator.
- It's a separate repository and needs its own approval.
