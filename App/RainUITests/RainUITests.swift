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
        XCTAssertTrue(forecastFrom.waitForExistence(timeout: 30), "The forecast should say when its data is from")
        XCTAssertTrue(app.staticTexts["Source: KNMI"].exists, "KNMI's forecast should name KNMI")
        XCTAssertTrue(app.buttons["Radar"].exists, "KNMI's area has the radar")
        keep("forecast")
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
            XCTAssertTrue(forecastFrom.waitForExistence(timeout: 15))
            keep("page-\(scenario)")
        }
        for failure in ["noLocation", "offline", "noForecast", "stale"] {
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
            XCTAssertTrue(forecastFrom.waitForExistence(timeout: 30), "\(name): Apple's forecast should show")
            XCTAssertTrue(app.links["Legal"].exists || app.buttons["Legal"].exists, "\(name): Apple's legal link")
            XCTAssertFalse(app.buttons["Radar"].exists, "\(name): no radar outside KNMI's area")
            XCTAssertEqual(app.staticTexts["Hourly forecast"].exists, hourly, "\(name): hourly only where Apple has no minute forecast")
            keep("apple-\(name)")
        }
    }

    /// Apple's reviewer may refuse location: the app must still work, with a place picked by name.
    func testChoosePlaceWithoutLocation() {
        app.launchArguments = server + ["-freshInstall", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Rain where you are"].waitForExistence(timeout: 15), "A first launch should explain the location question first")
        keep("place-intro")
        app.buttons["Continue"].tap()
        sleep(2)
        keep("place-location-question")
        answerLocation("Don’t Allow")
        XCTAssertTrue(app.staticTexts["Location Needed"].waitForExistence(timeout: 30), "Refusing location should say so")
        let choose = app.buttons["Choose a Place"].firstMatch
        XCTAssertTrue(choose.exists, "Refusing location should offer a place instead")
        keep("place-location-refused")
        choose.tap()
        let field = app.textFields["Town or Postcode"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        app.typeText("Utrecht")
        // The watch keyboard runs outside the app; a person finishes with its Done button.
        let done = [app, XCUIApplication(bundleIdentifier: "com.apple.Carousel")]
            .map { $0.buttons["Done"].firstMatch }
            .first { $0.waitForExistence(timeout: 3) }
        XCTAssertNotNil(done, "The keyboard should offer Done")
        done?.tap()
        let utrecht = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Utrecht'")).firstMatch
        XCTAssertTrue(utrecht.waitForExistence(timeout: 20), "Searching should find the town")
        keep("place-search")
        utrecht.tap()
        XCTAssertTrue(forecastFrom.waitForExistence(timeout: 30), "Picking a town should show its forecast")
        XCTAssertTrue(app.staticTexts["Utrecht"].exists, "The page should be named after the picked town")
        keep("place-forecast")
        // Back to the wearer's location, as someone would after a trip.
        let change = app.buttons["Change Place"].firstMatch
        for _ in 0..<5 where !change.isHittable { app.swipeUp() }
        change.tap()
        let mine = app.buttons["Use My Location"].firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 5))
        mine.tap()
        XCTAssertTrue(app.staticTexts["Location Needed"].waitForExistence(timeout: 30))
    }

    private var forecastFrom: XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Forecast from'")).firstMatch
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
