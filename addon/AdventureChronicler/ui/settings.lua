-- Adventure Chronicler: the settings window. Tabs run A-Z with Help last: Community, Export, Options,
-- Help. Options groups every setting into categories (A-Z) as tick boxes, with a search box; each one can
-- still be changed in chat with /ac set. Nothing here sends anything anywhere.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local T = { tab = "Options", category = "Loot", search = "" }
ns.ui.settings = T

T.TABS = { "Community", "Export", "Options", "Help" }

local f, version, searchBox, searchInput
local tabButtons, panels = {}, {}
local catButtons, rows = {}, {}
local opt = {}   -- Options panel parts
local com = {}   -- Community panel parts
local exp = {}   -- Export panel parts

local ROW_H = 40

local function W() return ns.ui.widgets end
local function App() return ns.App end

-- ----------------------------------------------------------------- Options

local function qualityChoices()
  local out = {}
  for _, q in ipairs(ns.options.MIN_QUALITY_CHOICES) do out[#out + 1] = { q, ns.options.qualityChoiceLabel(q) } end
  return out
end

local function optionRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Frame", nil, opt.body)
  r:SetHeight(ROW_H - 4)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetPoint("RIGHT", opt.body, "RIGHT", 0, 0)
  r.label = W().text(r, "body", 13, W().GOLD)
  r.label:SetPoint("TOPLEFT", 0, -2)
  r.label:SetPoint("RIGHT", -170, 0)
  r.label:SetJustifyH("LEFT")
  r.help = W().text(r, "body", 11, W().MUTED)
  r.help:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
  r.help:SetPoint("RIGHT", -170, 0)
  r.help:SetJustifyH("LEFT")
  r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.check:SetSize(26, 26)
  r.check:SetPoint("RIGHT", -4, 0)
  r.check:SetScript("OnClick", function(self)
    if r.key then App().settings[r.key] = self:GetChecked() == true; App().refresh() end
  end)
  r.choice = W().choice(r, 170, qualityChoices(), function(v)
    if r.key then App().settings[r.key] = v; App().refresh() end
  end)
  r.choice:SetPoint("RIGHT", -2, 0)
  rows[i] = r
  return r
end

local function showOptions(list, heading, note)
  opt.heading:SetText(heading)
  for _, r in ipairs(rows) do r:Hide() end
  for i, o in ipairs(list) do
    local r = optionRow(i)
    r.key = o.key
    r.label:SetText(T.search ~= "" and (o.cat .. ": " .. o.label) or o.label)
    r.help:SetText(o.help or "")
    local quality = o.kind == "quality"
    r.check:SetShown(not quality); r.choice:SetShown(quality)
    if quality then r.choice:SetValue(tonumber(App().settings[o.key]) or 0); r.choice.menu:Hide()
    else r.check:SetChecked(App().settings[o.key] == true) end
    r:Show()
  end
  opt.empty:SetShown(#list == 0)
  opt.note:SetText(note or "")
  opt.shown = list
end

local function refreshOptions()
  if T.search ~= "" then
    local found = ns.options.search(T.search)
    opt.empty:SetText("No setting matches \"" .. T.search .. "\".")
    showOptions(found, "Search", nil)
  else
    showOptions(ns.options.inCategory(T.category), T.category, ns.options.NOTES[T.category])
  end
  for cat, b in pairs(catButtons) do b.selected:SetShown(T.search == "" and cat == T.category) end
end

local function buildOptions(p)
  local list = CreateFrame("Frame", nil, p)
  list:SetPoint("TOPLEFT", 0, 0); list:SetPoint("BOTTOMLEFT", 0, 0); list:SetWidth(150)
  local edge = list:CreateTexture(nil, "ARTWORK")
  edge:SetColorTexture(W().GOLD[1], W().GOLD[2], W().GOLD[3], 0.5)
  edge:SetWidth(1); edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT")
  local title = W().text(list, "title", 16, W().CREAM)
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("Options")
  for i, cat in ipairs(ns.options.CATEGORIES) do
    local b = CreateFrame("Button", nil, list)
    b:SetSize(148, 26)
    b:SetPoint("TOPLEFT", 1, -40 - (i - 1) * 28)
    b:SetHighlightTexture(W().media("button_glow"), "ADD")
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetTexture(W().media("button_dark"))
    b.label = W().text(b, "body", 13, W().GOLD)
    b.label:SetPoint("LEFT", 18, 0)
    b.label:SetText(cat)
    b:SetScript("OnClick", function()
      T.category, T.search = cat, ""
      if searchInput then searchInput:SetText(""); searchInput:ClearFocus() end
      refreshOptions()
    end)
    catButtons[cat] = b
  end
  local right = CreateFrame("Frame", nil, p)
  right:SetPoint("TOPLEFT", 170, -10); right:SetPoint("BOTTOMRIGHT", -14, 10)
  opt.heading = W().text(right, "title", 20, W().CREAM)
  opt.heading:SetPoint("TOPLEFT", 0, -2)
  W().divider(right, -34, 0)
  opt.body = CreateFrame("Frame", nil, right)
  opt.body:SetPoint("TOPLEFT", 0, -46); opt.body:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  opt.body:SetHeight(5 * ROW_H)
  opt.empty = W().text(right, "body", 12, W().MUTED)
  opt.empty:SetPoint("TOPLEFT", 0, -50)
  opt.note = W().text(right, "body", 11, W().MUTED)
  opt.note:SetPoint("BOTTOMLEFT", 0, 36); opt.note:SetPoint("RIGHT", right, "RIGHT", -110, 0)
  opt.note:SetJustifyH("LEFT")
  local defaults = W().button(right, "Defaults", 96, function()
    ns.options.reset(App().settings, App().DEFAULT_SETTINGS, opt.shown or {})
    App().refresh()
  end)
  defaults:SetPoint("BOTTOMRIGHT", 0, 0)
  T.defaultsButton = defaults
end

-- --------------------------------------------------------------- Community

local function refreshCommunity()
  local C = ns.COMMUNITY or {}
  local name = C.name ~= nil and C.name ~= "" and C.name or nil
  local invite = App().invite()
  local board = App().validLink(C.board_url)
  com.heading:SetText(name or "Community")
  if invite then
    com.blurb:SetText(name and ("Join the " .. name .. " Discord to plan adventures, share your stories and get "
      .. "news about the add-on.") or "Your community's invite, to copy.")
    com.invite:SetValue(invite)
    com.hint:SetText("Press Ctrl+C (Cmd+C on Mac) to copy the invite link, then paste it in your browser.")
  else
    com.blurb:SetText("No community invite is set in this copy of the add-on. If your community has one, type it "
      .. "in chat:\n|cffffd100/ac community https://your-invite-address|r")
    com.hint:SetText("")
  end
  com.invite:SetShown(invite ~= nil)
  com.boardLabel:SetShown(board ~= nil); com.board:SetShown(board ~= nil)
  if board then com.board:SetValue(board) end
end

local function buildCommunity(p)
  com.heading = W().text(p, "title", 22, W().CREAM)
  com.heading:SetPoint("TOPLEFT", 22, -14)
  W().divider(p, -48, 20)
  com.blurb = W().text(p, "body", 13, W().GOLD)
  com.blurb:SetPoint("TOPLEFT", 22, -64); com.blurb:SetPoint("RIGHT", -22, 0)
  com.blurb:SetJustifyH("LEFT")
  com.invite = W().readonly(p, 28)
  com.invite:SetPoint("TOPLEFT", 22, -112); com.invite:SetWidth(300)
  com.hint = W().text(p, "body", 11, W().MUTED)
  com.hint:SetPoint("TOPLEFT", 22, -146)
  com.boardLabel = W().text(p, "body", 13, W().GOLD)
  com.boardLabel:SetPoint("TOPLEFT", 22, -186)
  com.boardLabel:SetText("Your QuestersBoard:")
  com.board = W().readonly(p, 26)
  com.board:SetPoint("LEFT", com.boardLabel, "RIGHT", 10, 0); com.board:SetPoint("RIGHT", p, "RIGHT", -22, 0)
end

-- ------------------------------------------------------------------ Export

local function refreshExport()
  local own = App().validLink(App().settings.questersboard_url)
  exp.current:SetValue(App().link() or "")
  exp.whose:SetText(own and "Your own address (set here or with /ac link)." or "The add-on's address.")
end

local function buildExport(p)
  local h = W().text(p, "title", 22, W().CREAM)
  h:SetPoint("TOPLEFT", 22, -14); h:SetText("Export")
  W().divider(p, -48, 20)
  local l1 = W().text(p, "body", 13, W().GOLD)
  l1:SetPoint("TOPLEFT", 22, -64); l1:SetText("The export window says to paste the import code at:")
  exp.current = W().readonly(p, 26)
  exp.current:SetPoint("TOPLEFT", 22, -86); exp.current:SetPoint("RIGHT", p, "RIGHT", -22, 0)
  exp.whose = W().text(p, "body", 11, W().MUTED)
  exp.whose:SetPoint("TOPLEFT", 22, -118)
  local l2 = W().text(p, "body", 13, W().GOLD)
  l2:SetPoint("TOPLEFT", 22, -150); l2:SetText("Use my own address instead (https:// only):")
  local box, input = W().input(p, 26)
  box:SetPoint("TOPLEFT", 22, -172); box:SetPoint("RIGHT", p, "RIGHT", -230, 0)
  exp.input = input
  local save = W().button(p, "Save", 70, function()
    App().setLink(input:GetText()); input:SetText(""); input:ClearFocus(); refreshExport()
  end, "gold")
  save:SetPoint("LEFT", box, "RIGHT", 8, 0)
  local back = W().button(p, "Use the add-on's", 130, function() App().setLink("clear"); refreshExport() end)
  back:SetPoint("LEFT", save, "RIGHT", 6, 0)
  input:SetScript("OnEnterPressed", function() save:Click() end)
  local latest = W().button(p, "Export the latest session", 190, function() App().export() end)
  latest:SetPoint("BOTTOMLEFT", 22, 16)
end

-- -------------------------------------------------------------------- Help

local HELP_LINES = {
  { "/ac", "open the Adventure Recorder" },
  { "/ac start, /ac pause, /ac stop", "recording" },
  { "/ac note, /ac mark", "a note or a bookmark" },
  { "/ac review", "your sessions, with a filter" },
  { "/ac export", "copy an import code" },
  { "/ac settings", "this window" },
  { "/ac set minimap off", "hide the compass" },
  { "/ac help", "every command, in chat" },
}

local function buildHelp(p)
  local h = W().text(p, "title", 22, W().CREAM)
  h:SetPoint("TOPLEFT", 22, -14); h:SetText("Help")
  W().divider(p, -48, 20)
  local report = W().button(p, "Report a problem", 150, function() App().reportProblem() end, "gold", 28)
  report:SetPoint("TOPLEFT", 22, -64)
  local news = W().button(p, "What's new", 120, function() App().whatsNew() end, "dark", 28)
  news:SetPoint("LEFT", report, "RIGHT", 10, 0)
  for i, l in ipairs(HELP_LINES) do
    local t = W().text(p, "body", 13, W().CREAM)
    t:SetPoint("TOPLEFT", 22, -108 - (i - 1) * 24)
    t:SetText("|cffd6ab5c" .. l[1] .. "|r  " .. l[2])
  end
end

-- ------------------------------------------------------------------ window

local function selectTab(name)
  T.tab = name
  for n, b in pairs(tabButtons) do W().restyle(b, n == name and "gold" or "dark") end
  for n, p in pairs(panels) do p:SetShown(n == name) end
  searchBox:SetShown(name == "Options")
  T.refresh()
end

local function build()
  f = W().window("AdventureChroniclerSettings", "Adventure Chronicler", 660, 470, { compass = true, header = 40 })
  f:SetFrameStrata("HIGH")
  version = W().text(f, "body", 11, W().MUTED)
  version:SetPoint("RIGHT", f.closeButton, "LEFT", -12, 0)
  local prev
  for _, name in ipairs(T.TABS) do
    local n = name
    local b = W().button(f, name, 100, function() selectTab(n) end, "dark", 26)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 20, -50) end
    tabButtons[name] = b
    prev = b
  end
  searchBox, searchInput = W().input(f, 26)
  searchBox:SetPoint("TOPRIGHT", -20, -50); searchBox:SetWidth(200)
  local placeholder = W().text(searchBox, "body", 12, W().INK)
  placeholder:SetPoint("LEFT", 10, 0); placeholder:SetText("Search options"); placeholder:SetAlpha(0.6)
  searchInput:SetScript("OnTextChanged", function(self)
    T.search = self:GetText() or ""
    placeholder:SetShown(T.search == "")
    if T.tab == "Options" then refreshOptions() end
  end)
  for _, name in ipairs(T.TABS) do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 16, -84); p:SetPoint("BOTTOMRIGHT", -16, 16)
    local shade = p:CreateTexture(nil, "BACKGROUND", nil, 2)
    shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.25)
    panels[name] = p
  end
  buildCommunity(panels.Community)
  buildExport(panels.Export)
  buildOptions(panels.Options)
  buildHelp(panels.Help)
end

function T.refresh()
  if not f or not f:IsShown() then return end
  version:SetText(App().VERSION)
  if T.tab == "Options" then refreshOptions()
  elseif T.tab == "Community" then refreshCommunity()
  elseif T.tab == "Export" then refreshExport() end
end

function T.open(tab)
  if not f then build() end
  f:Show()
  f:Raise()
  selectTab(tab or T.tab)
end

function T.isShown() return f ~= nil and f:IsShown() == true end
function T.rows() return rows end
function T.parts() return { options = opt, community = com, export = exp, search = searchInput } end

return T
