# Design files

Screen designs for lottoApp2, kept in the repo next to the tickets that need them.

## Layout

- `design/proposal/<id>-<slug>.html` — a draft for ticket `LTA-<id>`, lo-fi, open to change.
- `design/final/<screen>.html` — an approved design, the one implementation builds from.
- Each HTML file has a sibling `.png` snapshot with the same basename, rendered from it. The PNG is
  not listed in a ticket's `designs`; the HTML is.

## Format

- One self-contained HTML file per screen (or per flow): no external assets, fonts or scripts.
- Frames are iPhone-width (375 pt) and show every state the ticket names, in light mode, plus at
  least one frame in dark mode.
- Colors come from the app's asset catalog (`Assets.xcassets`), declared as CSS variables with the
  asset's name, so a design reads in the same tokens the code uses.
- Copy is the real copy the screen will show — no lorem ipsum.
- Each frame carries a short caption naming its state; notes for the implementer go below the frames.

## Rendering the snapshot

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --window-size=1640,1900 --screenshot=design/proposal/<id>-<slug>.png "file://$PWD/design/proposal/<id>-<slug>.html"
```

Adjust `--window-size` so every frame fits.

## Lifecycle

1. A design ticket (`Design: …`) gets a proposal in `design/proposal/`, linked in its `designs`.
2. Once approved, the file moves to `design/final/<screen>.html` (re-rendered), the proposal path in
   the design ticket is replaced by the final one, the final path is added to the implementation
   ticket's `designs`, the proposal is deleted, and the design ticket moves to `done`.
