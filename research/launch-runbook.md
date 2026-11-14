Written by AI on 2026.11.14 by model claude sonnet 5.5.

# Rain: launch runbook, from today's repo to "Ready for Sale"

This is the step-by-step version of `LAUNCH.md`. It covers what a team like kr0der's and Paul Solt's would do in November 2026, adjusted for a watch-only app, and it separates **Practice** (what they do, with links) from **Recommendation** (my view for Rain).

## 1. Read this first

**Realistic calendar: four to six weeks from Josh's go-ahead, almost all of it waiting.** The waits are Buienradar's answer, App Store Connect API access approval, the EU trader check, two weeks of wearing the TestFlight build, and App Review. Agent work is about three to five working days (my estimate).

Five findings change `LAUNCH.md`. I tested the first two on this Mac (Xcode 27.2, watchOS 27.2 SDK) in a throwaway copy under `/tmp`; the rest come from Apple's pages and the sources linked below.

1. **Rain cannot be uploaded as it is built today.** A bare watchOS app target has no "App Store Connect" export method. Xcode offers only `release-testing`, `enterprise` and `debugging` for it. Adding an iOS "container" target that wraps the watch app fixes it: the same archive then offers `app-store-connect`. This changes the bundle IDs (section 4, step B1). Apple's own doc says the root target of a watch-only project is "a stub that acts as an iOS wrapper", used to "package your app for distribution to the App Store".
2. **There is no `requestReview` on watchOS.** `SKStoreReviewController` is marked `API_UNAVAILABLE(watchos)` in the watchOS 27.2 SDK, and `RequestReviewAction` does not exist in the watchOS StoreKit interface. `LAUNCH.md` section 5 ("Ask for ratings only with Apple's own prompt") cannot be built. Ratings must come from the product page, a link on the web, and the launch post.
3. **Phased release is not available for version 1.0.** Apple's page covers "a version update", and its platform list is iOS, macOS and tvOS (no watchOS). Use manual release instead (section 4, step E3).
4. **The review queue is slow right now.** In October and November 2026, Paul Solt waited 14 days in total for a new app (including one rejection and 8 extra days from one button press). kr0der writes that a first review "can take weeks". Apple's stated target is 50% within 24 hours and 90% within 48 hours. Plan for two weeks and submit once.
5. **`asc` cannot do everything, and it has a known gap for watch apps.** It cannot create the app record or answer App Privacy with an API key (both need an Apple web session with two-factor sign-in), and EU trader status is website-only. Its watch-only upload failed for one user in February 2026. Use `xcodebuild` for the upload and `asc` for everything after it.

Three smaller facts worth knowing:

- **Apple Watch has no app preview video.** Apple's preview specification covers iOS, macOS, tvOS and visionOS only. The store page for Rain is screenshots only (1 to 10 at 422 × 514).
- **The Netherlands storefront indexes Dutch and English (U.K.).** Make English (U.K.) the primary language, not English (U.S.), so both listings count for Dutch search.
- **Reviewers are probably not in the Netherlands.** Today Rain shows "No Forecast Here" outside coverage. That is a likely rejection under 2.1 and 5.1.1(iv) ("if a user declines to share Location, offer the ability to manually enter an address"). The place picker in `LAUNCH.md` decision 6 is a submission blocker, not a nice-to-have.

### What only Josh can do

- Confirm the open decisions in `LAUNCH.md` section 1 (data source, price, trader status, name, market).
- Sign in to App Store Connect and give two-factor codes (Apple sends them to his devices or phone).
- As Account Holder: request App Store Connect API access, generate the key, complete EU trader status, and (if paid) sign the Paid Apps Agreement, tax forms and bank details.
- Approve every action that writes to his Apple account, and press **Submit for Review** and **Release**.
- Wear the TestFlight build and take two or three calls with Dutch cyclists.

## 2. What these practitioners actually do

None of them has shipped a watch-only app. Their evidence is about the App Store Connect workflow, screenshots, review and featuring in general. Watch-specific facts below come from Apple, Apple's forums, two blog posts by other developers and my own test.

**kr0der (Anthony Kroeger)**
- Runs App Store Connect with `asc`, "you won't need to open app store connect anymore" ([post](https://x.com/kr0der/status/2078856890575204704)). He still does "the privacy section myself but ask AI what to select" ([post](https://x.com/kr0der/status/2102341133078819325)).
- Submits every app and update with `asc`, and says they are approved in under 12 hours ([post](https://x.com/kr0der/status/2116376112901288311)). Another developer says Apple auto-rejects CLI submissions ([quoted in this reply](https://x.com/kr0der/status/2091817641732415596)). Both are single-person anecdotes.
- Review video: "record a demo going through the app to make it easy for apple reviewers to review the app and then upload it via asc CLI" ([post](https://x.com/kr0der/status/2117664246796538065)). A small new app was approved in 5 days with one ([post](https://x.com/kr0der/status/2117617297376633181)). No proof the video caused the speed.
- Review times: "initial app review can take weeks" ([post](https://x.com/kr0der/status/2091701308629901553)), "sometimes it can take 3 weeks" ([post](https://x.com/kr0der/status/2111362867152986487)). Expedited review started a stuck update "in 5 mins" after 5 days; he says wait 24 hours and keep it for urgent updates ([post](https://x.com/kr0der/status/2082594530021519698)). Four similar apps submitted together were batch-rejected as spam ([post](https://x.com/kr0der/status/2094037170302697726)).
- A rating prompt in onboarding got an app rejected ([post](https://x.com/kr0der/status/2074374557004423411)).
- Screenshots: sells a generator, Screenies, so treat his advice as interested ([launch](https://x.com/kr0der/status/2087378582930882733)). He localised a screenshot set and submitted it "in under 5 minutes" with `asc` and Claude ([post](https://x.com/kr0der/status/2090862253163831644)).

**Paul Solt**
- Builds and TestFlight uploads through Xcode Cloud: agents push a branch named `testflight/<name>` and a workflow archives and uploads ([post](https://x.com/PaulSolt/status/2084673707809591373), [his AGENTS.md rules](https://x.com/PaulSolt/status/2085414811442069940)). He also uses `asc` ([post](https://x.com/PaulSolt/status/2108945631532503331)) and says it "saved me so much time vs. fighting with the sluggishness of App Store Connect" ([post](https://x.com/PaulSolt/status/2117055978441236768)).
- Screenshots: follows designer Theodora's (@designerants) framework, points an LLM at her 100 practices, then builds them in Pixelmator Pro ([post](https://x.com/PaulSolt/status/2101367081606303862), [tools](https://x.com/PaulSolt/status/2083225981989331121)). Device frames in screenshots are fine; in the preview video they are not ([post](https://x.com/PaulSolt/status/2115458378965155924)).
- Rejection: Guideline 2.3.4, device frames in the app preview. I read this in his video frames: Apple's message says the preview "includes device images and/or device frames". Timeline: submitted 22 October, rejected 27 October, resubmitted, still waiting on 3 November, in review again 4 November, approved about 5 November ([timeline](https://x.com/PaulSolt/status/2116872842109186516), [14 days](https://x.com/PaulSolt/status/2118004880338264452), [video](https://x.com/PaulSolt/status/2120976166303547795)).
- His 8-day mistake: App Store Connect offered "submit with latest build" and he accepted, which "sent me all the way back to the beginning of the line" ([post](https://x.com/PaulSolt/status/2120981328191787372)). Apple's help says that after a metadata rejection "you can resubmit the same build after resolving the issue" ([Apple](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages/)). He also filed an expedite request ([link he used](https://developer.apple.com/contact/app-store/?topic=expedite)).
- Name and encryption: "when you start on a single platform (macOS), other developers can reserve your name on iOS (I filed an App Name Dispute)"; apps "need to state encryption compliance" ([post](https://x.com/PaulSolt/status/2083176853653574063)).
- Featuring: his Mac app was featured a week or two after a 2.0 with new screenshots, copy, preview, icon and design ([post](https://x.com/PaulSolt/status/2101004763496141084)). He says 757,612 impressions in one day ([post](https://x.com/PaulSolt/status/2073055955072254104)) and 3,158 downloads, $0 revenue, as the free app ([article](https://super-easy-apps.kit.com/posts/apple-featured-my-app-i-made-0)). He does not say he nominated it.

**Rudrank (author of `asc`) and the people who use it**
- `asc` covers nearly everything in this runbook. It has `nominations` commands; Rudrank has sent featuring nominations with it ([his post, quoted on 24 October](https://x.com/rudrank/status/2114067062628712890)). Dimillian: with `asc` an agent went from nothing configured to an app in TestFlight public beta review "in UNDER 2 minutes" ([post](https://x.com/Dimillian/status/2020871210515501116)).
- Watch gap: on 28 February 2026 a developer with a standalone watch app reported Apple rejecting an `asc` upload (errors 90100, 90508, 90092); Rudrank answered "OpenAPI spec does not support watchOS upload" ([report](https://x.com/pejmanjohn/status/2027565821552447918), [reply](https://x.com/rudrank/status/2027574347230286262)). I could not find a later fix. His October release note says "iOS, tvOS and visionOS IPA publishing still works" ([post](https://x.com/rudrank/status/2115971877097398281)).

**Others**
- Paul Hudson (@twostraws) sells Kickstart, a paid Mac app for keyword research and rank tracking ([post](https://x.com/twostraws/status/2099601559952789504)). I have not evaluated it and do not recommend a paid tool for one app.
- I searched for @steipete, @thekitze and @Dimillian on App Store launch practice and found nothing beyond the Dimillian post above.

## 3. The tools, in one place

- **`asc`** (github.com/rorkai/App-Store-Connect-CLI, MIT, version 6.x). Install with `brew install asc`. I read the repo, its docs and its source, not a running copy. Auth uses an App Store Connect API key (`asc auth login --key-id ... --issuer-id ... --private-key AuthKey.p8`). Output is JSON when piped. It has `--dry-run` and `--confirm` on most writes. Its agent guide says to run `--help` before every command and to prove the final state by reading it back ([guide](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/website/src/content/docs/guides/agent-ios-release.mdx)). It sends anonymous telemetry unless `ASC_TELEMETRY_DISABLED=1`.
- **`asc web ...`** commands use an Apple web session (`asc web auth login --apple-id ...`, password and two-factor code). They create apps, publish App Privacy and read regulatory declarations. The session is cached in `~/.asc/web`.
- **`xcodebuild`** archives and uploads. Flags are in `xcodebuild -help`: `-allowProvisioningUpdates`, `-authenticationKeyPath/ID/IssuerID`, and the export option `destination = upload`.
- **App Store Connect website** for what is website-only: EU trader status, agreements, tax and bank forms, and (in practice) the first press of Submit.
- **Screenshot tools others use:** Pixelmator Pro (Paul), Picasso Screenshots Studio (designerants), Screenies (kr0der), FrameBuddy 2.0 CLI (free, Mac App Store), `asc screenshots frame`. See step C6 for why I would build ours.

## 4. The runbook

Conventions: **Who** is who acts. **Josh** means Josh provides or approves something. Time is calendar time unless I say "work". "Goes wrong" lists failures seen in the sources or likely from them.

### Phase A: start the slow things (day 0)

These run in parallel and gate the later phases. Do them first.

**A1. Buienradar permission or a KNMI prototype** (`LAUNCH.md` decision 1).
- Who: Josh sends the email; the agent builds the KNMI prototype.
- Time: unknown for Buienradar. This blocks content rights and the review notes (Guideline 5.2.2: "Authorization must be provided upon request").
- Goes wrong: no reply, free-only terms, or a refusal. Do not submit a build that fetches Buienradar's data without permission.

**A2. Confirm account state in App Store Connect** (Josh, 15 minutes).
- Check the Apple Developer membership is active and the Free Apps agreement is signed (Business, Agreements). Nothing else can be created until the Account Holder signs the latest agreement.
- Request API access: Users and Access, Integrations, App Store Connect API, Request Access (Account Holder only). Apple reviews requests "on a case-by-case basis", so start now. Time: unknown.
- Then generate a key. Either a team key (the Account Holder or an Admin creates it; give it the App Manager role) or an individual key (profile page, "Individual API Key"; it cannot use provisioning endpoints, which the metadata and review commands should not need, my reading). The `.p8` downloads once. Store it in Josh's keyring and give the agent only the key ID, issuer ID and a path. Never paste it into chat or a repo.
- Goes wrong: access request pending for days; lost `.p8` (revoke and re-make).

**A3. EU Digital Services Act trader status** (Josh, 30 minutes plus verification wait).
- Business, Agreements, Compliance, Digital Services Act. Apple's page: you must declare a status "even if you don't distribute apps in the EU".
- If trader: Apple displays address, phone and email on the EU product page, verifies email and phone by two-factor code, and asks for a document that verifies the name and address. An individual may give a P.O. box with proof of association. If not a trader: EU buyers are told consumer rights do not apply to contracts with you.
- Apple lists these trader factors: revenue from the app (a paid app, in-app purchases or ads), commercial practices towards consumers, VAT registration, and developing the app in a professional or business capacity. Apple says a hobbyist with no intention to commercialise "may not be considered a trader". Whether Josh is one is his call and a legal question ([Apple](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)).
- Tooling: website only. `asc web apps declarations list` shows app-level declarations but "EU DSA trader status is account-level and is not included".
- Goes wrong: document rejected; Apple states no review time, so allow several days. If the account has no status when the first new app is submitted, App Store Connect asks then.

**A4. If paid: Paid Apps Agreement, tax and bank** (Josh, Account Holder only, about an hour plus verification).
- Order: sign the agreement, submit tax forms (a US form is mandatory for everyone; outside the US that is usually a W-8BEN), then add the bank account ([Apple](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information)). Tax submissions usually cannot be edited afterwards.
- Enrol in the Small Business Program (15% commission) after accepting the agreement; the rate starts 15 days after the end of the fiscal month in which Apple approves it ([Apple](https://developer.apple.com/app-store/small-business-program)).
- Free app: skip this step.
- Goes wrong: Dutch VAT and "is this a business" questions. Get an accountant's view before the first sale. I have not verified Dutch rules.

**A5. Name check** (agent, half a day).
- Search EUIPO TMview and BOIP for "Rain" in software and weather classes. I searched Apple's public iTunes Search API for the Netherlands, US and UK storefronts: no app is called exactly "Rain" in the 53 to 57 results each returned, but many start with it (for example "Rain Alarm - Neerslagradar", "Rain Radar Pro", "Rain: Buy & Sell Bitcoin"). Name availability is only proven when App Store Connect accepts it.
- Practice: Paul filed an App Name Dispute because another developer could take his name on iOS ([post](https://x.com/PaulSolt/status/2083176853653574063)). Apple's route if someone holds a name you have rights to is a [name claim](https://www.apple.com/legal/internet-services/itunes/appnamenotices/).
- Recommendation: create the app record early (step C1) to hold the name. Have fallbacks ready (for example "Rain Ahead").

### Phase B: make the build uploadable (agent, 3 to 5 working days)

**B1. Add the iOS container and rename the bundle IDs.**
- Tested here: the current project (`App/project.yml`) archives only if `SKIP_INSTALL` is turned off (xcodegen sets it to YES, so the archive is empty), and even then offers only `release-testing`, `enterprise`, `debugging`. With a container target the archive offers `app-store-connect`, `release-testing`, `enterprise`, `debugging` and `validation`.
- Change in `project.yml` (this is the shape I tested; Xcode's own watch-only template does the same):
  - New target `RainContainer`: type `application.watchapp2-container`, platform iOS, bundle ID `nl.jjp.rain` (this ID becomes the App Store record), depends on `Rain`, with Info.plist keys `ITSWatchOnlyContainer = true` and `LSApplicationLaunchProhibited = true`. No source files, no icons.
  - Watch app `Rain`: bundle ID `nl.jjp.rain.watchkitapp`, `SKIP_INSTALL = YES`, keep `WKWatchOnly = true`, no `WKCompanionAppBundleIdentifier`.
  - Widget: bundle ID `nl.jjp.rain.watchkitapp.widget`.
  - Archive the `RainContainer` scheme with `-destination 'generic/platform=iOS'`. Do not list the watch targets as scheme build targets: one developer found that sends the archive back to watchOS ([source](https://note.com/herodini777/n/nd9c38757f32a?hl=en)).
- Why the ID prefix matters: Apple requires the container's bundle ID to be the prefix of the watch app's.
- Side effects: `AGENTS.md` and `README.md` use `nl.jjp.rain` for `devicectl` on the watch; update them to `nl.jjp.rain.watchkitapp`. Delete the old dev install from the watch. The app group `group.nl.jjp.rain` is unchanged. `nl.jjp.rain` already exists as a registered ID from dev builds (my inference), so only the two new IDs need creating.
- Check: the archive's `Products/Applications/RainContainer.app/Watch/Rain.app` exists, and `xcodebuild -exportArchive` accepts `method = app-store-connect` (it errors on the method name before it needs any certificate, so this check costs nothing).
- Goes wrong: another Xcode update may change this again; re-test after each Xcode release. In an Apple forum thread an Apple engineer called the missing option "likely a bug" in March 2026, and developers still reported it in July ([thread](https://developer.apple.com/forums/thread/817223)). My test shows the bare archive still lacks it on Xcode 27.2.
- Not tested: the actual upload and processing (it needs Josh's account). The App Store icon source for a watch-only app is the open question for the first upload.

**B2. Slice and OS support.**
- The archive I built contains `arm64` and `arm64_32`. A developer who tested App Store validation reports `arm64` is always required and `arm64_32` is additionally required while the minimum OS is below watchOS 27 ([source](https://docs.perryts.com/platforms/watchos-app-store.html), one source, not Apple). Rain targets watchOS 26.0, so keep both slices, or raise the minimum to 27.0 and drop older watches. Ultra 3 runs either.
- Apple's April 2027 rule (watchOS apps built with the watchOS 27 SDK) is already met by Xcode 27.2 ([Apple](https://developer.apple.com/watchos/submit/)).

**B3. Release hygiene from `LAUNCH.md` section 2** (all agent work):
- `PrivacyInfo.xcprivacy` (app group `UserDefaults` is a required-reason API).
- `ITSAppUsesNonExemptEncryption = NO` in the container, watch app and widget `Info.plist` (HTTPS only). Apple's export-compliance page leaves the legal judgement to the developer. Setting the key stops the per-build encryption question; without it each build waits at "Missing Compliance". Which `Info.plist` App Store Connect reads for a container is unverified, so set all three.
- Purpose string that says what happens to the location (wording in `research/app-review-readiness.md`).
- Version `1.0.0`, build number, icon, Dutch strings, privacy policy link inside the app (Guideline 5.1.1(i) requires "within the app in an easily accessible manner").
- Accessibility: Apple now shows an "Accessibility Nutrition Label" per platform on the product page. Declare only what was tested (VoiceOver, Larger Text) on the real watch.

**B4. Signing.**
- First export needs an Apple Distribution certificate and App Store profiles for the three bundle IDs. Xcode makes them with `-allowProvisioningUpdates`, which writes to Josh's developer account. Ask Josh before the first run.
- Josh provides: Xcode already signed in on the build machine, or the API key from A2 (`-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`).
- Goes wrong: "No profiles for ..." errors (I hit exactly this when I renamed IDs in my copy without the flag).

**B5. Archive, export and upload from the command line.** Three routes, in my order of preference:

1. **`xcodebuild` straight to App Store Connect (Practice: Apple's route; kr0der and Paul use Xcode or Xcode Cloud for the upload).**
   ```sh
   xcodebuild -project App/Rain.xcodeproj -scheme RainContainer -configuration Release \
     -destination 'generic/platform=iOS' -archivePath build/Rain.xcarchive archive \
     -allowProvisioningUpdates
   xcodebuild -exportArchive -archivePath build/Rain.xcarchive \
     -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
   ```
   `ExportOptions.plist`: `method = app-store-connect`, `destination = upload`, `teamID = 7M8BR7R488`, `signingStyle = automatic`. Note `manageAppVersionAndBuildNumber` defaults to YES: Xcode may change the build number on upload. Set it to NO if the build number is yours. `testFlightInternalTestingOnly = true` marks a build that can never go to external testers or the store; leave it off for release candidates.
2. **Export a local IPA, then `asc builds upload --app APP_ID --ipa build/Rain.ipa --dry-run`, then `asc publish testflight --app APP_ID --ipa ... --group "Internal" --wait`.** The container IPA reads as an iOS package, and `asc`'s source maps platform `watchos` to `IOS`, so it should work. It is unproven for watch-only apps, and the February 2026 failure above is the warning. Run `--dry-run` first.
3. **`iTMSTransporter -m upload -assetFile Rain.ipa -apiKey ... -apiIssuer ...`.** A developer reports this worked for a container with `ITSWatchOnlyContainer` ([source](https://www.perryts.com/en/blog/shipping-a-watch-only-app-to-the-app-store)); `altool` could not read the platform.
4. Paul's Xcode Cloud route (`testflight/*` branch trigger, 25 free compute hours a month included with membership, [Apple](https://developer.apple.com/xcode-cloud/get-started)) is an option, but for one app on a Mac that is always on I would not add it for 1.0.

Time: archive about 2 to 4 minutes; upload and processing about 10 to 60 minutes. App Store Connect emails when processing ends. Goes wrong: processing errors arrive by email, not at upload (for example an icon, architecture or plist error).

### Phase C: the app record and the store page

**C1. Create the app record** (website click, or `asc web apps create`).
- Apple's dialog: Platforms "iOS" (Apple: "Watch-only apps are considered part of the iOS platform"), name, primary language **English (U.K.)**, bundle ID `nl.jjp.rain` from the dropdown, SKU (any unique string, for example `rain-watch-1`), User Access.
- Recommendation: Josh creates it in the browser (about two minutes) because `asc web apps create` needs his password and two-factor code in the agent's session. Everything after this the agent can do with the API key.
- Goes wrong: the name is rejected as taken (use the fallback); the bundle ID is missing from the dropdown (register it, or run B4 first).
- Verify: `asc apps list --bundle-id nl.jjp.rain` returns the app ID. Export `ASC_APP_ID`.

**C2. App information.**
- Commands (all `asc`, all reversible until submission):
  - `asc categories set --app $ASC_APP_ID --primary WEATHER` (a secondary such as `UTILITIES` is optional; category words are indexed, so do not repeat them in keywords).
  - `asc app-setup info set --app $ASC_APP_ID --primary-locale en-GB --privacy-policy-url https://...` and `--content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT` or the opposite, depending on A1. Be accurate: this answer is a legal statement.
  - Support URL and marketing URL per locale: `asc localizations update --version ID --locale en-GB --support-url ... --marketing-url ...`.
  - Copyright line.
- Josh provides: the URLs (his site hosts the privacy policy and a support page) and the copyright holder name.

**C3. Age rating.**
- `asc age-rating edit --app $ASC_APP_ID --all-none` then `asc age-rating view --app $ASC_APP_ID`. Expected result is the lowest rating, but the questionnaire decides. Do not choose "Made for Kids" (it locks the app into the Kids rules). Apple's questionnaire now includes controls and capabilities questions; answer them in the website if a flag is missing from `asc`.
- Time: 5 minutes.

**C4. App Privacy.**
- Apple's definition ([App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)): data is "collected" only if it is transmitted off the device "in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time". Data processed only on the device is not collected. If you do collect precise location but coarsen it before storing, you declare Coarse Location.
- What this means for Rain depends on the data source (A1). If Rain sends coordinates to a provider that may log them, the safe answer is Location (Coarse if you round to under three decimal places before sending), purpose "App Functionality", not linked to identity, not used for tracking. If Rain's own server proxies the request and keeps nothing, Apple's guidance allows "Data Not Collected". I would round coordinates to two decimals before any request, which also fits a privacy policy line. This is my judgement, not Apple's ruling; confirm what the provider logs.
- Tooling: the website (App Privacy, Get Started, Publish) or `asc web privacy plan/apply/publish` with a web session. Practice: kr0der does this part himself with AI advice. He also reports submitting four times in a row because review kept asking him to "remove tracking" in App Privacy even though it "literally wouldn't let me" ([post](https://x.com/kr0der/status/2107989792856346820)).
- Josh approves the answers. Nothing here is shown until you press **Publish**.

**C5. Metadata in English and Dutch.**
- Limits (Apple): name 30, subtitle 30, keywords 100, promotional text 170, description 4,000, What's New 4,000. The name, subtitle and keywords are ranked; the description and promotional text are not (promotional text can change without a new version). Do not repeat words across name, subtitle, category and keywords; use commas without spaces; singular and plural count as duplicates ([Apple](https://developer.apple.com/app-store/search)).
- Locales: `en-GB` (primary) and `nl-NL`. Per the cross-localisation tables from ASO vendors (not Apple), the Netherlands storefront indexes Dutch and English (U.K.). An ASO vendor quotes Apple as saying a language's keywords work "in all countries or regions where the App Store supports" it, which would make the Dutch set count in Belgium too (I did not read Apple's page for this).
- Guideline limits that bite here (2.3.7, 2.3.8): no prices, no other apps' names, no unverifiable claims in the subtitle, no trademarked terms. That excludes "Buienradar", "real-time", "accurate" and "best" in every field and every screenshot headline.
- My drafts (for Josh to edit; a Dutch speaker should read the Dutch before submission). Counts are characters:
  - en-GB subtitle: `Rain in the next 2 hours` (24).
  - en-GB keywords: `shower,radar,forecast,drizzle,precipitation,nowcast,umbrella,complication,smart stack,cycling` (93).
  - en-GB promotional text: "Will you get wet? The rain forecast for the next 2 hours, on your watch face, in the Smart Stack and as a radar." (112).
  - nl-NL subtitle: `Regen de komende 2 uur` (22).
  - nl-NL keywords: `buien,regenradar,neerslag,voorspelling,radar,wijzerplaat,fietsen,paraplu,nowcast,complicatie,droog` (98).
  - nl-NL promotional text: "Word je nat? De regenvoorspelling voor de komende 2 uur, op je wijzerplaat, in de Smart Stack en als radar." (107).
  - nl-NL name option: keep `Rain`, or `Rain: regenradar` (16) if the plain name is weak in Dutch search. Apple flags names packed with keywords, so keep this a judgement call.
  - Description: first two lines say what it does and for whom (cyclists, commuters, dog walkers); then complications, Smart Stack, radar; then coverage ("Netherlands and nearby countries", per `LAUNCH.md` decision 5), the data credit, and a plain note that it needs location. The description must say what Rain does on Apple Watch ([Apple](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-watchos-app-information/)).
- Commands: `asc metadata init --dir metadata --version 1.0.0 --locale en-GB` (and `nl-NL`), edit the files, then `asc metadata keywords audit --app $ASC_APP_ID --version 1.0.0`, `asc metadata apply ... --dry-run`, review, `--confirm`. `asc validate` also flags placeholders such as `TODO` and wording reviewers reject ("beta", "test build").
- Keyword research: Apple's popularity scores come through the Apple Ads API (`asc optimize search plan`), which needs an Apple Ads account. I did not check what opening one involves, so I would skip it. Instead read competitor listings (Buienradar, Buienalarm and Weer & Radar all have watch support and 49,000 to 155,000 NL ratings in Apple's search API, which tells you how crowded the term space is) and check the result 30 days after launch.
- Time: 1 to 2 hours of agent work, then Josh edits.

**C6. Screenshots (the part that needs the most care).**
- Spec (Apple): one to ten PNG or JPEG per size, no alpha channel, **422 × 514 px for Ultra 3 and Ultra 4**; the other sizes are 410 × 502, 416 × 496, 396 × 484, 368 × 448, 312 × 390. "You must use the same screenshot size for Apple Watch consistently across all localizations." One size is enough: Apple scales it for other watches ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)). iPhone screenshots are not needed for a watch-only app.
- Sources of raw images, both already in the repo workflow: the simulator (`xcrun simctl io <udid> screenshot`, 422 × 514 for Ultra 3, as in `renders/simulator/face-fresh.png`) and Josh's real watch (`xcrun devicectl device capture screenshot`). Real watch shots are better for complication faces; the `-scenario` launch argument in `AGENTS.md` puts any state on his real face. `RainUITests` already saves a screenshot of each screen.
- The constraint nobody on X mentions: the whole store image is 422 × 514. A headline plus a device frame on that canvas leaves a small watch. `asc screenshots frame --device watch-ultra-3` outputs exactly 422 × 514 including the bezel, so the watch shrinks. My recommendation: skip the bezel, fill the canvas with the UI, and put a bold headline band (about 90 px) at the top or bottom. Design at 3× and downscale so the text stays sharp.
- Headlines (Practice: Paul's write-up of Theodora's method, [article](https://x.com/PaulSolt/status/2037591726227902555)): eight words or fewer, about the user's moment, ordered as a story, and test it by covering the UI and reading only the headlines. The numbers in it ("70% from text") come from the seller of the service, so treat them as marketing. Order from `LAUNCH.md`: "Will I get wet?", the circle on a face, the Smart Stack card, the forecast, the radar.
- Frames: device frames are accepted in screenshots, not in preview videos ([Paul](https://x.com/PaulSolt/status/2115458378965155924)); Apple's 2.3.4 covers previews, and Rain has none.
- Tools: build a small repeatable renderer in the repo (the repo already has `render-mockups`), driven by the real-watch captures, one input JSON per locale. Do not buy a screenshot service for one app. Always open each output at full size and look at it (the `AGENTS.md` rule); Josh has already been sent clipped images once.
- Dutch set: same size, same layout, Dutch headlines, and Dutch UI in the captures (needs the Dutch localisation of the app). Check text length: Dutch runs about 20% longer.
- Upload: `asc screenshots upload --app $ASC_APP_ID --version 1.0.0 --locale en-GB --path screenshots/en-GB --device-type APP_WATCH_ULTRA` (run `asc screenshots sizes --all` to confirm the exact type name; the guide lists older names, the source lists `APP_WATCH_ULTRA` for 422 × 514 and 410 × 502). `asc screenshots validate` rejects alpha channels. Use `--replace` to swap a set and `--resume` after a failed upload. Order with `asc screenshots reorder`. A user reported Apple rate limits when uploading many screenshots at high concurrency ([Rudrank's reply](https://x.com/rudrank/status/2121325871785255233)); five small files should not hit it.
- Time: first usable set 1 to 2 days of agent work plus Josh's choice; resizing and reuploading takes minutes.
- Goes wrong: wrong size (upload rejects it); text clipped; a state that is not real (Guideline 2.3.1 and 2.3.3 want real use of the app); showing data you do not have the right to show.

**C7. Review information and the demo video.**
- Fields: contact first name, last name, email, phone (with + and country code), notes (at most 4,000 characters), attachment. No demo account (Rain has no login).
- Commands: `asc review details-create --version-id ID --contact-first-name ... --contact-last-name ... --contact-email ... --contact-phone "+31 ..." --notes "$(cat review-notes.txt)"`, then `asc review attachments-upload --review-detail DETAIL_ID --file review-demo.mp4`. App Store Connect restricts attachment file types; confirm that `.mp4` or `.mov` is accepted at upload and fall back to a link in the notes if not.
- Notes should say: watch-only; no iPhone app; where the location prompt appears; that a reviewer outside the Netherlands can pick a place (name the exact steps); how to open the radar; where the data comes from and that permission exists (A1); what each complication family shows; that nothing is collected or sold.
- Demo video: about 60 seconds, no device frames (cheap insurance given Paul's rejection), showing first launch, place choice, forecast, radar, Smart Stack and a complication state. Record from the simulator (`xcrun simctl io <udid> recordVideo`, or the video `RainUITests` already records). `devicectl` cannot screen-record the real watch.
- Practice: kr0der attaches a video. Evidence it speeds review is one anecdote. Recommendation: do it anyway; the cost is an hour.
- Josh provides: the phone number and email Apple may use to contact him during review. They stay private to Apple and are separate from the public trader details in A3.

**C8. Attach the build and run the gates.**
- `asc versions create --app $ASC_APP_ID --version 1.0.0 --platform IOS`, then attach the build (`asc versions attach-build --app $ASC_APP_ID --version 1.0.0 --build-number N`), or do both with `asc release stage --app $ASC_APP_ID --version 1.0.0 --build-id BUILD_ID --metadata-dir metadata --dry-run` and then `--confirm`.
- Gates: `asc validate --app $ASC_APP_ID --version 1.0.0 --strict --output json` (public API checks: build, metadata, screenshots, age rating, categories, pricing, review contact, URLs with `--check-urls`), then `asc validate ... --deep` (needs the cached web session; checks App Privacy is published, agreements, availability), then `asc review doctor --app $ASC_APP_ID`. Its output says it cannot see regulatory declarations; read them with `asc web apps declarations list --app $ASC_APP_ID`.
- The `--platform` value is `IOS` for Rain, because App Store Connect has no watchOS platform.

**C9. Pricing and availability.**
- Free: choose the free price (price point 0), no Paid Apps Agreement. Paid: choose a price point with `asc pricing price-points --app $ASC_APP_ID --territory NLD`, set it, and set territories. First-time availability may need `asc pricing availability create --app $ASC_APP_ID --territory NLD,BEL,GBR,DEU --available true --available-in-new-territories false` (or `asc web apps availability create`; the docs say the public API falls short for the first availability). Start narrow: the Netherlands plus the countries Rain really covers (`LAUNCH.md` decision 5). More countries are easy to add later; a bad first impression abroad is not easy to undo.
- Practice: kr0der's subscription results are not comparable. His evidence is for weekly-subscription iPhone apps; see `research/launch-playbook.md`.
- Goes wrong: a price set before the agreement is active; Apple's "intended price" in a country that Rain does not cover.

### Phase D: TestFlight (internal from day 3, external from about day 5, two weeks of use)

**D1. Internal testing.**
- Internal testers are App Store Connect users (up to 100). Josh is enough. Create the group and add the build (`asc testflight groups create --app $ASC_APP_ID --name "Internal" --internal`, then `asc builds add-groups --build-id BUILD_ID --group "Internal"`).
- Install path for a watch-only app: install TestFlight on the paired iPhone, open the invitation, and tap Install from the Apps list (Apple: "if you're testing an app that's for Apple Watch only, tap Install"). So Josh's iPhone must be paired to the watch. TestFlight on the watch needs watchOS 9 or later.
- Builds expire after 90 days. Goes wrong: an Apple Watch TestFlight bug in April 2026 stopped apps launching until TestFlight 4.2.1 ([thread](https://developer.apple.com/forums/thread/821989)); update TestFlight and reinstall if the app does nothing when tapped.
- Check on the real watch: all complication families, Always On, Night Mode, tinted faces, offline, location denied, VoiceOver, larger text, battery (`LAUNCH.md` section 2). Pull the refresh log (`reloads.log`).

**D2. External testing (Dutch cyclists).**
- Create an external group (an internal group must exist first), add the first build, and fill in Test Information (beta description, "What to Test", feedback email, contact). The first build of the app goes to TestFlight App Review ("a review is required only for the first build"); you can submit up to six builds to it in 24 hours.
- Invite by email, or make a public link with criteria (device and OS filters such as watchOS 26 and Apple Watch). The group allows up to 10,000 testers. Each tester can install on up to 30 devices.
- Practice: Paul's public TestFlight link in every post, and onboarding calls ("2 onboarding calls ... than 1 month of watching analytics", [post](https://x.com/PaulSolt/status/2120563199074287986)). Dimillian had an app in TestFlight public beta review within two minutes of setup; his post does not say how long Apple's review took.
- Recommendation: 5 to 10 testers, 2 or 3 calls (screen-share the iPhone's TestFlight install, then ask them to say what they see on the watch face). This is also the "supplemental material" for the featuring nomination (D4 below).
- Time: beta review typically 1 to 3 days (my estimate; Apple gives no figure). Goes wrong: privacy policy or contact details missing; the build rejected for using a data source without permission.

**D3. Two weeks of use.**
- Josh wears it. The agent reads `asc testflight crashes list`, `asc testflight feedback list` and tester metrics (`asc testflight metrics app-testers`).
- Update builds go to the same group; keep the version number and bump the build number.
- Note that `requestReview` does nothing in TestFlight and, as above, does not exist on watchOS at all.

### Phase E: submit, review, release

**E1. Pre-flight checklist.**
- `asc validate` clean under `--strict` and `--deep`.
- Build attached is the exact one tested (record its build number).
- Review notes and video in place; Buienradar permission letter or KNMI switch settled; place picker works from a US location (test by setting the simulator's location to Cupertino).
- App Privacy published; trader status set; age rating present; accessibility label (if used) published; Dutch and English both complete.
- Every claim in the metadata is something Rain does today.
- Do not touch the build or metadata in a hurry afterwards: Paul "afraid to resubmit anything at this point to go back to the end of the queue".

**E2. Submit.**
- Dry run: `asc review submit --app $ASC_APP_ID --version 1.0.0 --build-id BUILD_ID --platform IOS --dry-run`. Confirm: the same command with `--confirm`, or `asc publish appstore --app $ASC_APP_ID --ipa ... --version 1.0.0 --submit --confirm` if you upload and submit in one go.
- Recommendation: let Josh press **Submit for Review** in the browser for the first-ever submission. Reason: one developer claims Apple auto-rejects CLI-submitted new apps (quoted by kr0der, who disagrees). Neither claim is proven; a browser click costs two minutes and also fits Josh's rule of approving every outward action. Use `asc` for everything up to that point and for status afterwards.
- Wait for status: `asc status --app $ASC_APP_ID --until review-done --timeout 2h` (exit code 0 approved, 1 rejected, 7 still pending) or `asc submit status --version-id VERSION_ID`.
- Expectation: Apple's stated medians are 24 and 48 hours. Observed this autumn: 5 days (kr0der, small app), about 14 days with one rejection (Paul, iPhone Duo season), "weeks" (kr0der). Plan for 14 days.
- Expedite: only after at least 24 hours of waiting and only if there is a real reason ([Apple's form](https://developer.apple.com/contact/app-store/?topic=expedite); kr0der and Paul both used it; Paul filed on 4 November and his review started the same day, though he does not say the request caused it).
- Goes wrong, and what to do:
  - **Rejection for metadata** (screenshots, text, privacy answers): read the message in the Resolution Center, fix the metadata, reply, and **resubmit the same build**. Do not accept "use the latest build" if offered (Paul's 8-day mistake).
  - **Rejection for the binary**: upload a new build, attach it, resubmit.
  - **4.3 spam or copycat** (kr0der's batch rejection; Rain is a rain forecast among many near-identical Buienradar-style apps): the answer is the review notes. Say what is different (watch-first complications, Smart Stack, radar on the wrist), and do not submit similar apps together.
  - **5.2.2 third-party content**: attach the permission or explain the KNMI source.
  - **2.1 incomplete** (outside-coverage state, placeholder text): fix the picker and the copy.
  - Apple's reply box takes 4,000 characters and attachments.

**E3. Release control.**
- Choose **manual release** ("Release this version manually after approval") on the version page (`asc versions update --version-id ID --release-type MANUAL`). The app then waits at "Pending Developer Release". This gives Josh time to check screenshots, the NL and UK storefront pages and the TestFlight build one last time.
- Phased release (7 days, 1% to 100%) is for updates, not first versions; use it for 1.0.1 and later. That is moot for a new watch app with no existing users anyway.
- `SCHEDULED` with `--earliest-release-date` is available if a timed launch matters.

**E4. Release and "Ready for Sale".**
- Josh presses **Release this version** (or `asc versions release --version-id ID --confirm`). App Store Connect then shows `READY_FOR_DISTRIBUTION` (the older name is "Ready for Sale"). The page can take up to 24 hours to appear everywhere (Apple's status page says "within 24 hours").
- Verify (read back, do not trust the success message): `asc status --app $ASC_APP_ID --include appstore,builds`, then open `https://apps.apple.com/nl/app/id<APP_ID>` and the `gb` and `us` versions. On the iPhone App Store a watch-only app appears as a watch app (Apple: "also available to customers on the iOS App Store"); on the watch, search for it on the watch's App Store.
- Install it fresh from the store on Josh's watch (delete the dev and TestFlight builds first) and check the location prompt, complications and Smart Stack.

### Phase F: featuring nomination (start as soon as the page is ready)

- Apple: "give our team a minimum of two weeks notice. For wider featuring consideration, we recommend submitting a nomination up to three months in advance." The help page says a minimum lead time of three weeks ([getting featured](https://developer.apple.com/app-store/getting-featured/), [nominate](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)). Apple lists the factors: user experience, UI design, innovation, uniqueness, accessibility, localisation and the product page, including ratings.
- How: App Store Connect, the app, Featuring, Nominations, Create Nomination. Type **App Launch**. Description with purpose and priority (what is new: complications, Smart Stack, radar), platform Apple Watch, countries, locales, a publish date or range, up to five supplemental URLs (a TestFlight public link counts), and helpful details on accessibility. Save as a draft and edit freely; submitted nominations can be edited too.
- CLI: `asc nominations create --app $ASC_APP_ID --name "Rain launch" --type APP_LAUNCH --description "..." --device-families APPLE_WATCH --publish-start-date "2026-12-15T08:00:00Z" --submitted=false`, review the draft, then `asc nominations update --id ID --submitted=true`. Rudrank has used it ([post](https://x.com/rudrank/status/2114067062628712890)).
- Practice: Paul's featuring followed a polish release and he does not say he nominated. Nothing in the sources shows how often nominations lead to featuring.
- Recommendation: create the app record in week one, then submit the nomination when external TestFlight starts, with the planned release date. It costs 20 minutes. Expect no response; Apple may email Admin, App Manager or Marketing users to ask for promotional artwork if it is interested; read its artwork guidelines then, not before.

### Phase G: the first weeks after launch

- **Day 0:** the fresh-install check above; read the product page in Dutch and English; confirm the privacy label and age rating show as intended; save a copy of the page.
- **Reviews:** turn on App Store Connect app notifications for new reviews and reply to every written review in month one (Practice: [kr0der, quoting @andilosing](https://x.com/kr0der/status/2078057623518433520)). Apple's 5.6.1 says answers must target the user's comment and carry no marketing. `asc reviews list --app $ASC_APP_ID` for a scripted look.
- **Ratings:** no in-app prompt exists on watchOS, so ask in the launch post and on the support page, using the link `https://apps.apple.com/app/id<APP_ID>?action=write-review` (Apple's documented review deep link). Do not copy Paul's personalised prompt; Apple's 5.6.1 disallows custom prompts and he himself calls it "a gray area" ([post](https://x.com/PaulSolt/status/2115814038080786759)).
- **Analytics and crashes:** `asc insights weekly --app $ASC_APP_ID`, `asc analytics` reports, and Xcode Organizer crash reports. Apple applies privacy thresholds to analytics (I did not check the numbers), so a small app may show little at first. Product page views and conversion are the measure Paul and Theodora use ("check conversion in App Analytics", over 30 days).
- **Launch post:** one honest post on X and a Dutch page (`LAUNCH.md` section 5), each text approved by Josh first. The evidence from kr0der is that paid ads and posting farms did not pay; Paul's one big result was Apple featuring.
- **Updates:** a 1.0.1 for the first real bug. Updates review faster than new apps (Paul: about a day, slowest 5 days; [post](https://x.com/PaulSolt/status/2073058903386951731)). Keywords, subtitle and name only change with a new version.
- **Week 4:** compare the conversion to the TestFlight feel, then consider changing the screenshot order or the first headline. Keep a dated record of what changed.
- **Standing duties:** re-check the data licence terms; keep the privacy label true if the data source changes; renew membership; answer support email.

## 5. Everything that can go wrong, in one list

1. Bare watch archive cannot be exported (step B1). Tested; fixed by the container.
2. `asc` upload of a watch-only package may fail (B5). Use `xcodebuild`.
3. Data source permission missing (A1, E2). Do not submit without it.
4. Outside-coverage state shows "No Forecast Here" to a US reviewer (C7, E2).
5. Privacy answers or purpose string do not match what the build does (C4, B3).
6. Name taken or disputed (A5, C1).
7. Wrong screenshot size or alpha channel (C6).
8. Device frames or fake states in any video or image (C6, C7).
9. Resubmitting with a new build after a metadata rejection (E2).
10. Slow review (E2): plan two weeks, do not submit batches of similar apps.
11. Trader verification delay (A3), and API access approval delay (A2).
12. Xcode or TestFlight changes (B1, D1): re-run the export-method check after each Xcode update.
13. The `requestReview` assumption in `LAUNCH.md` (cannot be built).
14. The preview-video assumption: none exists for watch, so the page depends entirely on screenshots.

## 6. What I did not verify

- The upload itself. I did not sign in, send anything to Apple, or run `asc` (I read its source and docs; `asc` is not installed here). The container archive and the export-method list are tested; processing in App Store Connect is not.
- Which `Info.plist` App Store Connect reads for `ITSAppUsesNonExemptEncryption` in a container.
- Whether App Store Connect accepts `.mp4` review attachments, and the exact `asc` device type name for 422 × 514 (the catalogue says `APP_WATCH_ULTRA`).
- Whether Apple's featuring reads Watch-only apps differently, how long beta review and trader checks take, and whether CLI submissions are treated differently. All sources are anecdotes or silent.
- Dutch tax, VAT and Chamber of Commerce questions if the app is paid.
- The `birdclaw` search is partial by design (each query returns a page or two). I read about 250 relevant posts across kr0der, Paul Solt, Rudrank, Dimillian and Paul Hudson in full, and skimmed Rudrank's many release-note posts. That is a sample of each person's archive, not all of it.

## 7. Sources I read in full

Apple: [Add watchOS app information](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-watchos-app-information/), [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/), [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/), [Reply to App Review messages](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages/), [Release a version update in phases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/), [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/), [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/), [Age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/), [App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/), [TestFlight for testers](https://developer.apple.com/testflight/testers), [Getting featured](https://developer.apple.com/app-store/getting-featured/), [Nominate your app](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/), [Submit](https://developer.apple.com/watchos/submit/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Store Connect API access](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api), [Small Business Program](https://developer.apple.com/app-store/small-business-program), [Provide tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information), [Creating your product page](https://developer.apple.com/app-store/product-page), [Creating independent watchOS apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps), [TN3157](https://developer.apple.com/documentation/technotes/tn3157-updating-your-watchos-project-for-swiftui-and-widgetkit), [Xcode: create and distribute a watch-only app](https://help.apple.com/xcode/mac/current/en.lproj/devaba4602fd.html), [Developer Forums thread 817223](https://developer.apple.com/forums/thread/817223), [App Review](https://developer.apple.com/distribute/app-review). Also `xcodebuild -help` and the watchOS 27.2 and iOS 27.2 SDK headers and Swift interfaces on this Mac.

`asc`: the README, `docs/WORKFLOWS.md`, the website guides (submission, screenshots, TestFlight, metadata, agent release checklist), the `validate`, `review`, `publish`, `release`, `versions`, `age-rating`, `web` and `pricing` command pages, and the source for the watch platform mapping, the screenshot catalogue, the upload-requirement check and the nominations command (repository snapshot of 14 November 2026).

Third-party: [Perry: shipping a watch-only app](https://www.perryts.com/en/blog/shipping-a-watch-only-app-to-the-app-store) and its [watchOS publishing page](https://docs.perryts.com/platforms/watchos-app-store.html), [a note on the iOS distribution container](https://note.com/herodini777/n/nd9c38757f32a?hl=en), [Paul Solt's newsletter on being featured](https://super-easy-apps.kit.com/posts/apple-featured-my-app-i-made-0), his rejection video (frames from 4:11 to 6:20), the ASO vendors' cross-localisation tables ([Asonomica](https://asonomica.com/blog/apple-cross-localization-map), [MobileAction](https://www.mobileaction.co/blog/app-store-cross-localization)), and the X posts linked above (fetched through the public fxtwitter mirror).
