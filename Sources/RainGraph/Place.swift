import CoreLocation
import Foundation
import Synchronization

/// Where to forecast: a place the wearer picked, or else where they are. The app asks for location
/// permission and finds a fix; the widget tries for its own fix. Both remember the last fix in the
/// shared app group, so the widget still has a place when it cannot get one (watchOS gives widgets
/// no way to check their own location permission).
public enum Place {
    public static let appGroup = "group.nl.jjp.rain"

    public enum Failure: Error {
        case noLocation
    }

    public struct Found: Sendable {
        public let coordinate: CLLocationCoordinate2D
        /// True for a fix taken now, false for the last saved one or a picked place.
        public let isLive: Bool
        public let at: Date
        /// Set for a place the wearer picked.
        public var chosen: Chosen?
    }

    /// A place picked by name instead of the wearer's location. Apple requires a way in for people
    /// who don't share their location, and it also lets anyone watch the rain somewhere else.
    public struct Chosen: Codable, Hashable, Sendable {
        public let name: String
        /// Region and country, to tell apart places with the same name.
        public let detail: String
        public let latitude: Double
        public let longitude: Double

        public init(name: String, detail: String, latitude: Double, longitude: Double) {
            self.name = name
            self.detail = detail
            self.latitude = latitude
            self.longitude = longitude
        }

        public var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    public static var chosen: Chosen? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: "chosenPlace") else { return nil }
        return try? JSONDecoder().decode(Chosen.self, from: data)
    }

    /// Picks a place, or with nil goes back to the wearer's location.
    public static func choose(_ place: Chosen?) {
        let defaults = UserDefaults(suiteName: appGroup)
        if let place, let data = try? JSONEncoder().encode(place) {
            defaults?.set(data, forKey: "chosenPlace")
        } else {
            defaults?.removeObject(forKey: "chosenPlace")
        }
    }

    /// A fix under five minutes old is reused: each widget on the face reloads at about the same
    /// time, and one GPS fix serves them all.
    static let reuseFor: TimeInterval = 5 * 60

    /// The picked place if there is one; else the saved fix if it is recent, else a fresh fix if one
    /// comes within `timeout`, else the last saved one.
    public static func current(timeout: Duration = .seconds(8)) async throws -> Found {
        if let chosen {
            return Found(coordinate: chosen.coordinate, isLive: false, at: .now, chosen: chosen)
        }
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

    /// Forgets the saved fix and any picked place, as a new install would.
    public static func forget() {
        let defaults = UserDefaults(suiteName: appGroup)
        for key in ["latitude", "longitude", "fixedAt", "chosenPlace"] { defaults?.removeObject(forKey: key) }
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

    /// Returns at the timeout even when Core Location never answers: a task group would wait for
    /// the location task to end, and on a watch waiting for permission it does not end.
    private static func fix(timeout: Duration) async -> CLLocationCoordinate2D? {
        let answered = Mutex(false)
        return await withCheckedContinuation { continuation in
            let answer: @Sendable (CLLocationCoordinate2D?) -> Void = { coordinate in
                let first = answered.withLock { done in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(returning: coordinate) }
            }
            let updates = Task {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location { return answer(location.coordinate) }
                        if update.authorizationDenied || update.authorizationDeniedGlobally { return answer(nil) }
                    }
                } catch {}
                answer(nil)
            }
            Task {
                try? await Task.sleep(for: timeout)
                updates.cancel()
                answer(nil)
            }
        }
    }
}
