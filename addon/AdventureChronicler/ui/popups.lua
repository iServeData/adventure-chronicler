-- Adventure Chronicler: confirmation dialogs. Destructive actions always ask first.
local _, ns = ...
ns = ns or {}

StaticPopupDialogs["ADVENTURECHRONICLER_START_PROMPT"] = {
  text = "Adventure Chronicler: start recording a session in %s?",
  button1 = "Start", button2 = "Not now",
  OnAccept = function() ns.App.start() end,
  timeout = 30, whileDead = false, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["ADVENTURECHRONICLER_REMOVE_OLDEST"] = {
  text = "You've reached the session limit. Delete your oldest stopped session to start a new one?%s",
  button1 = "Delete and start", button2 = "Cancel",
  OnAccept = function(_, data) ns.App.removeOldestThenStart(data.id, data.title) end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

StaticPopupDialogs["ADVENTURECHRONICLER_STOP"] = {
  text = "Stop recording %s? You can still review and export it, and continue it later from the review window.",
  button1 = "Stop", button2 = "Keep recording",
  OnAccept = function() ns.App.stop() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["ADVENTURECHRONICLER_DELETE_SESSION"] = {
  text = "Delete this session and everything in it? This can't be undone.%s",
  button1 = "Delete", button2 = "Cancel",
  OnAccept = function(_, data)
    ns.Session.deleteSession(ns.App.db, data.id)
    ns.App.print("Session deleted.")
    ns.App.refresh()
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

StaticPopupDialogs["ADVENTURECHRONICLER_UNSAVED_NOTE"] = {
  text = "Your note isn't saved. Keep editing or discard it?",
  button1 = "Keep editing", button2 = "Discard",
  OnAccept = function() ns.ui.notes.reopen() end,
  OnCancel = function(_, _, reason) if reason == "clicked" then ns.ui.notes.discard() else ns.ui.notes.reopen() end end,
  timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

StaticPopupDialogs["ADVENTURECHRONICLER_CONTINUE"] = {
  text = "Continue %s? The time since you stopped will show as a pause.",
  button1 = "Continue", button2 = "Cancel",
  OnAccept = function(_, data) ns.App.continue(data.id, true) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
