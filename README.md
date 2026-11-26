# Adventure Chronicler

Adventure Chronicler (a provisional name) is a World of Warcraft addon for WoW Forever. You turn it on when you
want to remember an adventure. It notes the places you visit, the quests you turn in, the bosses you fight and
your battleground results, along with notes and bookmarks you write. When you're done, you can copy the session
out as a checked text export and turn it into a story. The story can be a private QuestersBoard Chronicle draft
or a Markdown, text or HTML file.

> Status: prototype, version 0.3.3. It has had **seven partial in-game test runs** (Windows; see [docs/test_results.md](docs/test_results.md)). The automated tests run
> against a mocked game API (see [docs/testing.md](docs/testing.md)).

## What it does and doesn't do

- It only records while you've started a session. While it's recording or paused, the compass button on
  the minimap shows a red (recording) or gold (paused) dot, and the mini recorder (REC / PAUSED, the time
  and small buttons) shows whenever the Adventure Recorder window is closed. The mini recorder's x hides it.
  It comes back from the compass and after a login or `/reload`. If the minimap button is off, closing the
  mini recorder says once in chat that it's still recording.
- The compass button on the minimap opens the Adventure Recorder, or while a session is open, the mini
  recorder (its first button opens the Adventure Recorder). Drag it around the minimap;
  `/ac set minimap off` hides it, and `/ac` always works.
- It records your own activity: zones, instance entry and exit, boss encounter results, quests you accept
  with their objectives and progress, quest turn-ins and reward choices, battleground results, your own deaths, and bookmarks.
- Off by default: personal loot, your character name and realm in exports, and the "start recording?" prompt
  when you enter an instance.
- Never: chat or whispers, other players' names, Battle.net identifiers, party member names, the combat log,
  telemetry, network access or automation. The addon can't send anything anywhere. Exporting means you copy
  text yourself.
- It records what the game reports and labels how sure it is (confirmed, seen, probably, uncertain). Entering
  a dungeon isn't treated as clearing it. Seeing a reward isn't treated as receiving it. One boss kill is one
  boss kill.

## Commands

| Command | What it does |
| --- | --- |
| `/ac` | Open or close the recorder window |
| `/ac start [name]` | Start a session |
| `/ac pause` / `/ac resume` | Pause or continue recording |
| `/ac note [text]` | Add a note. With no text, it opens the editor. |
| `/ac mark [label]` | Add a bookmark |
| `/ac title <name>` | Rename the session that is open (or click the title in the recorder). Any session, stopped too, can be renamed from its title in `/ac review` |
| `/ac shot` / `/ac shot clean` | Take a screenshot as seen, or a clean scene (outside combat) |
| `/ac stop` | End the session |
| `/ac review` | Review, edit or delete sessions, notes and events. The line under the title shows the export size. Hover an event for a tooltip (the game's own for items); click it for everything recorded |
| `/ac export` | Show the latest session to copy: the import code for QuestersBoard, or Markdown, Text or JSON to keep as a file |
| `/ac link <https://...>` | Set the address the export window says to paste the code at. It starts as your community's address (or the placeholder `https://example.com/import` in the public build); `/ac link clear` goes back to it |
| `/ac settings` (or `/ac options`) | Open the Settings window: Community, Export, Options (searchable, by category) and Help |
| `/ac community <https://...>` | Set the invite shown on the Community tab and in Report a problem; `/ac community clear` goes back to the add-on's |
| `/ac report` | Report a problem: a short report to copy, with versions, settings and the last error the add-on caught. No names |
| `/ac whatsnew` | Show what changed in each version. It also opens once after an update (`/ac set whatsnew off` to stop that) |
| `/ac set lootquality all\|common\|uncommon\|rare\|epic` | Lowest loot quality recorded. `/ac set lootquest`, `loottrade` and `lootjunk on\|off` leave out quest items, trade goods and grey items |
| `/ac set <setting> on\|off` | Change settings (`prompt`, `pvp`, `loot`, `identity`, `classlevel`, `buttons`, `questtext`). `questtext` (off by default) also keeps the quest giver's full text. `buttons` shows or hides the small Open, Note, Bookmark, Pause, Stop, Export and Review buttons on the mini recorder. `minimap off\|on` hides or shows the minimap button |

If another addon already uses `/ac`, use `/advchron` instead.

## Repository layout

| Path | Contents |
| --- | --- |
| `addon/AdventureChronicler/` | The addon. This folder is all that goes in the zip. |
| `schema/` | JSON Schema for the export format |
| `reference/validator/` | Python (standard library) validator for exports |
| `reference/scaffold/` | Python story scaffold (Markdown, text, HTML or JSON for an import form) |
| `tests/` | Mocked Lua tests (busted) and the committed export fixture |
| `tools/` | Hygiene check, schema generator and zip builder |
| `docs/` | Install, privacy, schema, security, testing and design notes |

## Documentation

- [Supported clients](docs/supported_clients.md) and [compatibility](docs/compatibility.md)
- [Install](docs/install.md)
- [Privacy](docs/privacy.md)
- [Recording and export](docs/recording_and_export.md)
- [Export schema and the QuestersBoard mapping](docs/schema.md)
- [Security and threat model](docs/security.md)
- [Testing and the in-game checklist](docs/testing.md), [in-game results](docs/test_results.md)
- [Release checklist](docs/release_checklist.md)
- [Story editor specification](docs/story_editor_spec.md)
- [Future desktop companion (design only)](docs/future_companion.md)

## Rules this project follows

The addon is free, and its code is visible to anyone, as Blizzard's UI add-on policy requires. It has no ads,
donation prompts or paid features, and it doesn't automate gameplay. It's an independent project and is not
made, endorsed or supported by Blizzard Entertainment.

## Licence

No licence has been chosen yet. Until one is added, you can read the code, but no permission is granted to
copy, modify or redistribute it.
