import CoreLocation
import Foundation

/// Where to forecast. The app asks for location permission and finds a fix; the widget tries for
/// its own fix. Both remember the last fix in the shared app group, so the widget still has a place
/// when it cannot get one (watchOS gives widgets no way to check their own location permission).
public enum Place {
    public static let appGroup = "group.nl.jjp.rain"

    public enum Failure: Error {
        case noLocation
    }

    /// A fresh fix if one comes within `timeout`, otherwise the last saved one.
    public static func current(timeout: Duration = .seconds(10)) async throws -> CLLocationCoordinate2D {
        if let fix = await fix(timeout: timeout) {
            save(fix)
            return fix
        }
        if let saved { return saved }
        throw Failure.noLocation
    }

    public static var saved: CLLocationCoordinate2D? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              defaults.object(forKey: "latitude") != nil else { return nil }
        return CLLocationCoordinate2D(latitude: defaults.double(forKey: "latitude"), longitude: defaults.double(forKey: "longitude"))
    }

    private static func save(_ coordinate: CLLocationCoordinate2D) {
        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.set(coordinate.latitude, forKey: "latitude")
        defaults?.set(coordinate.longitude, forKey: "longitude")
    }

    private static func fix(timeout: Duration) async -> CLLocationCoordinate2D? {
        await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location { return location.coordinate }
                        if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
