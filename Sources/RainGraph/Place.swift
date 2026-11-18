import CoreLocation
import Foundation
import Synchronization

/// Where to forecast: a place the wearer picked, or else where they are. The app asks for location
/// permission and finds a fix; the widget tries for its own fix. Both remember the last fix in the
/// shared app group, so the widget still has a place when it cannot get one (watchOS gives widgets
/// no way to check their own location permission).
public enum Place {
    public static let appGroup = "group.nl.jjp.rain"

    /// Why there is no place to forecast for.
    public enum Failure: Error, Equatable {
        /// Location was never answered.
        case notAsked
        /// Location was allowed, and the system will ask again: Allow Once has run out, or the
        /// wearer chose Ask Next Time in Settings.
        case expired
        /// Location is refused or turned off.
        case off
        /// Location is allowed, but no fix has come for an hour.
        case notFound
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
    ///
    /// Apple's Maps terms allow its search results to be kept only for a while (Attachment 6, 2.5),
    /// and towns have no Place ID, the one thing they let an app keep. So only the words the wearer
    /// typed are kept, with the position rounded to the 0.01 degrees the forecast is asked for.
    public struct Chosen: Codable, Hashable, Sendable {
        /// What the wearer typed, never Apple's name for the place.
        public let name: String
        public let latitude: Double
        public let longitude: Double

        public init(name: String, latitude: Double, longitude: Double) {
            self.name = name
            self.latitude = (latitude * 100).rounded() / 100
            self.longitude = (longitude * 100).rounded() / 100
        }

        /// A place saved by an earlier build is rounded as it is read.
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            self.init(name: try values.decode(String.self, forKey: .name),
                      latitude: try values.decode(Double.self, forKey: .latitude),
                      longitude: try values.decode(Double.self, forKey: .longitude))
        }

        private enum CodingKeys: String, CodingKey {
            case name, latitude, longitude
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

    /// A saved fix is where the wearer was. A complication that cannot get its own fix may stand on
    /// it for an hour, as it may stand on an hour-old forecast; after that there is no place. So a
    /// watch that cannot find itself never goes on showing a town the wearer left this morning.
    /// Once Allow Once has run out the fix is not used at all.
    public static let trustFor: TimeInterval = 60 * 60

    private static var trustedSaved: (CLLocationCoordinate2D, Date)? {
        guard let saved, let at = savedAt, Date.now.timeIntervalSince(at) < trustFor else { return nil }
        return (saved, at)
    }

    /// A fix from within the hour that is at hand without waiting: the saved one, or the last one
    /// the system holds. The app shows its forecast at once and then looks for a new fix.
    public static var recent: (coordinate: CLLocationCoordinate2D, at: Date)? {
        if let (saved, at) = trustedSaved { return (saved, at) }
        guard let last = CLLocationManager().location, Date.now.timeIntervalSince(last.timestamp) < trustFor else { return nil }
        return (last.coordinate, last.timestamp)
    }

    /// The picked place if there is one; else the saved fix if it is recent, else a fresh fix if one
    /// comes within `timeout`, else the last saved one. Only the app may raise the system's location
    /// question (`mayAsk`): the app explains it first, and a complication asking would raise it with
    /// no explanation, over whatever the wearer is doing. Once location is refused there is no place:
    /// the last fix is where the wearer was, not where they are.
    public static func current(timeout: Duration = .seconds(8), mayAsk: Bool = true) async throws -> Found {
        if let chosen {
            Log.event("place: picked by name")
            return Found(coordinate: chosen.coordinate, isLive: false, at: .now, chosen: chosen)
        }
        let status = CLLocationManager().authorizationStatus
        Log.event("location permission: \(name(status))")
        note(status)
        // Not answered, or Allow Once has run out: the last fix was given for that one use, so it
        // is forgotten, not used again.
        if status == .notDetermined { forgetFix() }
        if let failure = failure(status: status, refused: isRefused, allowedBefore: wasAllowed),
           failure == .off || !mayAsk {
            Log.event("place: none, \(failure)")
            throw failure
        }
        if let saved, let at = savedAt, Date.now.timeIntervalSince(at) < reuseFor {
            Log.event("place: saved fix reused, \(Log.age(of: at))")
            return Found(coordinate: saved, isLive: false, at: at)
        }
        let start = ContinuousClock.now
        switch await Log.stage("Location fix", { await fix(timeout: timeout) }) {
        case let .found(fix):
            save(fix)
            Log.event("place: new fix after \(Log.seconds(since: start))")
            return Found(coordinate: fix, isLive: true, at: .now)
        case .refused:
            note(.denied)
            Log.event("place: none, location refused")
            throw Failure.off
        case .none:
            if CLLocationManager().authorizationStatus == .notDetermined {
                Log.event("place: none, location still not answered after \(Log.seconds(since: start))")
                throw Failure.notAsked
            }
            if let (saved, at) = trustedSaved {
                Log.event("place: no fix in \(Log.seconds(since: start)), saved fix stands in, \(Log.age(of: at))")
                return Found(coordinate: saved, isLive: false, at: at)
            }
            Log.event("place: none, no fix in \(Log.seconds(since: start)) and none saved under an hour old")
            throw Failure.notFound
        }
    }

    private static func name(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not answered"
        case .denied: "refused"
        case .restricted: "restricted"
        case .authorizedAlways: "always"
        case .authorizedWhenInUse: "while using"
        @unknown default: "unknown"
        }
    }

    /// Why a permission gives no place, before any fix is tried; nil when location may be used.
    /// `refused` and `allowedBefore` are what the app or a widget last saw (`isRefused`,
    /// `wasAllowed`): watchOS does not always tell a widget its own permission, and once Allow Once
    /// has run out the status reads as never answered.
    public static func failure(status: CLAuthorizationStatus, refused: Bool, allowedBefore: Bool) -> Failure? {
        switch status {
        case .denied, .restricted: .off
        case .authorizedAlways, .authorizedWhenInUse: nil
        default: refused ? .off : allowedBefore ? .expired : .notAsked
        }
    }

    /// Keeps what the permission says for the face, which may not see it itself.
    public static func note(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            noteRefused(true)
            noteAllowed(false)
        case .authorizedAlways, .authorizedWhenInUse:
            noteRefused(false)
            noteAllowed(true)
        default:
            break
        }
    }

    /// Location was allowed, by Allow Once or Allow While Using App, and not refused since.
    public static var wasAllowed: Bool {
        UserDefaults(suiteName: appGroup)?.bool(forKey: "locationAllowed") ?? false
    }

    static func noteAllowed(_ allowed: Bool) {
        UserDefaults(suiteName: appGroup)?.set(allowed, forKey: "locationAllowed")
    }

    /// Location was refused, as the app or a widget last saw. Kept in the app group because watchOS
    /// does not always tell a widget its own permission: the app sees it, and the face follows.
    public static var isRefused: Bool {
        UserDefaults(suiteName: appGroup)?.bool(forKey: "locationRefused") ?? false
    }

    public static func noteRefused(_ refused: Bool) {
        UserDefaults(suiteName: appGroup)?.set(refused, forKey: "locationRefused")
    }

    /// Forgets the saved fix and any picked place, as a new install would.
    public static func forget() {
        forgetFix()
        let defaults = UserDefaults(suiteName: appGroup)
        for key in ["chosenPlace", "locationRefused", "locationAllowed"] { defaults?.removeObject(forKey: key) }
    }

    private static func forgetFix() {
        let defaults = UserDefaults(suiteName: appGroup)
        for key in ["latitude", "longitude", "fixedAt"] { defaults?.removeObject(forKey: key) }
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

    private enum Fix: Sendable {
        case found(CLLocationCoordinate2D)
        case refused
        case none
    }

    /// Returns at the timeout even when Core Location never answers: a task group would wait for
    /// the location task to end, and on a watch waiting for permission it does not end.
    private static func fix(timeout: Duration) async -> Fix {
        let answered = Mutex(false)
        return await withCheckedContinuation { continuation in
            let answer: @Sendable (Fix) -> Void = { coordinate in
                let first = answered.withLock { done in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(returning: coordinate) }
            }
            let updates = Task {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location { return answer(.found(location.coordinate)) }
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            return answer(.refused)
                        }
                    }
                } catch {}
                answer(.none)
            }
            Task {
                try? await Task.sleep(for: timeout)
                updates.cancel()
                answer(.none)
            }
        }
    }
}
