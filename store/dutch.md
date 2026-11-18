<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. Made from the string catalogues; edit those, not this. -->

# The Dutch in BuienWatch, for Josh to read

Every word the app and the watch face show, English beside Dutch. To change one, edit `Sources/RainGraph/Localizable.xcstrings` (or `App/Shared/InfoPlist.xcstrings` for the last two). `%@` stands for a time or a phrase, `%lld` for a number. The store text is in `store/metadata/`, the screenshot headlines in `store/screenshots/make.py`.

Choices worth a look:
- Headlines put the time first: "Nog 40 min droog", "Nog 14 min regen", "Ruim een uur droog". English leads with "Dry" or "Rain".
- The circle reads "OVER 40 MIN" and "NOG 14 MIN", "OVER" a size smaller so its four letters clear the arc.
- "No PLACE" is "Geen PLEK": "PLAATS" is too wide for the circle.
- "Forecast Unavailable" is "Geen verwachting", and "No Recent Forecast" is "Verwachting te oud": the longer forms were cut short on the face.
- The first-launch and Location Expired sentences quote watchOS's own Dutch button, "Bij gebruik van app" (checked on the watchOS 27 simulator in Dutch), and Location Off spells out the way in the iPhone's Dutch Settings: Instellingen > Privacy en beveiliging > Locatievoorzieningen > BuienWatch > Bij gebruik van app.

| English | Dutch | Where |
|---|---|---|
| %@ from %@ | %1$@ vanaf %2$@ | Second line, rain that lasts as far as the forecast reaches: Drizzle from 01:20 |
| %@, hourly | %@, per uur | Face, second line with Apple's hourly data: Apple Weather, hourly |
| %@, made %@ | %1$@, van %2$@ | Face, second line with Apple's data once it is 20 minutes old: Weather, made 23:40 |
| %lld min ago | %lld min geleden | Radar, a frame in the past |
| About | Info | Button and page title: privacy policy and the data's terms |
| Change Place | Wijzig plaats | Button at the end of a picked place's forecast |
| Changed by %@ into rain or dry, in five-minute or hourly steps. | Door %@ omgezet in regen of droog, per vijf minuten of per uur. | About page, under Apple's Weather mark; %@ is the app's name |
| Choose a Place | Kies een plaats | Button |
| Continue | Ga door | First launch button |
| Couldn’t update | Bijwerken mislukt | Second line in the app after a refresh failed |
| DATA | DATA | Circle without a forecast, second line |
| Drizzle | Motregen | How hard, second line |
| Dry | Droog | The circle with no rain forecast, and the second line: Dry 00:25–01:20 |
| Dry for %@ | %@ droog | Headline, no rain as far as the forecast reaches: Dry for over an hour |
| Dry for %lld min | Nog %lld min droog | Headline, rain starts within the hour |
| Dry from %@ | Droog vanaf %@ | Second line, dry as far as the forecast reaches |
| Dry until %@ | Droog tot %@ | Headline, dry for an hour or more: Dry until 15:10 |
| FOR | NOG | Circle, above the number, raining now: rain FOR 14 MIN more |
| Forecast Unavailable | Geen verwachting | Problem title |
| Forecast made %@ | Verwachting van %@ | Second line once the forecast is 20 minutes old: when it was made |
| HR | UUR | Circle, under the number, hourly forecast: <1 HR |
| HRS | UUR | Circle, under the number: 1+ HRS |
| Heaviest around %@ | Het hardst rond %@ | Second line while it rains for an hour or more |
| Heavy | Zwaar | Scale line in the app's graph |
| Heavy rain | Zware regen | How hard, second line |
| Hourly forecast | Verwachting per uur | Second line, where Apple has only an hourly forecast |
| Hourly forecast made %@ | Verwachting per uur van %@ | Second line of an hourly forecast once it is 20 minutes old: when it was made |
| IN | OVER | Circle, above the number, dry now: rain IN 39 MIN |
| KNMI forecast made %@ | KNMI-verwachting %@ | Credit under the app's graph: whose forecast, and when it was made |
| Last forecast %@ | Laatste verwachting %@ | Under No Recent Forecast, and on the face |
| Legal | Juridisch | Apple Weather's legal link |
| Light | Licht | Scale line in the app's graph |
| Light rain | Lichte regen | How hard, second line |
| Location Not Found | Locatie niet gevonden | Problem title |
| Location Not Set | Locatie niet ingesteld | Problem title |
| Location Off | Locatie uit | Problem title |
| MIN | MIN | Circle, under the number |
| My Location | Mijn locatie | Title of the forecast for where the wearer is, beside the location arrow |
| No | Geen | Circle without a forecast, first line: No PLACE, No DATA |
| No Forecast Here | Hier geen verwachting | Problem title |
| No Recent Forecast | Verwachting te oud | Problem title, forecast over an hour old |
| No places found | Geen plaatsen gevonden | Place search with no results |
| Now | Nu | Start of the time axis, and the radar's present frame |
| On your iPhone, open Settings, then Privacy & Security > Location Services > %@ > While Using the App. | Open op je iPhone Instellingen, dan Privacy en beveiliging > Locatievoorzieningen > %@ > Bij gebruik van app. | Under Location Off: the way to turn location on, in iOS's own words. It is on the paired iPhone: the watch's row for a watch app is locked (checked on paired watchOS and iOS 27.2 simulators). %@ is the app's name |
| PLACE | PLEK | Circle without a place, second line |
| Pause | Pauzeer | Radar button, for VoiceOver |
| Permission Expired | Toestemming verlopen | Problem title: Allow Once has run out, so the system must ask again |
| Place | Plaats | Title of the place search |
| Play | Speel af | Radar button, for VoiceOver |
| Privacy Policy | Privacybeleid | Link on the About page |
| Radar | Radar | Button and page title |
| Radar Unavailable | Radar niet beschikbaar | Radar page when it can't load |
| Rain | Regen | How hard, second line: moderate rain |
| Rain data from KNMI under CC BY 4.0, changed by %@. | Regendata van het KNMI onder CC BY 4.0, bewerkt door %@. | About page, KNMI's licence; %@ is the app's name |
| Rain for %@ | %@ regen | Headline, rain as far as the forecast reaches: Rain for over an hour |
| Rain stops in %lld min | Nog %lld min regen | Headline, rain stops within the hour |
| Rain until %@ | Regen tot %@ | Headline, rain for an hour or more: Rain until 15:10 |
| Source: KNMI | Bron: KNMI | Credit under an old forecast, and on the radar |
| Tap for steps | Tik voor de stappen | Face, second line of Location off: a tap opens the steps to turn location on |
| Tap to allow location | Tik om locatie toe te staan | Face, second line of Permission expired |
| Tap to choose a place | Tik om een plaats te kiezen | Face, second line of a problem |
| Tap to set up | Tik om in te stellen | Face, second line before the first launch |
| Tap to try again | Tik om opnieuw te proberen | Face, second line of a problem |
| To keep your watch face up to date, choose Allow While Using App. | Kies ‘Bij gebruik van app’ om je wijzerplaat bij te houden. | Under Permission Expired, before the system's location question. The quoted words are watchOS's own button |
| To see the rain where you are, choose Allow While Using App. | Kies ‘Bij gebruik van app’ om de regen te zien waar je bent. | First launch, before the system's location question. The quoted words are watchOS's own button |
| Town or postcode | Plaats of postcode | Prompt in the place search field |
| Try Again | Probeer opnieuw | Button |
| Use My Location | Gebruik mijn locatie | Button in the place search |
| When the next rain starts or stops. | Wanneer de volgende bui begint of stopt. | The widget's description when adding it to a face |
| Zoom in | Zoom in | Radar button |
| Zoom out | Zoom uit | Radar button |
| in %lld min | over %lld min | Radar, a frame in the future |
| over %lld min | Ruim %lld min | How far a short forecast reaches, ending a headline: Dry for over 50 min. Dutch starts the headline with it. |
| over 2 hours | Ruim 2 uur | How far the forecast reaches, ending a headline: Dry for over 2 hours. Dutch starts the headline with it. |
| over an hour | Ruim een uur | How far the forecast reaches, ending a headline: Dry for over an hour. Dutch starts the headline with it. |
| RainWatch | BuienWatch | CFBundleDisplayName |
| RainWatch rounds your location to about 1 km to get the rain forecast. | BuienWatch rondt je locatie af op ongeveer 1 km om de regenverwachting op te halen. | NSLocationWhenInUseUsageDescription |
