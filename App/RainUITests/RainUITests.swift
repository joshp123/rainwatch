import CoreLocation
import XCTest

/// Walks the app the way Josh uses it and keeps a screenshot of every screen, so each one can be
/// looked at before anyone else sees it. Run it with `App/test.sh`, which serves a copy of the
/// server's files on this Mac; the screenshots are in the result bundle's attachments.
@MainActor
final class RainUITests: XCTestCase {
    let app = XCUIApplication()

    /// The local copy of the server, passed on by `test.sh` (TEST_RUNNER_RAIN_SERVER).
    private var server: [String] {
        ProcessInfo.processInfo.environment["RAIN_SERVER"].map { ["-server", $0] } ?? []
    }

    override func setUp() async throws {
        continueAfterFailure = false
        // That test starts from a fresh install with location never asked (App/test.sh resets it).
        if name.contains("WithoutLocation") { return }
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 51.92, longitude: 4.48))
        app.launchArguments = server + ["-freshInstall", "YES"]
        app.launch()
        continuePastIntro()
        allowLocation()
    }

    /// Rotterdam is in KNMI's area: its forecast comes from the server, with KNMI named.
    func testForecastPage() {
        XCTAssertTrue(headline.waitForExistence(timeout: 30), "The forecast should show")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'KNMI forecast made'")).firstMatch.exists,
                      "KNMI's forecast should name KNMI and say when it was made")
        XCTAssertTrue(app.buttons["Radar"].exists, "KNMI's area has the radar")
        XCTAssertTrue(app.staticTexts["Rotterdam"].waitForExistence(timeout: 20), "The page should name the town where you are")
        keep("forecast")
        audit("forecast")
        // The privacy policy and KNMI's licence, at the end of the page.
        let about = app.buttons["About"].firstMatch
        for _ in 0..<5 where !about.isHittable { app.swipeUp() }
        about.tap()
        XCTAssertTrue(app.links.containing(NSPredicate(format: "label BEGINSWITH 'Privacy Policy'")).firstMatch.waitForExistence(timeout: 5),
                      "About should link the privacy policy")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Rain data from KNMI under CC BY 4.0'")).firstMatch.exists,
                      "About should give KNMI's licence")
        keep("about")
        audit("about")
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.4)
        sleep(1)
        keep("about-knmi")
        app.swipeUp()
        keep("about-apple")
    }

    /// The radar opens on the present and plays; the crown pauses it and steps through time; the
    /// zoom button widens the view.
    func testRadar() {
        let radar = app.buttons["Radar"].firstMatch
        XCTAssertTrue(radar.waitForExistence(timeout: 30))
        radar.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20), "The radar should open playing")
        let frameLabel = app.staticTexts.matching(NSPredicate(format: "label == 'Now' OR label MATCHES '(in [0-9]+ min|[0-9]+ min ago)'")).firstMatch
        XCTAssertTrue(frameLabel.waitForExistence(timeout: 20), "The radar should name the moment it shows")
        XCTAssertTrue(app.staticTexts["Source: KNMI"].exists, "The radar should name KNMI")
        sleep(1)
        keep("radar-opening")
        audit("radar")
        // A small turn may not cross a detent, as on the real crown; a person turns again.
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        if !app.buttons["Play"].waitForExistence(timeout: 3) {
            XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        }
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "Turning the crown should pause")
        sleep(1)
        keep("radar-crown")
        // It opens close when rain is due here and wide when not; the button switches either way.
        let zoomOut = app.buttons["Zoom out"].firstMatch
        let startsClose = zoomOut.exists
        (startsClose ? zoomOut : app.buttons["Zoom in"].firstMatch).tap()
        XCTAssertTrue(app.buttons[startsClose ? "Zoom in" : "Zoom out"].firstMatch.waitForExistence(timeout: 5))
        sleep(3)
        keep(startsClose ? "radar-region" : "radar-near")
    }

    /// Every kind of forecast on the app's first page, from saved real KNMI forecasts, and the
    /// failures.
    func testEveryForecastPage() {
        for scenario in ["dry", "showerComing", "onAndOff", "drizzleStops", "rainingEasing", "rainComing", "rainAllWindow", "heavy"] {
            app.terminate()
            app.launchArguments = server + ["-scenario", scenario]
            app.launch()
            XCTAssertTrue(headline.waitForExistence(timeout: 15))
            keep("page-\(scenario)")
        }
        // Apple's screens, from test data shaped like its answers (live WeatherKit is tested below).
        for (scenario, hourly) in [("ukNextHour", false), ("spainHourly", true)] {
            app.terminate()
            app.launchArguments = server + ["-scenario", scenario]
            app.launch()
            XCTAssertTrue(headline.waitForExistence(timeout: 15))
            XCTAssertTrue(appleLegal.exists, "\(scenario): Apple's legal link")
            XCTAssertFalse(app.buttons["Radar"].exists, "\(scenario): no radar outside KNMI's area")
            XCTAssertEqual(app.staticTexts["Hourly forecast"].exists, hourly, "\(scenario): hourly label")
            keep("page-\(scenario)")
            app.swipeUp()
            sleep(1)
            keep("page-\(scenario)-credit")
        }
        // Apple's hourly forecast, 40 minutes old: still labelled hourly, with its time.
        app.terminate()
        app.launchArguments = server + ["-scenario", "spainHourly", "-age", "40"]
        app.launch()
        XCTAssertTrue(headline.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Hourly forecast made'")).firstMatch.exists,
                      "An old hourly forecast should stay labelled hourly")
        keep("page-spainHourly-old")
        // Apple's legal link opens its legal text in the app: the watch has no browser for it.
        for _ in 0..<5 where !appleLegal.isHittable { app.swipeUp() }
        appleLegal.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Changed by'")).firstMatch.waitForExistence(timeout: 10),
                      "Apple's legal link should open on the note that Apple's data was changed")
        sleep(3)
        keep("about-from-legal")
        app.swipeUp()
        keep("about-from-legal-text")
        for failure in ["notAsked", "noLocation", "locationNotFound", "offline", "noForecast", "stale"] {
            app.terminate()
            app.launchArguments = server + ["-failure", failure]
            app.launch()
            sleep(2)
            keep("page-\(failure)")
        }
    }

    /// Rain arriving on the radar at Alkmaar: the strip and the map from the server's files, stepped
    /// through with the crown, close and wide.
    func testRadarWithRain() {
        app.terminate()
        app.launchArguments = server + ["-scenario", "rainComing"]
        app.launch()
        let radar = app.buttons["Radar"].firstMatch
        XCTAssertTrue(radar.waitForExistence(timeout: 15))
        radar.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20))
        sleep(3)
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        if !app.buttons["Play"].waitForExistence(timeout: 3) { XCUIDevice.shared.rotateDigitalCrown(delta: 0.5) }
        // Back through time a few frames at a time: the frame label changes with each turn.
        let label = app.staticTexts.matching(NSPredicate(format: "label == 'Now' OR label MATCHES '(in [0-9]+ min|[0-9]+ min ago)'")).firstMatch
        var seen: Set<String> = []
        for step in 0..<4 {
            sleep(1)
            seen.insert(label.label)
            keep("radar-rain-near-\(step)")
            XCUIDevice.shared.rotateDigitalCrown(delta: -0.4)
        }
        XCTAssertGreaterThan(seen.count, 2, "Turning the crown should move through time")
        app.buttons["Zoom out"].firstMatch.tap()
        sleep(3)
        keep("radar-rain-wide")
    }

    /// Outside KNMI's area the forecast comes from Apple: minute by minute in the UK, hourly in
    /// Spain, each with Apple's Weather mark and legal link, and no radar.
    func testAppleWeatherPlaces() {
        for (name, latitude, longitude, hourly) in [("london", 51.507, -0.128, false), ("madrid", 40.417, -3.704, true)] {
            app.terminate()
            XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: latitude, longitude: longitude))
            app.launchArguments = server + ["-freshInstall", "YES"]
            app.launch()
            XCTAssertTrue(headline.waitForExistence(timeout: 30), "\(name): Apple's forecast should show")
            XCTAssertTrue(appleLegal.exists, "\(name): Apple's legal link")
            XCTAssertFalse(app.buttons["Radar"].exists, "\(name): no radar outside KNMI's area")
            XCTAssertEqual(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Hourly forecast'")).firstMatch.exists, hourly,
                           "\(name): hourly only where Apple has no minute forecast")
            keep("apple-\(name)")
            audit("apple-\(name)")
        }
    }

    /// A refresh that fails over a saved forecast says so, with the forecast's age and Try Again
    /// in view: some minutes later the person opens the app with no connection. (A forecast under
    /// two minutes old is reused without a request, so the test waits that long.)
    func testFailedRefreshSaysSo() {
        XCTAssertTrue(headline.waitForExistence(timeout: 30))
        app.terminate()
        sleep(125)
        app.launchArguments = ["-server", "http://127.0.0.1:1"]
        app.launch()
        sleep(10)
        keep("refresh-failed")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Couldn’t update'")).firstMatch.exists,
                      "A failed refresh should say so")
        let again = app.buttons["Try Again"].firstMatch
        XCTAssertTrue(again.exists, "A failed refresh should offer Try Again")
        if !again.isHittable { app.swipeUp() }
        XCTAssertTrue(again.isHittable, "Try Again should be one swipe away at most")
    }

    /// The radar says plainly when it can't be reached, and offers Try Again instead of playback.
    func testRadarUnavailable() {
        app.terminate()
        app.launchArguments = ["-server", "http://127.0.0.1:1", "-scenario", "rainComing"]
        app.launch()
        let radar = app.buttons["Radar"].firstMatch
        XCTAssertTrue(radar.waitForExistence(timeout: 15))
        radar.tap()
        sleep(6)
        keep("radar-unavailable")
        XCTAssertTrue(app.buttons["Try Again"].firstMatch.exists, "The radar should offer Try Again")
        XCTAssertFalse(app.buttons["Pause"].exists || app.buttons["Play"].exists, "Nothing to play")
    }

    /// Sets up the simulator's Modular Ultra face (added by hand once, from All Watch Faces) the way
    /// the design shows it: RainWatch in the large slot and in the bottom middle circle.
    func testSetUpFaceWithoutLocation() {
        let face = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        // Out of whatever the last run left open, then to the face by way of the app: one press of
        // the crown from an app always lands on the face.
        answerLocation("Don’t Allow")
        for label in ["Close", "Back"] where face.buttons[label].firstMatch.exists { face.buttons[label].firstMatch.tap(); sleep(2) }
        app.launchArguments = ["-scenario", "onAndOff"]
        app.launch()
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(4)
        func dump(_ tag: String) {
            let texts = face.staticTexts.allElementsBoundByIndex.map(\.label)
            let buttons = face.buttons.allElementsBoundByIndex.map { "\($0.label)\($0.isHittable ? "" : "~")" }
            print("EXPLORE \(tag) texts: \(texts) buttons: \(buttons)")
            keep("explore-\(tag)")
        }
        for y in [0.85, 0.3, 0.6] where !face.buttons["Edit"].exists {
            face.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y)).press(forDuration: 2)
            sleep(3)
        }
        dump("library")
        face.buttons["Edit"].tap()
        sleep(3)
        func slot(_ name: String) -> XCUIElement { face.buttons["\(name) complication"] }
        for _ in 0..<8 where !slot("Middle").isHittable { face.swipeLeft(); sleep(2) }
        /// Picks an app's complication for a slot, taking the first one where the app lists several.
        func set(_ name: String, to app: String) {
            slot(name).tap()
            sleep(3)
            let target = face.staticTexts[app].firstMatch
            var found = false
            for _ in 0..<90 {
                if target.exists, target.isHittable { found = true; break }
                if target.exists { XCUIDevice.shared.rotateDigitalCrown(delta: 0.3) } else { face.swipeUp(velocity: .slow) }
            }
            guard found else {
                print("EXPLORE \(app) not offered for \(name)")
                face.buttons["Close"].firstMatch.tap()
                sleep(2)
                return
            }
            target.tap()
            sleep(3)
            if !slot(name).isHittable {
                dump("choices-\(name)")
                let first = face.cells.firstMatch
                if first.exists { first.tap(); sleep(3) }
            }
            if !slot(name).isHittable { face.buttons["Back"].firstMatch.tap(); sleep(2) }
        }
        set("Bottom Middle", to: "RainWatch")
        set("Bottom Left", to: "Time")
        dump("configured")
        XCUIDevice.shared.press(.home)
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(4)
        dump("face")
    }

    /// The face after the app, as the wearer sees it on leaving the app.
    @discardableResult private func keepFace(_ name: String) -> XCUIElement {
        XCUIDevice.shared.press(.home)
        sleep(5)
        let face = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        keep(name)
        return face
    }

    /// Apple's reviewer may refuse location: the app must still work, with a place picked by name.
    func testChoosePlaceWithoutLocation() {
        app.launchArguments = server + ["-freshInstall", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'To see the rain where you are'")).firstMatch.waitForExistence(timeout: 15),
                      "A first launch should say which answer to choose before the system asks")
        keep("place-intro")
        app.buttons["Continue"].tap()
        sleep(2)
        keep("place-location-question")
        answerLocation("Don’t Allow")
        XCTAssertTrue(app.staticTexts["Location Off"].waitForExistence(timeout: 30), "Refusing location should say so")
        let choose = app.buttons["Choose a Place"].firstMatch
        XCTAssertTrue(choose.exists, "Refusing location should offer a place instead")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'On your iPhone, open Settings'")).firstMatch.exists,
                      "Location Off should say how to turn it on: watchOS lets no app open Settings")
        keep("place-location-refused")
        choose.tap()
        let field = app.textFields["Town or postcode"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // A tap while the sheet is still sliding in does not open the keyboard.
        sleep(2)
        field.tap()
        sleep(2)
        app.typeText("Utrecht")
        // The watch keyboard runs outside the app; a person finishes with its Done button.
        let done = [app, XCUIApplication(bundleIdentifier: "com.apple.Carousel")]
            .map { $0.buttons["Done"].firstMatch }
            .first { $0.waitForExistence(timeout: 3) }
        XCTAssertNotNil(done, "The keyboard should offer Done")
        done?.tap()
        let utrecht = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Utrecht'")).firstMatch
        XCTAssertTrue(utrecht.waitForExistence(timeout: 20), "Searching should find the town")
        sleep(3)
        keep("place-search")
        audit("place-search")
        utrecht.tap()
        XCTAssertTrue(headline.waitForExistence(timeout: 30), "Picking a town should show its forecast")
        XCTAssertTrue(app.staticTexts["Utrecht"].exists, "The page should be named after the picked town")
        keep("place-forecast")
        keepFace("place-face-utrecht")
        app.activate()
        // Back to the wearer's location, as someone would after a trip.
        // At the end of the page: a sliver of it shows at first, too little to tap.
        let change = app.buttons["Change Place"].firstMatch
        app.swipeUp()
        for _ in 0..<5 where !change.isHittable { app.swipeUp() }
        change.tap()
        let mine = app.buttons["Use My Location"].firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 5))
        mine.tap()
        XCTAssertTrue(app.staticTexts["Location Off"].waitForExistence(timeout: 30))
        keep("place-location-off")
        // The face follows: no place, never the last one.
        let face = keepFace("place-face-location-off")
        for words in ["PLACE", "Location off"] {
            XCTAssertTrue(face.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch.exists,
                          "The face should say \(words)")
        }
    }

    /// Apple's line under its forecast, which opens its legal text.
    private var appleLegal: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Legal'")).firstMatch
    }

    /// Apple's accessibility audit of the screen. Every issue is printed; a control too small to hit
    /// fails the test, except MapKit's own Legal link, which the Maps terms forbid changing
    /// (Attachment 6, 2.1).
    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let label = issue.element?.label ?? ""
                print("AUDIT \(screen): \(issue.auditType) \(issue.compactDescription) [\(label)]")
                return issue.auditType != .hitRegion || label == "Legal"
            }
        } catch {
            XCTFail("\(screen): \(error)")
        }
    }

    /// The forecast page is up when its headline is, and that always starts with "Dry" or "Rain".
    private var headline: XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Dry ' OR label BEGINSWITH 'Rain '")).firstMatch
    }

    /// The first launch explains the location question before the system asks it.
    private func continuePastIntro() {
        let next = app.buttons["Continue"]
        if next.waitForExistence(timeout: 5) { next.tap() }
    }

    /// Location permission is asked by the system, outside the app.
    private func allowLocation() {
        answerLocation("Allow While Using App", "Allow Once")
    }

    private func answerLocation(_ labels: String...) {
        for bundle in ["com.apple.Carousel", "com.apple.springboard"] {
            let system = XCUIApplication(bundleIdentifier: bundle)
            for label in labels {
                let button = system.buttons[label]
                if button.waitForExistence(timeout: 3) {
                    button.tap()
                    return
                }
            }
        }
    }

    func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
