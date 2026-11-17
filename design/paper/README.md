<!-- Written by AI on 2026.11.17 by model claude fable 5.2, at Josh's request. -->

# The design file's screens

The Paper file "RainWatch: design for approval" (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F) is the design Josh approves before the app is changed to match it. Its watch screens are the pictures in `screens/`, drawn by `screens.py`.

They are pictures because Paper could not load Apple's SF Compact when the file was made: the fonts were installed in `~/Library/Fonts` after Paper had started, and Paper lists fonts once at launch. `lib.py` therefore sets every word from the font files' own outlines, so the type is the watch's. If Paper sees the fonts after a restart, the screens could be redrawn as editable layers.

To change a screen, edit `screens.py`, run it, and replace the picture in Paper:

```
cd design/paper
nix shell nixpkgs#resvg -c uv run --with fonttools --with uharfbuzz --with pillow python screens.py
```

Paper keeps the picture it was given, so give a changed screen a new file name, or it will not update.

- `lib.py`: text, Apple's symbols, and the forecast as the app computes it (the rain curve, the spells and the words, ported from `Sources/RainGraph`).
- `screens.py`: one function per screen. Sizes are watch pixels, two per point, on the Ultra 3's 422 by 514 display. They were measured from real screenshots in `renders/simulator/`.
- `sym/`: Apple's symbols as masks, made by `symbols.swift` (`swiftc symbols.swift -o symtool && ./symtool map drop ...`).
- `ref/location-choices.png`: a real screenshot of watchOS's location answers, used as it is.

Look at every picture at full size before it goes into Paper, as AGENTS.md requires.
