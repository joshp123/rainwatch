<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request. -->

# Design

How Rain looks and why. Read it before changing any view. The rules come from Apple's design principles (Human Interface Guidelines, "Design principles", June 2026), Emil Kowalski's `apple-design` skill (Apple's WWDC design talks), Vercel's Web Interface Guidelines, rams.ai, Ibelick's `baseline-ui` and `improve-ui` and Jakub Krehel's `better-ui`, all from Josh's bookmarks, and from Josh's own corrections.

## Rules

1. **Look like Apple's own, beside Apple's own.** Josh sees Rain next to Apple's complications, so it matches them. The circle sits on `AccessoryWidgetBackground`, the grey disc Sunrise and World Clock use. Its words are the size of theirs, measured on his face (`renders/circular-on-real-face.png`): the number in white, the words around it in Buienradar blue, as World Clock colours "SF" orange. Complications use SF Compact Rounded; the app uses the system's text styles (`title3`, `body`, `footnote`), its margins (`scenePadding`), Swift Charts, toolbar buttons and `ContentUnavailableView`.
2. **One accent.** Buienradar blue (#5A9BD3) means rain and labels rain words. White is a value, grey is secondary. Red appears only for downpours on the radar.
3. **Never cover what matters.** On the radar the map round the yellow dot stays visible: the timeline is a slim strip over a dark fade, and the map centres the dot in the part the strip leaves free.
4. **Every element earns its place.** One label per fact: the radar names its moment once, relative to now ("in 25 min"), so it is never mistaken for the watch's clock. No decoration, no repeated words.
5. **Nothing touches, nothing shrinks.** Words never touch the line or the edge. Never box text shorter than its line height: watchOS then shrinks it, which made the circle look tiny.
6. **The line carries the meaning.** Height is how hard it rains, position is time. A layout that squeezes the line flat gives up words first (the rectangular slot drops its second line in short slots).
7. **Every state is designed.** Dry, drizzle, showers on and off, heavy, rain all window, stale, no location, offline and outside Buienradar's area each have a screen. `RainUITests` renders them all.
8. **Motion only where it explains.** The radar plays because the point is the time dimension; the crown pauses it and a tap or the play button resumes it.

## Check

Before showing any change: render every affected view (`swift run render-mockups`, `xcodebuild test` for the app), look at each at full size against these rules and against Josh's real face, then have a fresh agent critique the images with only Josh's words for context.
