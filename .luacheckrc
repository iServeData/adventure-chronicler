-- luacheck configuration. WoW globals the addon reads or writes are listed explicitly.
std = "lua51"
max_line_length = 120
codes = true
ignore = { "212/self", "211/ADDON" }

files["addon"] = {
  globals = {
    "AdventureChroniclerDB", "AdventureChroniclerCharDB", "AdventureChronicler_OnCompartmentClick",
    "SLASH_ADVENTURECHRONICLER1", "SLASH_ADVENTURECHRONICLER2", "SlashCmdList", "StaticPopupDialogs",
  },
  read_globals = {
    "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "Minimap", "GetCursorPosition", "ChatFontNormal", "DEFAULT_CHAT_FRAME",
    "StaticPopup_Show", "hooksecurefunc", "C_Timer", "C_CVar", "C_Map", "C_Item", "C_QuestLog",
    "InCombatLockdown", "Screenshot", "GetBuildInfo", "GetLocale", "UnitClass", "UnitName", "UnitLevel",
    "GetRealmName", "GetInstanceInfo", "GetRealZoneText", "date", "time", "tinsert", "bit",
    "issecretvalue", "UnitFactionGroup", "GetBattlefieldWinner",
  },
}

files["tests"] = { std = "+busted", globals = { "_G" } }

-- Built from changelog.toml by tools/build_changelog.py; each change is one line.
files["addon/AdventureChronicler/core/changelog_data.lua"] = { max_line_length = false }
