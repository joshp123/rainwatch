import CoreLocation
import Foundation

/// Why there is no forecast to show. The app and the watch face read their words from here, so the
/// two always say the same thing about the same problem. STATES.md has the whole table.
public enum Problem: Equatable, Sendable {
    /// Location was never answered, and no place is picked.
    case locationNotAsked
    /// Location was allowed, and must be asked again: Allow Once has run out. No place is picked.
    case locationExpired
    /// Location is refused or turned off, and no place is picked.
    case locationOff
    /// Location is allowed, but the watch has had no fix for an hour.
    case locationNotFound
    /// The forecast could not be fetched, and none is saved for this place.
    case forecastUnavailable
    /// Apple has no forecast for this place.
    case noForecastHere
    /// The newest forecast is too old to count down from.
    case forecastTooOld(since: Date)

    public init(_ failure: Place.Failure) {
        switch failure {
        case .notAsked: self = .locationNotAsked
        case .expired: self = .locationExpired
        case .off: self = .locationOff
        case .notFound: self = .locationNotFound
        }
    }

    public enum Action: Sendable {
        case tryAgain, choosePlace
        /// Continue, which opens the system's location question.
        case allowLocation
    }

    /// The app's title for the problem.
    public var title: String {
        switch self {
        case .locationNotAsked: localized("Location Not Set")
        case .locationExpired: localized("Permission Expired")
        case .locationOff: localized("Location Off")
        case .locationNotFound: localized("Location Not Found")
        case .forecastUnavailable: localized("Forecast Unavailable")
        case .noForecastHere: localized("No Forecast Here")
        case .forecastTooOld: localized("No Recent Forecast")
        }
    }

    /// The one line the app adds under its title, where there is something to add.
    public var detail: String? {
        switch self {
        // watchOS lets no app open Settings, so the way there is spelled out.
        case .locationOff: localized("Open Settings, then Privacy & Security > Location Services > \(Bundle.main.displayName) > While Using the App.")
        case .locationExpired: localized("To keep your watch face up to date, choose Allow While Using App.")
        case let .forecastTooOld(since): localized("Last forecast \(RainCopy.clock(since))")
        default: nil
        }
    }

    /// The app's buttons, in order. The first is what a tap on the face is for.
    public var actions: [Action] {
        switch self {
        case .locationNotAsked: []
        case .locationExpired: [.allowLocation]
        case .locationOff: [.choosePlace]
        case .locationNotFound, .noForecastHere: [.tryAgain, .choosePlace]
        case .forecastUnavailable, .forecastTooOld: [.tryAgain]
        }
    }

    public var symbol: String {
        switch self {
        case .locationNotAsked, .locationExpired, .locationOff, .locationNotFound: "location.slash"
        case .forecastUnavailable: "exclamationmark.icloud"
        case .noForecastHere: "icloud.slash"
        case .forecastTooOld: "clock.badge.exclamationmark"
        }
    }

    /// The face's large slot, first line: the app's title as a sentence.
    public var faceHeadline: String {
        let words = title.split(separator: " ")
        return ([String(words[0])] + words.dropFirst().map { $0.lowercased() }).joined(separator: " ")
    }

    /// The face's large slot, second line: the forecast's time where that is the news, else what a
    /// tap does.
    public var faceHint: String {
        if let detail, case .forecastTooOld = self { return detail }
        if self == .locationOff { return localized("Tap for steps") }
        switch actions.first {
        case .tryAgain: return localized("Tap to try again")
        case .choosePlace: return localized("Tap to choose a place")
        case .allowLocation: return localized("Tap to allow location")
        case nil: return localized("Tap to set up")
        }
    }

    /// The face's circle says "No" over this: what is missing, a place or the data.
    public var circleWord: String {
        switch self {
        case .locationNotAsked, .locationExpired, .locationOff, .locationNotFound: localized("PLACE")
        case .forecastUnavailable, .noForecastHere, .forecastTooOld: localized("DATA")
        }
    }

    #if DEBUG
    /// The problems by the names the app's `-failure` option takes, for the face as well.
    public static func named(_ name: String, launched: Date) -> Problem? {
        switch name {
        case "notAsked": .locationNotAsked
        case "expired": .locationExpired
        case "noLocation": .locationOff
        case "locationNotFound": .locationNotFound
        case "offline": .forecastUnavailable
        case "noForecast": .noForecastHere
        case "stale": .forecastTooOld(since: Date(timeIntervalSince1970: ((launched.timeIntervalSince1970 - 75 * 60) / 300).rounded(.down) * 300))
        default: nil
        }
    }
    #endif
}

/// What RainWatch shows at one moment: a forecast, or the reason there is none. Never both, and
/// never a forecast that breaks one of the rules in STATES.md.
public enum Situation: Sendable {
    /// `updateFailed`: the last fetch failed, so this is the saved forecast, cut to now.
    case forecast(RainForecast, from: Snapshot, updateFailed: Bool)
    case problem(Problem)

    /// How a fetch for a place ended.
    public enum Fetch: Sendable {
        case fetched(Snapshot)
        /// The server or the network could not be reached.
        case unreachable
        /// Apple refused, or has no forecast for the place.
        case refused
    }

    /// The situation after a fetch for a place. A saved forecast stands in for a failed fetch only
    /// if it is for this place and under an hour old, and it is cut to `now`, so its countdown is
    /// today's, not the one from when it was fetched.
    public static func after(_ fetch: Fetch, latitude: Double, longitude: Double, saved: Snapshot?, now: Date) -> Situation {
        switch fetch {
        case let .fetched(snapshot):
            if let forecast = snapshot.forecast(at: now) { return .forecast(forecast, from: snapshot, updateFailed: false) }
            return .problem(snapshot.source == .knmi ? .forecastTooOld(since: snapshot.issued) : .noForecastHere)
        case .refused:
            return .problem(.noForecastHere)
        case .unreachable:
            guard let saved, saved.isNear(latitude: latitude, longitude: longitude) else { return .problem(.forecastUnavailable) }
            if let forecast = saved.forecast(at: now) { return .forecast(forecast, from: saved, updateFailed: true) }
            return .problem(.forecastTooOld(since: saved.issued))
        }
    }

    /// The face's schedule from `now`: a forecast for every minute while the snapshot may be shown,
    /// then the problem that takes its place. `placeExpires` is when a fix stops being trusted (an
    /// hour after it was taken); the face then says Location Not Found. A picked place does not
    /// expire.
    public static func schedule(_ snapshot: Snapshot, now: Date, placeExpires: Date?) -> [(date: Date, situation: Situation)] {
        var entries: [(date: Date, situation: Situation)] = snapshot.forecasts(from: now).map {
            ($0.now, .forecast($0, from: snapshot, updateFailed: false))
        }
        let dataEnds = max(min(snapshot.staleAt, entries.last.map { $0.date.addingTimeInterval(60) } ?? now), now)
        if let placeExpires, placeExpires < dataEnds {
            entries.removeAll { $0.date >= placeExpires }
            entries.append((max(placeExpires, now), .problem(.locationNotFound)))
        } else {
            entries.append((dataEnds, .problem(snapshot.source == .knmi ? .forecastTooOld(since: snapshot.issued) : .noForecastHere)))
        }
        return entries
    }
}

extension Snapshot {
    /// From this age the forecast says its time instead of what comes next.
    public static let oldAfter: TimeInterval = 20 * 60

    public func isOld(at moment: Date) -> Bool {
        moment.timeIntervalSince(issued) >= Self.oldAfter
    }

    /// The same place for a forecast: within 1.5 km, about one KNMI cell either way.
    public func isNear(latitude: Double, longitude: Double) -> Bool {
        CLLocation(latitude: self.latitude, longitude: self.longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= 1500
    }
}
