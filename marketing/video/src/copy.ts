export type Lang = "en" | "nl";

/**
 * Every word the film shows, in order. The same words are on the "Launch video" page of the Paper
 * design file, where Josh edits them; copy them back here after an edit. The app's own words (on the
 * watch and in the large graphics) come from the app's code, not from here.
 */
export const copy = {
  en: {
    name: "RainWatch",
    hook: "Caught in the rain again?",
    chore: "Fed up with getting your phone out to check?",
    answer: "RainWatch shows the next two hours of rain on your watch face.",
    radar: "The Dutch weather service's rain radar, for the square kilometre you're in.",
    line: "It draws the next two hours as one line.",
    height: "The higher the line, the harder it rains.",
    circle: "The same two hours, in a small circle.",
    minutes: "It counts the minutes until it rains, or until it stops.",
    decide: "Dry for ten more minutes. Long enough to get home?",
    shortened: "Sequence shortened",
    stack: "Also in the Smart Stack.",
    radarApp: "In the app, the Digital Crown moves the radar through time.",
    compareTitle: "On your watch face",
    rows: [
      { name: "RainWatch", note: "" },
      { name: "Buienradar", note: "A button that opens its app" },
      { name: "Buienalarm", note: "Nothing on the watch face" },
    ],
    sources: "Buienradar and Buienalarm as described by iCulture, December 2024.",
    unnamedTitle: "Two ways to check for rain",
    unnamed: [
      { name: "Your phone", note: "Unlock it, open an app, wait for the radar." },
      { name: "RainWatch", note: "Look at your wrist." },
    ],
    endFor: "for Apple Watch",
    endPromise: "Free, with no ads and no account.",
    credit: "Rain data from KNMI. Apple, the Apple logo, Apple Watch, Digital Crown and App Store are trademarks of Apple Inc., registered in the U.S. and other countries and regions.",
  },
  nl: {
    name: "BuienWatch",
    hook: "Weer natgeregend?",
    chore: "Elke keer je telefoon pakken om te kijken?",
    answer: "BuienWatch zet de komende twee uur regen op je wijzerplaat.",
    radar: "De regenradar van het KNMI, voor de vierkante kilometer waar je bent.",
    line: "Het tekent de komende twee uur als één lijn.",
    height: "Hoe hoger de lijn, hoe harder het regent.",
    circle: "Dezelfde twee uur, in een klein rondje.",
    minutes: "Het telt de minuten tot het gaat regenen, of tot het droog is.",
    decide: "Nog tien minuten droog. Kom je droog thuis?",
    shortened: "Beelden ingekort",
    stack: "Ook in de Slimme Stapel.",
    radarApp: "In de app draai je met de Digital Crown door de radar.",
    compareTitle: "Op je wijzerplaat",
    rows: [
      { name: "BuienWatch", note: "" },
      { name: "Buienradar", note: "Een knop die de app opent" },
      { name: "Buienalarm", note: "Niets op de wijzerplaat" },
    ],
    sources: "Buienradar en Buienalarm volgens iCulture, december 2024.",
    unnamedTitle: "Twee manieren om te kijken of het gaat regenen",
    unnamed: [
      { name: "Je telefoon", note: "Ontgrendelen, app openen, wachten op de radar." },
      { name: "BuienWatch", note: "Kijk op je pols." },
    ],
    endFor: "voor Apple Watch",
    endPromise: "Gratis, zonder reclame en zonder account.",
    credit: "Neerslaggegevens van het KNMI. Apple, het Apple-logo, Apple Watch, Digital Crown en App Store zijn handelsmerken van Apple Inc., gedeponeerd in de VS en andere landen en regio's.",
  },
} as const;
