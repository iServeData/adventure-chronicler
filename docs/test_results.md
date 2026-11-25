# In-game test results

Only real runs in the game client are listed here. Mocked test results are in CI.

## Run 1: 0.1.0, Windows, WoW Forever 1.60.1 (build 71091), 2026-11-24

| # | Result |
| --- | --- |
| 1 | Loaded with no reported errors |
| 2 | Passed: REC indicator shown, timer counting |
| 3 | Passed: two zone arrivals recorded |
| 10 | Passed: pause and resume recorded as separate segments |
| 11 | Partly checked: the editor opened and saved a short note. The over-limit case wasn't tried |
| 12 | Passed, but the review window listed the bookmark twice. **Fixed in 0.1.1; needs a retest** |
| 13 | Passed: screenshot saved in the Screenshots folder inside `_forever_`, and the marker shows success |
| 14 | Partly passed: the interface and nameplates were hidden and restored, but the minimap ring and the names above characters were still visible. **Fixed in 0.1.1; needs a retest** |
| 20 | Passed: the export copied, the reference validator said valid, and the character name wasn't included |

Not yet run: 4 to 9, 15 to 19 and 21 to 24, and every item on Mac.

## Run 2: 0.1.1, Windows, WoW Forever 1.60.1, 2026-11-24

| # | Result |
| --- | --- |
| 14 | Passed (image): the clean scene screenshot has no interface, minimap, nameplates or names above characters. The interface and chat came back afterwards |
| 1 | Passed: `/ac version` shows 0.1.1 |
| 13 | Passed: the chat message appeared. It said 17:06:15 for a file named `..._170614`, so the time now comes from the request instead of the confirmation |
| 14 | Passed again (image, 17:18:22): clean scene while riding a flight path shows only the scenery and the character on the mount |
| 5 | Passed: a reward choice gave "Reward window opened (2 choices shown)", "Chose a reward ... (probably)", "Turned in" and an inferred "Received" in the export |
| 16 | Passed: `/reload` while recording showed "Recording continues" and the export has a reload gap |
| 22 | Passed (one event): deleting one row is counted in the export as one deletion by the user |
| 20 | Passed (while still recording): the second export passes the reference validator. The first pasted copy had one stray letter, and the validator rejects it as changed, as intended |

Found and fixed in this run: the flight path start logged "Arrived in Desolace" twice, and the export window let review rows show through.

## Run 3: 0.1.1 (before the flight path fix), Windows, WoW Forever 1.60.1, 2026-11-24

| # | Result |
| --- | --- |
| 4 | Passed: a quest with no reward choice gave "Reward window opened" with no choices, then "Turned in", and no chosen or received item |
| 20 | Passed: the export passes the reference validator |

Seen again: taking the zeppelin from Durotar logged a second Durotar arrival when the map changed to the other continent. This build came before the fix; recheck on 0.2.0.

## Run 4: 0.2.0, Windows, WoW Forever 1.60.1, 2026-11-24

| # | Result |
| --- | --- |
| 1 | Passed: `/ac version` shows 0.2.0 |
| 25 | Passed (images): `/ac` opened the recorder, a session started, and it showed "Recording locally" with the time counting and the latest entry |

Found in this run: the recorder used the stock Blizzard frames and looked nothing like the mock. 0.2.1 restyles it. The 0.2.1 look is checked only in a rendered approximation so far, not in game.

## Run 5: 0.2.1, Windows, WoW Forever 1.60.1, 2026-11-24

| # | Result |
| --- | --- |
| 1 | Passed: `/ac version` shows 0.2.1 |
| 25 | Passed (images): the restyled recorder loaded with all its artwork (no missing textures) and shows the latest three entries |
| 26 | Partial: Add note and the Bookmark link worked, and the latest three entries updated. Long notes are cut short with "..." in both windows. Pause and Resume weren't shown |
| 20 | Passed: the export from the restyled export window passes the reference validator (6 observations, 2 notes) |
| 16 | Passed again: a `/reload` while recording shows as a reload gap in the export |
| 27 | Partial: Stop asks first ("Stop" or "Keep recording"). What happens after Stop wasn't shown |

Found in this run, all fixed in 0.2.2:

- The session title couldn't be changed once recording had started.
- Right after a `/reload` the map was briefly the whole continent, which logged "Arrived in Eastern Kingdoms" between two Stranglethorn Vale arrivals.
- One death was logged twice, a second apart.

## Run 6: 0.2.2, Windows, WoW Forever 1.60.1, 2026-11-24

| # | Result |
| --- | --- |
| 1 | Passed: `/ac version` shows 0.2.2 |
| 28 | Passed (images): a session was renamed to "Test" while recording, and a later one to "Sstuf". Chat said "Session renamed", and the new names show in the recorder, the review list and the export |
| 29 | Partial: after a `/reload` the export has a reload gap and no continent line (the Orgrimmar arrival is merged as a repeat). Not yet checked on a boat or zeppelin |
| 26 | Passed: Pause and Resume show as a 3-second paused segment in the export. Bookmark and Add note also worked |
| 27 | Passed: after Stop, a new session started from the recorder. The stopped session stays in the review list |
| 20 | Passed: all three exports pass the reference validator |

Found in this run, fixed in 0.2.3:

- A note opened while the export window was showing appeared underneath it.
- In the recorder, "Arrived in Orgrimmar [+1 repeats]" was cut off. The recorder now leaves the count out, and the review window says "[+1 repeat]".

