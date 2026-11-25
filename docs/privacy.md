# Privacy

Adventure Chronicler keeps everything on your computer, in the game's normal saved-data files. It has no
network access, no telemetry and no analytics. Nothing leaves your computer unless you copy an export and
paste it somewhere yourself.

## When it records

Only between `/ac start` and `/ac stop`, and only while not paused. A REC / PAUSED indicator is shown the
whole time, either full size or as a small tab with a red or gold dot. You can choose to hide it completely
with `/ac set indicator hide` (off by default); then chat says "Adventure Chronicler is recording" when a
session starts, resumes or continues after login, and the minimap button shows the dot. If the game closes or crashes, the next login records a gap and doesn't pretend you were
recording. After a long gap the session is paused until you resume it.

## What it records

| Recorded | Default |
| --- | --- |
| Zones, instance entry and exit | On |
| Boss encounter start, end and result | On |
| Quests you accept, with their objectives and short objective summary; objective progress; the quests already in your log when you press Start | On |
| The quest giver's full quest text | **Off** (`/ac set questtext on`). Left out of exports unless it's on when you export |
| Quest reward window, reward chosen, quest turned in, reward items that appear in your bags | On |
| Battleground entry, result and exit, and your own deaths | On (`/ac set pvp off`) |
| Items shown in your own loot window | **Off** (`/ac set loot on`) |
| Your notes, bookmarks and screenshot markers (not the images) | When you add them |

## What it never records

Chat, whispers, emotes, other players' names (including group, raid and battleground members and opponents),
Battle.net identifiers, the combat log, your location coordinates, or anything about other addons.

## What goes into an export

| Field | Default |
| --- | --- |
| Character class and level | Included (`/ac set classlevel off`) |
| Character name and realm | **Not included** (`/ac set identity on`) |
| Game client version, build and locale | Included, to help with compatibility |

Before you copy it, the export dialog says whether your name is included.

## Screenshots

The addon never reads, stores or uploads screenshot images. It only notes that one was taken. The clean scene
preset hides the interface, the minimap, nameplates and the names above characters for a moment. **That
doesn't anonymise everything on screen.** Chat bubbles, guild banners, signs and other text in the world can
still appear. Check a
screenshot before you share it.

## Deleting

In `/ac review` you can delete a whole session, a single event or a note. Before you delete a session with
notes that were never exported, the addon warns you.

## AI

The addon doesn't use AI. The reference story scaffold is deterministic and doesn't use AI either. Nothing
here sends your data to an AI service. Any future feature that might do that would ask you first, every time.
