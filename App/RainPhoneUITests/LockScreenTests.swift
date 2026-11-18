import XCTest

/// Puts RainWatch's widgets on the iPhone Lock Screen the way a person adds them, beside Apple's
/// Batteries circle for scale, then shows the Lock Screen. Run `testAddWidgets` once on a new
/// simulator; after that `testShowLockScreen` shows whatever the widgets say, for screenshots taken
/// with `xcrun simctl io <device> screenshot`. XCUITest's own screenshots miss the Lock Screen
/// editor, so the pictures come from simctl.
@MainActor
final class LockScreenTests: XCTestCase {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func pressLock() {
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    }

    func testAddWidgets() {
        pressLock(); sleep(2); pressLock(); sleep(3)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 2)
        XCTAssertTrue(springboard.buttons["posterboard-customize-button"].waitForExistence(timeout: 5))
        springboard.buttons["posterboard-customize-button"].tap()
        XCTAssertTrue(springboard.buttons["grouped-widgets-reticle-view"].waitForExistence(timeout: 10))
        sleep(2)
        springboard.buttons["grouped-widgets-reticle-view"].firstMatch.tap()
        add("RainWatch", ["Rectangular", "Circular"])
        add("Batteries", ["Circular"])
        springboard.buttons["Sheet Grabber"].firstMatch.swipeDown()
        sleep(2)
        springboard.buttons["inline-widget-reticle-view"].firstMatch.tap()
        let inline = springboard.cells["RainWatch, RainWatch, Top Widget"].firstMatch
        XCTAssertTrue(inline.waitForExistence(timeout: 5), "RainWatch should be offered above the clock")
        inline.tap()
        sleep(2)
        if springboard.buttons["Sheet Grabber"].exists { springboard.buttons["Sheet Grabber"].firstMatch.swipeDown(); sleep(2) }
        springboard.buttons["editing-done"].firstMatch.tap()
        sleep(3)
        if springboard.otherElements["poster-switcher-view"].exists { springboard.cells.firstMatch.tap(); sleep(2) }
    }

    /// Picks an app in the widget gallery and adds its widgets in the given sizes.
    private func add(_ app: String, _ sizes: [String]) {
        let row = springboard.cells[app].firstMatch
        sleep(2)
        // On a new phone the gallery opens with suggestions first, and the list of apps below them.
        for _ in 0..<8 where !(row.exists && row.isHittable) {
            springboard.toolbars["Toolbar"].firstMatch.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(row.isHittable, "\(app) should be in the widget gallery")
        row.tap()
        sleep(2)
        for size in sizes {
            springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND value CONTAINS %@", app, size)).firstMatch.tap()
            sleep(2)
        }
        springboard.buttons["close"].firstMatch.tap()
        sleep(2)
    }

    /// Locks and wakes the phone, so the Lock Screen shows what the widgets now say.
    func testShowLockScreen() {
        if springboard.otherElements["poster-switcher-view"].exists { springboard.cells.firstMatch.tap(); sleep(2) }
        pressLock(); sleep(2); pressLock(); sleep(8)
    }
}
