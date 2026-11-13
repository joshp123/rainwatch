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
        keep("radar-near-1")
        sleep(2)
        keep("radar-near-2")
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.25)
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "Turning the crown should pause")
        sleep(1)
        keep("radar-crown")
        app.buttons["Zoom out"].firstMatch.tap()
        sleep(2)
        keep("radar-region")
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
