import XCTest

/// Walks the app the way Josh uses it and keeps a screenshot of every screen, so each one can be
/// looked at before anyone else sees it. Run it with `xcodebuild test`; the screenshots are in the
/// result bundle's attachments.
@MainActor
final class RainUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launch()
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

    /// Location permission is asked by the system, outside the app.
    private func allowLocation() {
        for bundle in ["com.apple.Carousel", "com.apple.springboard"] {
            let system = XCUIApplication(bundleIdentifier: bundle)
            for label in ["Allow While Using App", "Allow Once"] {
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
