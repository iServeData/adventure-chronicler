# Supported clients

| Client | Status |
| --- | --- |
| WoW Forever (interface 16001) | Target for 0.1.0. **Not yet tested in the client.** |
| Retail, Classic Era, Anniversary, Mists Classic | Not supported. The addon may load if the interface number is changed, but nothing has been checked. |

WoW Forever uses the modern game API. Some values that are restricted during combat (Blizzard calls them
"secret values") can't be read by addons. When an event carries one, Adventure Chronicler leaves that field
out and marks the observation as uncertain. It never tries to get around the restriction. The combat log
isn't used.

The interface number and client details come from public community reports, not from Blizzard
documentation. They'll be confirmed in the in-game checklist (see [testing.md](testing.md)).
