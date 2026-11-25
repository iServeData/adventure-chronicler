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
