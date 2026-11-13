<!-- Written by AI on 2026.11.13 by model claude opus 5.5. -->

# Rain on the watch: mock-ups

Buienradar's rain line for the next two hours, in every Apple Watch widget family, sized for Apple Watch Ultra 3.

- `renders/ultra-faces.png`: the widgets on Ultra faces, including Night Mode.
- `renders/families.png` and `renders/families-night-mode.png`: every family for five forecasts, one of them live Rotterdam data.

## Design

- The line is Buienradar's: its own graph height (`percentageValue` from `graphdata.buienradar.nl`), its own Light, Moderate and Heavy lines, its fill colour.
- Height is intensity. Time runs left to right, or clockwise round an arc, from now to two hours.
- Any rain sits visibly above dry, so drizzle never looks like nothing.
- Words state only the next change: "Rain in 25 min", "Dry in 30 min", "Dry", "Raining".
- Colour only repeats what height shows, so tinted faces and Night Mode lose nothing.

| Family | What it shows |
|---|---|
| Corner (Wayfinder, Waypoint) | The sparkline along the edge, the words inside it |
| Circular | The line bent round a gauge arc, the next change in the centre |
| Rectangular (Modular Ultra) and Smart Stack | Headline, the full line, Now and clock-hour labels |
| Inline | Block-glyph sparkline and the short words |

WidgetKit curves only text, SF Symbols and images in the corner. The proven corner draws the sparkline as block glyphs, as buienwatch does. The corner line variant cuts the real curve into image slices inside one `Text`; whether watchOS turns each slice to follow the edge needs a device test.

## Run

```sh
swift run render-mockups renders
xcodebuild -scheme RainComplication -destination 'generic/platform=watchOS' build
```

The renderer draws the shared SwiftUI views on the Mac. It draws curved text itself, because only the watch does that for real. `Sources/RainComplication` is the WidgetKit code with `#Preview`s for every family; it needs the watchOS simulator runtime to preview in Xcode.
