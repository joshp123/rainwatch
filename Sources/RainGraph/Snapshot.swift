import Foundation

/// The last Buienradar forecast fetched, kept in the app group so the app and the widget share it.
/// When a fetch fails, the widget shows this one with its original fetch time, so its age keeps
/// growing and it turns stale on schedule instead of looking current.
public struct Snapshot: Codable, Sendable {
    /// After this long, the countdown is withdrawn. watchOS reloads a complication on the active
    /// face about every 15 to 20 minutes; Buienradar updates its forecast every 5.
    #if STALE_TEST
    public static let staleAfter: TimeInterval = 60
    #else
    public static let staleAfter: TimeInterval = 30 * 60
    #endif

    public let samples: [RainSample]
    public let fetched: Date
    public let latitude: Double
    public let longitude: Double

    public init(samples: [RainSample], fetched: Date, latitude: Double, longitude: Double) {
        self.samples = samples
        self.fetched = fetched
        self.latitude = latitude
        self.longitude = longitude
    }

    public var staleAt: Date { fetched.addingTimeInterval(Self.staleAfter) }

    /// A forecast per minute from `now` until the snapshot turns stale.
    public func forecasts(from now: Date) -> [RainForecast] {
        RainForecast.timeline(from: samples, now: now).filter { $0.now < staleAt }
    }

    public static func fetch(latitude: Double, longitude: Double, now: Date = .now) async throws -> Snapshot {
        let samples = try await Buienradar.samples(latitude: latitude, longitude: longitude)
        let snapshot = Snapshot(samples: samples, fetched: now, latitude: latitude, longitude: longitude)
        try? JSONEncoder().encode(snapshot).write(to: file)
        return snapshot
    }

    public static var saved: Snapshot? {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
    }

    private static var file: URL {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Place.appGroup)
            ?? FileManager.default.temporaryDirectory
        return folder.appendingPathComponent("forecast.json")
    }
}

/// One line per widget reload in the app group, so a day on the real watch shows how often watchOS
/// actually refreshed and where the location came from.
public enum ReloadLog {
    public static func record(_ line: String, now: Date = .now) {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Place.appGroup) else { return }
        let file = folder.appendingPathComponent("reloads.log")
        let entry = Data("\(now.ISO8601Format()) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(entry)
            try? handle.close()
        } else {
            try? entry.write(to: file)
        }
    }
}
