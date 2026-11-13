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

    public struct Found: Sendable {
        public let coordinate: CLLocationCoordinate2D
        /// True for a fix taken now, false for the last saved one.
        public let isLive: Bool
        public let at: Date
    }

    /// A fix under five minutes old is reused: each widget on the face reloads at about the same
    /// time, and one GPS fix serves them all.
    static let reuseFor: TimeInterval = 5 * 60

    /// The saved fix if it is recent, else a fresh fix if one comes within `timeout`, else the last
    /// saved one.
    public static func current(timeout: Duration = .seconds(8)) async throws -> Found {
        if let saved, let at = savedAt, Date.now.timeIntervalSince(at) < reuseFor {
            return Found(coordinate: saved, isLive: false, at: at)
        }
        if let fix = await fix(timeout: timeout) {
            save(fix)
            return Found(coordinate: fix, isLive: true, at: .now)
        }
        if let saved, let at = savedAt { return Found(coordinate: saved, isLive: false, at: at) }
        throw Failure.noLocation
    }

    public static var savedAt: Date? {
        UserDefaults(suiteName: appGroup)?.object(forKey: "fixedAt") as? Date
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
        defaults?.set(Date.now, forKey: "fixedAt")
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
