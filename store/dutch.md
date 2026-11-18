<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. Made from the string catalogues; edit those, not this. -->

# The Dutch in BuienWatch, for Josh to read

Every word the app and the watch face show, English beside Dutch. To change one, edit `Sources/RainGraph/Localizable.xcstrings` (or `App/Shared/InfoPlist.xcstrings` for the last two). `%@` stands for a time or a phrase, `%lld` for a number. The store text is in `store/metadata/`, the screenshot headlines in `store/screenshots/make.py`.

Choices worth a look:
- Headlines put the time first: "Nog 40 min droog", "Nog 14 min regen", "Nog 1+ uur droog". English leads with "Dry" or "Rain".
- The circle reads "IN 40 MIN" and "NOG 14 MIN". "OVER" was the better word for "in", but four letters touched the arc.
- "No PLACE" is "Geen PLEK": "PLAATS" is too wide for the circle.
- "Forecast Unavailable" is "Geen verwachting", and "No Recent Forecast" is "Verwachting te oud": the longer forms were cut short on the face.
- The first-launch sentence quotes watchOS's own Dutch button, "Sta toe bij gebruik van app". Check it against your watch in Dutch.

| English | Dutch | Where |
|---|---|---|
| Legal | Juridisch | Apple Weather's legal link, which opens the About page |
| Choose a Place | Kies een plaats | Button |
| Try Again | Probeer opnieuw | Button |
| Radar | Radar | Button and page title |
| Change Place | Wijzig plaats | Button at the end of a picked place's forecast |
| Use My Location | Gebruik mijn locatie | Button in the place search |
| No | Geen | Circle without a forecast, first line: No PLACE, No DATA |
| DATA | DATA | Circle without a forecast, second line |
| PLACE | PLEK | Circle without a place, second line |
| IN | IN | Circle, above the number, dry now: rain IN 39 MIN |
| FOR | NOG | Circle, above the number, raining now: rain FOR 14 MIN more |
| MIN | MIN | Circle, under the number |
| HR | UUR | Circle, under the number, hourly forecast: <1 HR |
| HRS | UUR | Circle, under the number: 1+ HRS |
| Source: KNMI | Bron: KNMI | Credit under an old forecast, and on the radar |
| KNMI forecast from %@ | KNMI-data van %@ | Credit under the app's graph |
| Tap to set up | Tik om in te stellen | Face, second line before the first launch |
| Tap to choose a place | Tik om een plaats te kiezen | Face, second line of a problem |
| Tap to try again | Tik om opnieuw te proberen | Face, second line of a problem |
| %@, hourly | %@, per uur | Face, second line with Apple's hourly data: Apple Weather, hourly |
| Continue | Ga door | First launch button |
| To see live rain data where you are, choose Allow While Using App. | Kies ‘Sta toe bij gebruik van app’ voor live regendata waar je bent. | First launch. The quoted words are watchOS's own Dutch button |
| Dry until %@ | Droog tot %@ | Headline, dry for an hour or more: Dry until 15:10 |
| Dry for %@ | Nog %@ droog | Headline, no rain as far as the forecast reaches: Dry for 1+ hours |
| Rain for %@ | Nog %@ regen | Headline, rain as far as the forecast reaches: Rain for 1+ hours |
| Rain until %@ | Regen tot %@ | Headline, rain for an hour or more: Rain until 15:10 |
| Dry for %lld min | Nog %lld min droog | Headline, rain starts within the hour |
| Rain stops in %lld min | Nog %lld min regen | Headline, rain stops within the hour |
| %lld+ min | %lld+ min | How far a short forecast reaches, in a headline |
| 1+ hours | 1+ uur | How far the forecast reaches, in a headline |
| 2+ hours | 2+ uur | How far the forecast reaches, in a headline |
| Drizzle | Motregen | How hard, second line |
| Heavy rain | Zware regen | How hard, second line |
| Light rain | Lichte regen | How hard, second line |
| Rain | Regen | How hard, second line: moderate rain |
| No places found | Geen plaatsen gevonden | Place search with no results |
| Forecast Unavailable | Geen verwachting | Problem title |
| Location Not Found | Locatie niet gevonden | Problem title |
| Location Not Set | Locatie niet ingesteld | Problem title |
| Location Off | Locatie uit | Problem title |
| No Forecast Here | Hier geen verwachting | Problem title |
| No Recent Forecast | Verwachting te oud | Problem title, forecast over an hour old |
| Town or postcode | Plaats of postcode | Prompt in the place search field |
| Zoom in | Zoom in | Radar button |
| Zoom out | Zoom uit | Radar button |
| Pause | Pauzeer | Radar button, for VoiceOver |
| Play | Speel af | Radar button, for VoiceOver |
| Radar Unavailable | Radar niet beschikbaar | Radar page when it can't load |
| in %lld min | over %lld min | Radar, a frame in the future |
| %lld min ago | %lld min geleden | Radar, a frame in the past |
| Heavy | Zwaar | Scale line in the app's graph |
| Light | Licht | Scale line in the app's graph |
| Couldn’t update | Bijwerken mislukt | Second line in the app after a refresh failed |
| Forecast from %@ | Verwachting van %@ | Second line once the forecast is 20 minutes old |
| Heaviest around %@ | Hardst rond %@ | Second line while it rains for an hour or more |
| Dry from %@ | Droog vanaf %@ | Second line, dry as far as the forecast reaches |
| %@ from %@ | %1$@ vanaf %2$@ | Second line, rain that lasts as far as the forecast reaches: Drizzle from 01:20 |
| Hourly forecast | Verwachting per uur | Second line, where Apple has only an hourly forecast |
| Hourly forecast from %@ | Verwachting per uur van %@ | Second line of an hourly forecast once it is 20 minutes old |
| %@, from %@ | %1$@, van %2$@ | Face, second line with Apple's data once it is 20 minutes old:  Weather, from 23:40 |
| My Location | Mijn locatie | Title of the forecast for where the wearer is, beside the location arrow |
| About | Info | Button and page title: privacy policy and the data's terms |
| Privacy Policy | Privacybeleid | Link on the About page |
| Rain data from KNMI under CC BY 4.0, changed by %@. | Regendata van het KNMI onder CC BY 4.0, bewerkt door %@. | About page, KNMI's licence; %@ is the app's name |
| Changed by %@ into rain or dry, in five-minute or hourly steps. | Door %@ omgezet in regen of droog, per vijf minuten of per uur. | About page, under Apple's Weather mark; %@ is the app's name |
| Now | Nu | Start of the time axis, and the radar's present frame |
| Dry | Droog | The circle with no rain forecast, and the second line: Dry 00:25–01:20 |
| Rain for the next two hours. | Regen in de komende twee uur. | The widget's description when adding it to a face |
| Place | Plaats | Title of the place search |
| Allow it in Settings. | Sta dit toe in Instellingen. | Under Location Off |
| Last forecast %@ | Laatste verwachting %@ | Under No Recent Forecast, and on the face |
| RainWatch | BuienWatch | The app's name under its icon |
| RainWatch rounds your location to about 1 km to get the rain forecast. | BuienWatch rondt je locatie af op ongeveer 1 km om de regenverwachting op te halen. | Under Apple's location question |
