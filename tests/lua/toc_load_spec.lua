-- MOCKED smoke test: loads every file in the .toc order against stub frames and drives the slash
-- commands end to end. It catches load-order and wiring mistakes; it says nothing about how the
-- real client draws the windows.
local H = require("tests.lua.helper")

local function stubObject()
  local o = {}
  return setmetatable(o, { __index = function(t, k)
    local f = function() return stubObject() end
    if k == "GetText" then f = function() return rawget(t, "_text") or "" end end
    if k == "SetText" then f = function(_, v) t._text = v end end
    if k == "IsShown" then f = function() return t._shown end end
    if k == "Show" then f = function() t._shown = true end end
    if k == "Hide" then f = function() t._shown = false end end
    rawset(t, k, f)
    return f
  end })
end

local function withGame(fn)
  local saved = {}
  local fake = H.api()
  local events, printed = {}, {}
  local G = {
    CreateFrame = function()
      local f = stubObject()
      f.RegisterEvent = function(_, e) events[e] = true end
      f.SetScript = function(self, name, h) rawset(self, "_" .. name, h) end
      return f
    end,
    UIParent = fake.UIParent, UISpecialFrames = {}, GameTooltip = stubObject(), ChatFontNormal = {},
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end },
    StaticPopupDialogs = {}, StaticPopup_Show = function() end, SlashCmdList = {},
    hooksecurefunc = function() end, C_Timer = { After = function() end, NewTicker = function() end },
    C_CVar = fake.C_CVar, InCombatLockdown = fake.InCombatLockdown, Screenshot = fake.Screenshot,
    GetBuildInfo = function() return "1.60.1", "00000", "", 16001 end, GetLocale = function() return "enUS" end,
    UnitClass = function() return "Hunter", "HUNTER" end, UnitName = function() return "Examplechar" end,
    UnitLevel = function() return 24 end, GetRealmName = function() return "Example Realm" end,
    GetCursorPosition = function() return 100, 300 end,
    time = function() return 1800000000 end, date = os.date, tinsert = table.insert,
  }
  local mm = stubObject()
  mm.GetWidth = function() return 140 end
  mm.GetCenter = function() return 100, 200 end
  mm.GetEffectiveScale = function() return 1 end
  G.Minimap = mm
  for k, v in pairs(G) do saved[k] = rawget(_G, k); _G[k] = v end
  local ok, err = pcall(fn, events, printed)
  for k in pairs(G) do _G[k] = saved[k] end
  _G.AdventureChroniclerDB, _G.AdventureChroniclerCharDB = nil, nil
  if not ok then error(err, 0) end
end

describe("addon load (stubbed)", function()
  it("loads every .toc file and runs the commands", function()
    withGame(function(events, printed)
      local ns, frames = {}, {}
      local real = _G.CreateFrame
      _G.CreateFrame = function(...) local f = real(...); frames[#frames + 1] = f; return f end
      for line in io.lines("addon/AdventureChronicler/AdventureChronicler.toc") do
        if line ~= "" and not line:match("^##") then
          local path = "addon/AdventureChronicler/" .. line:gsub("\\", "/")
          assert(loadfile(path))("AdventureChronicler", ns)
        end
      end
      assert.truthy(events.QUEST_TURNED_IN); assert.truthy(events.ADDON_LOADED)
      assert.is_nil(events.COMBAT_LOG_EVENT_UNFILTERED); assert.is_nil(events.CHAT_MSG_SAY)
      local onEvent = rawget(frames[1], "_OnEvent")
      onEvent(frames[1], "ADDON_LOADED", "AdventureChronicler")
      onEvent(frames[1], "PLAYER_LOGIN")
      local slash = _G.SlashCmdList.ADVENTURECHRONICLER
      slash("")  -- opens the recorder window with no session
      slash("start Synthetic test")
      slash("")  -- closes it
      slash("")  -- and opens it again while recording
      slash("help")
      slash("note A short synthetic note")
      slash("mark")
      slash("pause"); slash("resume")
      -- The indicator's small buttons can be hidden and shown again.
      slash("set buttons off")
      assert.is_false(_G.AdventureChroniclerDB.settings.indicator_buttons)
      slash("set buttons on")
      assert.is_true(_G.AdventureChroniclerDB.settings.indicator_buttons)
      -- 0.3.3 window flow. The Adventure Recorder is open (slash("") above), so the mini recorder steps aside.
      local settings0 = _G.AdventureChroniclerDB.settings
      assert.is_nil(settings0.show_indicator); assert.is_nil(settings0.indicator_minimized) -- retired
      local function mshown() local f = ns.ui.indicator.frames(); return f ~= nil and f:IsShown() == true end
      assert.is_true(ns.ui.recorder.isShown()); assert.is_false(mshown())
      -- Closing the Adventure Recorder while recording shows the mini recorder.
      ns.ui.recorder.close(); ns.ui.indicator.closed = false; ns.App.refresh() -- (the stub has no OnHide)
      assert.is_true(mshown())
      local _, btns = ns.ui.indicator.frames()
      -- Its x hides it; the compass brings it back; the compass again opens the Adventure Recorder.
      rawget(btns.close, "_OnClick")(btns.close)
      assert.is_false(mshown())
      ns.App.compass(); assert.is_true(mshown()); assert.is_false(ns.ui.recorder.isShown())
      ns.App.compass(); assert.is_true(ns.ui.recorder.isShown()); assert.is_false(mshown())
      ns.App.compass(); assert.is_false(ns.ui.recorder.isShown()) -- closes it again
      ns.ui.indicator.closed = false; ns.App.refresh(); assert.is_true(mshown())
      -- With the minimap button off, closing it says once in chat how to get back.
      slash("set minimap off")
      local before = #printed
      rawget(btns.close, "_OnClick")(btns.close); ns.ui.indicator.reopen()
      rawget(btns.close, "_OnClick")(btns.close)
      local told = 0
      for i = before + 1, #printed do
        if printed[i]:find("Still recording, /ac to open.", 1, true) then told = told + 1 end
      end
      assert.equal(1, told)
      slash("set minimap on"); ns.ui.indicator.reopen()
      -- The old setting answers with what to do now.
      before = #printed
      slash("set indicator hide")
      assert.truthy(printed[before + 1]:find("gone since 0.3.3", 1, true))
      assert.is_nil(settings0.show_indicator)
      -- The minimap button: shown with a dot while recording, draggable, and can be turned off.
      local mb, dot = ns.ui.minimap.frame()
      assert.is_true(mb:IsShown()); assert.is_true(dot:IsShown())
      rawget(mb, "_OnDragStart")(mb)
      rawget(mb, "_OnUpdate")(mb)  -- cursor is straight above the centre
      assert.equal(90, settings0.minimap_angle)
      rawget(mb, "_OnDragStop")(mb)
      slash("set minimap off")
      assert.is_false(settings0.minimap_button); assert.is_false(mb:IsShown())
      slash("set minimap on")
      assert.is_true(mb:IsShown())
      slash("stop")
      assert.is_false(dot:IsShown())
      local db = _G.AdventureChroniclerCharDB
      local s = db.sessions[db.order[1]]
      assert.equal("stopped", s.state); assert.equal(2, #s.notes)
      assert.is_false(_G.AdventureChroniclerDB.settings.include_identity)
      assert.is_false(_G.AdventureChroniclerDB.settings.record_personal_loot)
      assert.is_false(_G.AdventureChroniclerDB.settings.prompt_on_instance)
      -- A stopped session can be renamed from the review window.
      slash("review")
      ns.ui.review.startRename()
      ns.App.rename("Renamed after stopping", s.id)
      assert.equal("Renamed after stopping", s.title)
      slash("export")
      assert.truthy(s.exported_at)
      assert.truthy(#printed > 0)
      -- The QuestersBoard address: https only, saved in settings, cleared on request.
      local settings = _G.AdventureChroniclerDB.settings
      assert.equal("", settings.questersboard_url)
      assert.equal("https://example.com/import", ns.App.link())  -- the shipped default
      slash("link http://example.com/import")
      assert.equal("", settings.questersboard_url)
      slash("link https://example.org/board/import")
      assert.equal("https://example.org/board/import", settings.questersboard_url)
      assert.equal("https://example.org/board/import", ns.App.link())
      slash("export")  -- the window opens with the address set
      for _, k in ipairs({ "markdown", "text", "json", "code" }) do ns.ui.export.setKind(k) end
      -- 0.3.4: the import code shows "Paste the code at:" with the address, instead of a button.
      assert.equal("https://example.org/board/import", ns.ui.export.pasteAddress())
      slash("link clear")
      assert.equal("", settings.questersboard_url)
      assert.equal("https://example.com/import", ns.App.link())
      ns.ui.export.setKind("code")
      assert.equal("https://example.com/import", ns.ui.export.pasteAddress())

      -- A community build's values (core/community.lua) come after your own and before the default.
      ns.COMMUNITY.import_url = "https://example.net/wow/import"
      ns.COMMUNITY.invite = "https://example.net/invite"
      ns.COMMUNITY.name = "Example Community"
      assert.equal("https://example.net/wow/import", ns.App.link())
      assert.equal("https://example.net/invite", ns.App.invite())
      slash("community http://example.com/x")  -- refused: not https
      assert.equal("", settings.community_invite)
      slash("community https://example.com/own-invite")
      assert.equal("https://example.com/own-invite", ns.App.invite())
      slash("community clear")
      assert.equal("https://example.net/invite", ns.App.invite())

      -- The settings window opens on each tab; the tick boxes change the same settings as /ac set.
      slash("settings")
      assert.is_true(ns.ui.settings.isShown())
      for _, tab in ipairs(ns.ui.settings.TABS) do ns.ui.settings.open(tab) end
      ns.ui.settings.open("Options")
      local rowsShown = ns.ui.settings.rows()
      assert.truthy(#rowsShown >= 1)
      local parts = ns.ui.settings.parts()
      parts.search:SetText("quest")
      rawget(parts.search, "_OnTextChanged")(parts.search)
      assert.equal("quest", ns.ui.settings.search)
      local lootRow
      for _, r in ipairs(rowsShown) do if r.key == "loot_skip_quest" then lootRow = r end end
      assert.truthy(lootRow)
      lootRow.check.GetChecked = function() return true end
      rawget(lootRow.check, "_OnClick")(lootRow.check)
      assert.is_true(settings.loot_skip_quest)
      slash("set lootquest off"); assert.is_false(settings.loot_skip_quest)
      slash("set lootquality uncommon"); assert.equal(2, settings.loot_min_quality)
      slash("set lootquality all"); assert.equal(0, settings.loot_min_quality)

      -- Report a problem: version and settings, no names, and where to paste it.
      ns.App.noteError("LOOT_READY", "Interface/AddOns/AdventureChronicler/capture/loot.lua:1: |cffff0000boom|r")
      slash("report")
      ns.ui.report.setWhat("The mini recorder didn't show")
      local report = ns.ui.report.text()
      assert.truthy(report:find("Adventure Chronicler 0.3.5", 1, true))
      assert.truthy(report:find("loot.lua:1: boom", 1, true))
      assert.truthy(report:find("What happened: The mini recorder didn't show", 1, true))
      assert.is_nil(report:find("Examplechar", 1, true)); assert.is_nil(report:find("Example Realm", 1, true))
      assert.is_nil(report:find("AC1.", 1, true))
      assert.equal("https://example.net/invite", ns.ui.report.place())

      -- What's new opens on the newest version, and from Help.
      slash("whatsnew")
      assert.is_true(ns.ui.whatsnew.isShown())
      assert.equal("0.3.5", ns.ui.whatsnew.current().version)

      -- The review window's Filter only hides rows.
      slash("review")
      local obsBefore = #s.observations
      ns.ui.review.filter.types.Notes = true
      ns.ui.review.refresh()
      assert.equal(obsBefore, #s.observations)
      ns.reviewfilter.clear(ns.ui.review.filter)

      -- 0.3.5: the status line has the export size; a row's details panel opens and closes; nothing changes.
      ns.ui.review.refresh()
      local bytes = ns.ui.review.exportSize(s)
      assert.truthy(bytes and bytes > 0)
      assert.truthy(ns.ui.review.statusText(s, bytes):find("export ", 1, true))
      local firstObs = { t = 1800000000, obs = { type = "loot.seen", certainty = "seen", t = 1800000000,
        data = { items = { { item_id = 101, name = "Example Rags", count = 2 } } } } }
      ns.ui.details.toggle(_G.UIParent, firstObs)
      assert.is_true(ns.ui.details.isShown())
      local shownText = table.concat(ns.ui.details.texts(), "\n")
      assert.truthy(shownText:find("Example Rags x2", 1, true))
      ns.ui.details.showEntry(_G.UIParent, firstObs)
      ns.ui.details.toggle(_G.UIParent, firstObs)
      assert.is_false(ns.ui.details.isShown())
      assert.equal(obsBefore, #s.observations)

      ns.App.DEFAULT_LINK = ""
      ns.COMMUNITY.import_url = ""
      assert.is_nil(ns.App.link())
      ns.ui.export.setKind("code")  -- no address at all: the field is empty, nothing breaks
      assert.equal("", ns.ui.export.pasteAddress())
    end)
  end)
end)
