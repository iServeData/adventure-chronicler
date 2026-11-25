# Adventure Chronicler

Adventure Chronicler (a provisional name) is a World of Warcraft addon for WoW Forever. You turn it on when you
want to remember an adventure. It notes the places you visit, the quests you turn in, the bosses you fight and
your battleground results, along with notes and bookmarks you write. When you're done, you can copy the session
out as a checked text export and turn it into a story. The story can be a private QuestersBoard Chronicle draft
or a Markdown, text or HTML file.

> Status: prototype, version 0.2.0. It has had **one partial in-game test** (Windows; see [docs/test_results.md](docs/test_results.md)). The automated tests run
> against a mocked game API (see [docs/testing.md](docs/testing.md)).

## What it does and doesn't do

- It only records while you've started a session. A visible REC / PAUSED indicator shows whenever it's
  recording or paused.
- It records your own activity: zones, instance entry and exit, boss encounter results, quest turn-ins and
  reward choices, battleground results, your own deaths, and bookmarks.
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
| `/ac shot` / `/ac shot clean` | Take a screenshot as seen, or a clean scene (outside combat) |
| `/ac stop` | End the session |
| `/ac review` | Review, edit or delete sessions, notes and events |
| `/ac export` | Show the latest session's export text to copy |
| `/ac options`, `/ac set <setting> on\|off` | Show or change settings |

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
