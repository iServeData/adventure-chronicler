# Recording and export

## Session states

`recording`, `paused`, then `stopped`. The time is split into segments:

- `recording` and `paused` segments come from your commands. A `paused` segment's reason is `player`, or
  `auto_after_gap` after a long absence.
- `gap` segments are added when you log back in. A gap is a `reload` if it's up to 2 minutes, `offline` if
  it's longer, or `unknown` if there's no last-seen time. An `offline` or `unknown` gap marks the session as
  interrupted. After an offline gap of more than 15 minutes, or an unknown one, the session is paused until
  you type `/ac resume`.

Recorded time counts only `recording` segments. Gaps aren't counted, and the addon never fills them in.

## Certainty

Every observation carries one of these labels:

| Label | Meaning | Example |
| --- | --- | --- |
| `confirmed` | The game reported it directly | Quest turned in, encounter ended |
| `seen` | It was shown to you, which doesn't mean you got it | Reward choices in the quest window, items in a loot window |
| `inferred` | A reasonable reading of indirect evidence | The reward you clicked, a reward item appearing in your bags shortly after |
| `uncertain` | Incomplete, restricted or contradictory | An encounter result the game didn't report |

## Limits

| Limit | Value | When it's reached |
| --- | --- | --- |
| Sessions per character | 50 | The addon asks before removing the oldest stopped session |
| Observations per session | 2,000 | New ones are counted as dropped (shown in review and in the export) |
| Notes and bookmarks per session | 200 | You're told, and nothing is removed |
| Note length | 4,000 characters | Save is disabled and the counter turns red; the text is never cut off |
| Bookmark label | 200 characters | Refused with a message |
| Session name | 120 characters | Refused with a message |
| Export size | 512 KiB | Refused; delete some events in review |

The same event repeated within 60 seconds is merged and counted as a repeat. An event with a timestamp earlier
than the one before it is kept in order and flagged `earlier_than_previous`.

## Export

`/ac export` opens a window with the export already selected. Press Ctrl+C (Cmd+C on a Mac) to copy it.
The text looks like this:

```
ACX1:<byte length>:<crc32, 8 hex digits>:<JSON>
```

Keys are sorted, and the same session always exports the same way. `<`, `>`, `&`, U+2028 and U+2029 are
escaped. Paste the text into the QuestersBoard import form, or save it as a `.txt` file and use the reference
tools:

```
python3 reference/validator/ac_validate.py my_session.txt
python3 reference/scaffold/ac_scaffold.py my_session.txt --format md > my_story.md
```

### Other formats

The export window's Format row also offers readable copies. They're made from the same data as the import
code and follow the same privacy settings.

| Format | What it is | Suggested file name |
| --- | --- | --- |
| Import code | The `ACX1` text above. The only form QuestersBoard and the validator read | `adventure_<date>_<title>_import_code.txt` |
| Markdown | Title, details, timeline, then every note in full | `adventure_<date>_<title>.md` |
| Text | The same as plain text | `adventure_<date>_<title>.txt` |
| JSON | The export document, indented, without the `ACX1` header | `adventure_<date>_<title>.json` |

WoW doesn't let add-ons write files, so keeping one means pasting the copy into a new file yourself. The
title part of the name is lowercase with underscores (`untitled` if the session has no title). Your sessions
are also kept in the add-on's saved-data file in the game folder, but that file is the add-on's storage, not an
export.

### QuestersBoard button

WoW doesn't let add-ons open a browser either. Open QuestersBoard shows your community's address, selected,
so Ctrl+C copies it for your browser. Set the address once with `/ac link https://...`; only `https://`
addresses are accepted, and `/ac link clear` removes it. The add-on ships with no address.
