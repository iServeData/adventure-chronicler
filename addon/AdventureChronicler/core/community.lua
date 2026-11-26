-- Adventure Chronicler: community details for the Community tab, the export window and Report a problem.
-- In the public source these are empty, so the add-on is community-neutral. A community's own build fills
-- them in from a local file kept outside the repository (tools/build_zip.py --community FILE), which
-- replaces this file inside the zip. Players can still set their own addresses with /ac link and
-- /ac community.
local _, ns = ...
ns = ns or {}

ns.COMMUNITY = {
  name = "",        -- shown as the Community tab's heading
  invite = "",      -- a Discord (or other) invite address, shown to copy
  import_url = "",  -- where the import code is pasted (the QuestersBoard import page)
  board_url = "",   -- the community's QuestersBoard
  -- Where problems can be reported when no community invite is set: this project's public issue page.
  issues_url = "https://github.com/iServeData/adventure-chronicler/issues",
}

return ns.COMMUNITY
