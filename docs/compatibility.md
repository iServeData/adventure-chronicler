# Compatibility

- **Slash command:** `/ac` is registered only if no other addon has it. `/advchron` always works.
- **Saved data:** settings are stored per account in `AdventureChroniclerDB`. Sessions are stored per
  character in `AdventureChroniclerCharDB`. When the addon loads, it repairs the data layout without throwing
  sessions away.
- **Quest reward hook:** the addon uses `hooksecurefunc("GetQuestReward", ...)`. That's a post-hook, so it
  runs after the game's own code and changes nothing.
- **Screenshots:** for a moment, the clean scene preset changes `UIParent` alpha, hides the minimap and
  turns off the nameplate and floating-name settings (`nameplateShowEnemies`, `nameplateShowFriends` and the
  `UnitName*` settings listed in `capture/screenshot.lua`). It then restores the exact previous values.
  Settings the client doesn't have are skipped. If
  combat starts first, the nameplate restore waits until combat ends. Other addons that change these same
  settings at the same moment could conflict. Please report it if you see that.
- **Addon compartment:** clicking the addon's entry opens the review window.
- **Errors:** each capture module runs inside `pcall`, so one failing module doesn't break the others or
  your interface.
