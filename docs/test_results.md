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
| 14 | Passed (image): the clean scene screenshot has no interface, minimap, nameplates or names above characters. Whether the settings came back afterwards wasn't reported separately |
