import XCTest

/// Walks the app the way Josh uses it and keeps a screenshot of every screen, so each one can be
/// looked at before anyone else sees it. Run it with `xcodebuild test`; the screenshots are in the
/// result bundle's attachments.
@MainActor
final class RainUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        // That test starts from a fresh install with location never asked (App/test.sh resets it).
        if name.contains("WithoutLocation") { return }
        app.launch()
        continuePastIntro()
        allowLocation()
    }

    func testForecastPage() {
        XCTAssertTrue(app.staticTexts["Updated"].firstMatch.waitForExistence(timeout: 30) ||
                      app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch.waitForExistence(timeout: 30))
        keep("forecast")
    }

    /// The radar opens on the present and plays; the crown pauses it and steps through time; the
    /// zoom button widens the view.
    func testRadar() {
        let radar = app.buttons["Radar"].firstMatch
        XCTAssertTrue(radar.waitForExistence(timeout: 30))
        radar.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20), "The radar should open playing")
        sleep(1)
        keep("radar-opening-1")
        sleep(2)
        keep("radar-opening-2")
        // The crown only steps once the frames have arrived; until then there is nothing to step to.
        let frameLabel = app.staticTexts.matching(NSPredicate(format: "label == 'Now' OR label MATCHES '(in [0-9]+ min|[0-9]+ min ago)'")).firstMatch
        XCTAssertTrue(frameLabel.waitForExistence(timeout: 20), "The radar should name the moment it shows")
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
        sleep(2)
        keep(startsClose ? "radar-region" : "radar-near")
    }

    /// Every kind of forecast on the app's first page, from saved real forecasts, and the failures.
    func testEveryForecastPage() {
        for scenario in ["dry", "showerComing", "onAndOff", "drizzleStops", "rainingEasing", "rainComing", "rainAllWindow"] {
            app.terminate()
            app.launchArguments = ["-scenario", scenario]
            app.launch()
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch.waitForExistence(timeout: 15))
            keep("page-\(scenario)")
        }
        for failure in ["noLocation", "offline", "notCovered"] {
            app.terminate()
            app.launchArguments = ["-failure", failure]
            app.launch()
            sleep(2)
            keep("page-\(failure)")
        }
    }

    /// The radar's strip with rain in it, from a saved forecast (the radar frames are live).
    func testRadarWithRain() {
        app.terminate()
        app.launchArguments = ["-scenario", "rainComing"]
        app.launch()
        let radar = app.buttons["Radar"].firstMatch
        XCTAssertTrue(radar.waitForExistence(timeout: 15))
        radar.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20))
        sleep(3)
        keep("radar-rain")
    }

    /// Apple's reviewer may refuse location: the app must still work, with a place picked by name.
    func testChoosePlaceWithoutLocation() {
        app.launchArguments = ["-freshInstall", "YES"]
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
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch.waitForExistence(timeout: 30),
                      "Picking a town should show its forecast")
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
