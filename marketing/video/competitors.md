<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. -->

# What Buienradar and Buienalarm put on the watch face

Checked on 18 November 2026, for the comparison shot in the launch video. Josh decides whether a cut that names them goes out; the `-unnamed` cuts name no one.

## What is true

- **Buienalarm has a watch app and no complication.** iCulture's guide to watch weather apps, updated December 2024: "Complicaties: Nee ... Buiengrafieken in een complicatie hadden de app een stuk beter gemaakt, maar die ontbreken helaas." Its App Store page names one widget, for the iPhone's home screen. None of its 25 release notes from 10 June 2025 to 16 November 2026 (version 4.34.0) mentions the watch, a complication or a widget.
- **Buienradar has a watch app and a complication, and the complication only opens the app.** iCulture, 12 July 2022: the app "biedt ook een complicatie om snel te openen", in an extra-wide size and a small round one; "Na het aantikken van de complicatie krijg je het laatst geopende scherm te zien". Its screenshot shows the complication as "--". The December 2024 guide says the same. None of its 25 release notes from 8 December 2025 to 13 November 2026 (version 4.10.2) mentions the watch or a complication. Its App Store page says "Via onze handige widgets en watch app kan je snel zien of het binnenkort gaat regenen zonder de app te openen": the widgets are the iPhone's.
- Both watch apps are on Josh's watch today: Buienradar 4.10.2 (`nl.rtl.buienradar.watchkitapp`) and Buienalarm 4.33.0 (`org.yoki.ios.Buienalarm.BuienalarmWatchKitApp`), listed by `devicectl device info apps`.

So "Buienradar and Buienalarm have no watch widgets" is half right. The video says "Buienalarm: no complication" and "Buienradar: complication only opens the app".

## Not checked

What the two apps offer in the watch's own complication list today. The sources above are from 2022 and 2024, and release notes that say nothing do not prove nothing changed. `devicectl` cannot open the face editor, and the watch was asleep and out of reach during this work. The check takes a minute on the watch: hold the face, Edit, swipe to Complications, tap a slot and look for Buienradar and Buienalarm in the list.

## Sources

- Buienradar, App Store (Netherlands): https://apps.apple.com/nl/app/buienradar-weer/id621542526?platform=watch
- Buienalarm, App Store (Netherlands): https://apps.apple.com/nl/app/buienalarm-weer-regenradar/id598509141?platform=watch
- iCulture, "Buienradar is terug op de Apple Watch", 12 July 2022: https://www.iculture.nl/nieuws/buienradar-terug-apple-watch (screenshot: https://www.iculture.nl/wp-content/uploads/mediacloud/2022/07/buienradar-apple-watch-2.png)
- iCulture, "De beste weer-apps voor je Apple Watch, mét handige complicaties", updated December 2024: https://www.iculture.nl/gids/apple-watch-weerapps-complicaties
