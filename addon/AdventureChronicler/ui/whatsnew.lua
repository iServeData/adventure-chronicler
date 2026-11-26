-- Adventure Chronicler: What's new. The versions on the left, the chosen version's changes on parchment,
-- with Newer and Older. The text comes from core/changelog_data.lua, built from changelog.toml, so it says
-- the same as CHANGELOG.md and the QuestersBoard add-on page. It opens once after an update (unless that's
-- turned off in Settings) and any time from Help or /ac whatsnew.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local N = { index = 1 }
ns.ui.whatsnew = N

local f, listChild, pageChild, pageScroll, pageText, pageHead, pageMeta, newer, older, showCheck
local versionRows = {}

local KIND_COLOUR = { New = "6fd36f", Improved = "d6ab5c", Fixed = "7fb4ff" }

-- Changelog text for a WoW font string: "|" would start an escape code, so it's doubled, and `code`
-- is shown in gold instead of backticks.
function N.format(text)
  local s = tostring(text or ""):gsub("|", "||")
  s = s:gsub("`([^`]+)`", "|cffffd100%1|r")
  return s
end

-- The page for one release, as one block of text.
function N.page(r)
  local parts = {}
  for _, c in ipairs(r.changes or {}) do
    parts[#parts + 1] = string.format("|cff%s%s|r  |cff8a6a3a%s|r\n%s", KIND_COLOUR[c.kind] or "ffffff",
      c.kind, c.area, N.format(c.text))
  end
  return table.concat(parts, "\n\n")
end

local function releases() return ns.CHANGELOG or {} end

local function refresh()
  local list = releases()
  N.index = math.max(1, math.min(N.index, #list))
  for i, b in ipairs(versionRows) do b.selected:SetShown(i == N.index) end
  local r = list[N.index]
  if not r then pageHead:SetText("No changes listed"); pageMeta:SetText(""); pageText:SetText("") return end
  pageHead:SetText(r.version .. "  " .. N.format(r.title))
  pageMeta:SetText(r.date .. " · " .. r.status)
  pageText:SetText(N.page(r))
  pageScroll.setContentHeight((tonumber(pageText:GetStringHeight()) or 0) + 20)
  pageScroll.toTop()
  newer:SetEnabled(N.index > 1)
  older:SetEnabled(N.index < #list)
  showCheck:SetChecked(ns.App.settings.whats_new_on_update == true)
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerWhatsNew", "What's new", 680, 460, { compass = true, header = 40 })
  f:SetFrameStrata("FULLSCREEN_DIALOG")

  local list
  list, listChild = W.scroll(f, 150, 340)
  list:SetPoint("TOPLEFT", 16, -54)
  for i, r in ipairs(releases()) do
    local idx = i
    local b = CreateFrame("Button", nil, listChild)
    b:SetSize(140, 24)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
    b:SetHighlightTexture(W.media("button_glow"), "ADD")
    b.selected = b:CreateTexture(nil, "BACKGROUND")
    b.selected:SetAllPoints()
    b.selected:SetTexture(W.media("button_dark"))
    b.label = W.text(b, "body", 13, W.GOLD)
    b.label:SetPoint("LEFT", 10, 0)
    b.label:SetText(r.version .. (i == 1 and "  |cffa89880newest|r" or ""))
    b:SetScript("OnClick", function() N.index = idx; refresh() end)
    versionRows[i] = b
  end
  list.setContentHeight(#versionRows * 26)

  local paper = W.parchment(f)
  paper:SetPoint("TOPLEFT", 186, -54)
  paper:SetPoint("BOTTOMRIGHT", -18, 56)
  pageHead = W.text(paper, "title", 19, W.INK)
  pageHead:SetPoint("TOPLEFT", 16, -12)
  pageHead:SetPoint("RIGHT", -16, 0)
  pageHead:SetJustifyH("LEFT")
  pageMeta = W.text(paper, "body", 11, W.INK)
  pageMeta:SetPoint("TOPLEFT", 16, -38)
  pageMeta:SetAlpha(0.75)
  local scroll
  scroll, pageChild = W.scroll(paper, 420, 280)
  scroll:SetPoint("TOPLEFT", 14, -60)
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  pageScroll = scroll
  scroll:SetScript("OnSizeChanged", function(_, w) pageChild:SetWidth(math.max(50, w)); pageText:SetWidth(w - 6) end)
  pageText = W.text(pageChild, "body", 13, W.INK)
  pageText:SetPoint("TOPLEFT", 2, 0)
  pageText:SetWidth(414)
  pageText:SetJustifyH("LEFT")
  pageText:SetJustifyV("TOP")
  pageText:SetSpacing(2)

  showCheck = W.check(f, "Show this after an update", function(on)
    ns.App.settings.whats_new_on_update = on
  end)
  showCheck:SetPoint("BOTTOMLEFT", 16, 16)
  local close = W.button(f, "Close", 80, function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -18, 16)
  older = W.button(f, "Older", 80, function() N.index = N.index + 1; refresh() end)
  older:SetPoint("RIGHT", close, "LEFT", -14, 0)
  newer = W.button(f, "Newer", 80, function() N.index = N.index - 1; refresh() end)
  newer:SetPoint("RIGHT", older, "LEFT", -6, 0)
end

function N.open(version)
  if not f then build() end
  N.index = 1
  if version then
    for i, r in ipairs(releases()) do if r.version == version then N.index = i end end
  end
  f:Show()
  f:Raise()
  refresh()
end

function N.isShown() return f ~= nil and f:IsShown() == true end
function N.current() return releases()[N.index] end

return N
