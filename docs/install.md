# Install

The prototype has no download or listing yet. To try it from a copy of this repository:

1. Close the game.
2. Copy the folder `addon/AdventureChronicler` into the addons folder for WoW Forever:
   - Windows: `<World of Warcraft folder>\_forever_\Interface\AddOns\`
   - Mac: `<World of Warcraft folder>/_forever_/Interface/AddOns/`

   Community guides give the default locations as `C:\Program Files (x86)\World of Warcraft\_forever_\` on
   Windows and `/Applications/World of Warcraft/_forever_/` on a Mac. If you installed the game somewhere else,
   use that folder instead. The result should be
   `.../_forever_/Interface/AddOns/AdventureChronicler/AdventureChronicler.toc`.
3. Start the game. At the character screen, open **AddOns** and make sure Adventure Chronicler is enabled.
   Screenshots go to the `Screenshots` folder in the same `_forever_` folder.
4. In the game, type `/ac` to open the review window, or `/ac help` for the commands.

To remove it, delete the `AdventureChronicler` folder. Your saved sessions stay in the account's
`WTF` folder until you delete them there too. You can also delete them in `/ac review`.

You can also build a zip with `python3 tools/build_zip.py`. The zip goes to `dist/`.
