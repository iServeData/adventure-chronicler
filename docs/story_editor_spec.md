# Story editor specification

This describes how a story is built from a recorded session. It applies to the reference scaffold and to any
importer, such as a QuestersBoard draft.

## Principles

1. **Deterministic.** The same export always gives the same draft. There's no AI at runtime.
2. **Nothing invented.** No dialogue, feelings, loot, companions, victories or outcomes that weren't recorded
   or written by the author.
3. **Placeholders for the unknown.** Anything not recorded is a bracketed placeholder that the author
   replaces, such as `[What did you set out to do?]`.
4. **Certainty is shown.** "(probably)", "(seen)" and "(uncertain)" stay in the timeline text until the author
   edits them out.
5. **Gaps are visible.** An interrupted recording shows where it stopped and that what happened next isn't
   known.
6. **No silent truncation.** Long fields end with an explicit "...and N more" line.
7. **Private by default.** A draft is visible only to its author until they publish it through the normal
   process.

## Fields

See the mapping in [schema.md](schema.md#mapping-to-a-questersboard-chronicle-draft).

## Output formats

Markdown, plain text and HTML are for keeping a story locally. The HTML is fully escaped and loads nothing
external. JSON is for an import form.
