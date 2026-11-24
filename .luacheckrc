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
    "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "ChatFontNormal", "DEFAULT_CHAT_FRAME",
    "StaticPopup_Show", "hooksecurefunc", "C_Timer", "C_CVar", "C_Map", "C_Item", "C_QuestLog",
    "InCombatLockdown", "Screenshot", "GetBuildInfo", "GetLocale", "UnitClass", "UnitName", "UnitLevel",
    "GetRealmName", "GetInstanceInfo", "GetRealZoneText", "date", "time", "tinsert", "bit",
    "issecretvalue", "UnitFactionGroup", "GetBattlefieldWinner",
  },
}

files["tests"] = { std = "+busted", globals = { "_G" } }
