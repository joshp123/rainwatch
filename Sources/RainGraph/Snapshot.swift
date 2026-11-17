import Foundation

/// The last forecast fetched, kept in the app group so the app and the widget share it. Its age is
/// the age of the data (KNMI's radar time, or when Apple made its forecast), never when the watch
/// fetched it, so it turns stale on schedule even when every fetch succeeds.
public struct Snapshot: Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// KNMI's forecast, from BuienWatch's server.
        case knmi
        /// Apple's minute-by-minute forecast for the next hour.
        case appleMinute
        /// Apple's hourly forecast, where it has no minute forecast.
        case appleHourly

        public var isApple: Bool { self != .knmi }

        /// Who made the forecast, for credits and error messages.
        public var name: String { self == .knmi ? "KNMI" : "Apple Weather" }
    }

    /// After this long, the countdown is withdrawn. On Josh's watch the widget was reloaded 30
    /// minutes apart, so a 30-minute limit blanked the face in normal use; from 20 minutes the
    /// rectangular slot says how old the forecast is. An hourly forecast is fetched at most once an
    /// hour, so it may be two hours old before it turns stale.
    #if STALE_TEST
    public static let staleAfter: TimeInterval = 60
    #else
    public static let staleAfter: TimeInterval = 60 * 60
    #endif

    public let samples: [RainSample]
    public let source: Source
    /// When the data was made: KNMI's radar time, or Apple's forecast time.
    public let issued: Date
    /// When the watch fetched it, to reuse it rather than fetch again moments later.
    public let fetched: Date
    /// Until when Apple says its forecast holds.
    public let expires: Date?
    public let latitude: Double
    public let longitude: Double
    /// Requests this fetch made, for the reload log.
    public var requests = 0

    enum CodingKeys: String, CodingKey {
        case samples, source, issued, fetched, expires, latitude, longitude
    }

    public init(samples: [RainSample], source: Source, issued: Date, fetched: Date, expires: Date? = nil,
                latitude: Double, longitude: Double) {
        self.samples = samples
        self.source = source
        self.issued = issued
        self.fetched = fetched
        self.expires = expires
        self.latitude = latitude
        self.longitude = longitude
    }

    public var staleAt: Date {
        issued.addingTimeInterval(source == .appleHourly ? 2 * Self.staleAfter : Self.staleAfter)
    }

    public var resolution: RainForecast.Resolution { source == .appleHourly ? .hourly : .fiveMinutes }

    /// What is left of the forecast at `moment`, if it is not stale.
    public func forecast(at moment: Date) -> RainForecast? {
        guard moment < staleAt else { return nil }
        return RainForecast.at(moment, from: samples, resolution: resolution)
    }

    /// A forecast per minute from `now` until the snapshot turns stale or its data runs out.
    public func forecasts(from now: Date) -> [RainForecast] {
        RainForecast.timeline(from: samples, now: now, resolution: resolution).filter { $0.now < staleAt }
    }

    public enum Failure: Error {
        /// The forecast could not be reached.
        case offline(Source)
        /// Apple refused the call, or had no forecast here: shown as no forecast, never as dry.
        case refused
    }

    /// The forecast for a place: KNMI's inside its area, Apple's elsewhere. A forecast fetched for
    /// the same place moments ago is reused, so the complications on one face, which reload
    /// together, share one fetch; Apple's hourly forecast is reused until it expires, and at least
    /// an hour.
    public static func fetch(latitude: Double, longitude: Double, now: Date = .now) async throws -> Snapshot {
        if let saved, saved.isFor(latitude: latitude, longitude: longitude), saved.canBeReused(at: now) {
            return saved
        }
        var snapshot = try await fetchNew(latitude: latitude, longitude: longitude, now: now)
        try? JSONEncoder().encode(snapshot).write(to: file)
        snapshot.requests = max(snapshot.requests, 1)
        return snapshot
    }

    /// Close enough to reuse a fetch made moments ago: about half a kilometre.
    private func isFor(latitude: Double, longitude: Double) -> Bool {
        abs(self.latitude - latitude) < 0.005 && abs(self.longitude - longitude) < 0.005
    }

    private func canBeReused(at now: Date) -> Bool {
        let age = now.timeIntervalSince(fetched)
        guard age >= 0, now < staleAt else { return false }
        if source == .appleHourly { return now < max(expires ?? fetched, fetched.addingTimeInterval(3600)) }
        return age < 2 * 60
    }

    private static func fetchNew(latitude: Double, longitude: Double, now: Date) async throws -> Snapshot {
        if let cell = KNMI.cell(latitude: latitude, longitude: longitude) {
            let latest: KNMI.Latest
            do {
                latest = try await KNMI.latest()
            } catch {
                throw Failure.offline(.knmi)
            }
            // The run is the one already saved: its values for this place are already here.
            if let saved, saved.source == .knmi, saved.issued == latest.run,
               KNMI.cell(latitude: saved.latitude, longitude: saved.longitude) == cell {
                var same = Snapshot(samples: saved.samples, source: .knmi, issued: latest.run, fetched: now,
                                    latitude: latitude, longitude: longitude)
                same.requests = 1
                return same
            }
            let samples: [RainSample]?
            do {
                samples = try await KNMI.samples(at: cell, in: latest)
            } catch {
                throw Failure.offline(.knmi)
            }
            // Where KNMI's radars can't see this place now, Apple's forecast is used instead.
            if let samples, RainForecast.at(now, from: samples) != nil {
                var snapshot = Snapshot(samples: samples, source: .knmi, issued: latest.run, fetched: now,
                                        latitude: latitude, longitude: longitude)
                snapshot.requests = latest.squares[latest.square(holding: cell)] > 0 ? 2 : 1
                return snapshot
            }
        }
        #if canImport(WeatherKit)
        let apple: AppleWeather.Result
        do {
            apple = try await AppleWeather.forecast(latitude: latitude, longitude: longitude, now: now)
        } catch is URLError {
            throw Failure.offline(.appleMinute)
        } catch {
            throw Failure.refused
        }
        return Snapshot(samples: apple.samples, source: apple.resolution == .hourly ? .appleHourly : .appleMinute,
                        issued: apple.issued, fetched: now, expires: apple.expires, latitude: latitude, longitude: longitude)
        #else
        throw Failure.refused
        #endif
    }

    public static var saved: Snapshot? {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
    }

    public static func forget() {
        try? FileManager.default.removeItem(at: file)
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
        // In Library, the only part of the container a Mac may copy from a real watch.
        let file = folder.appendingPathComponent("Library/reloads.log")
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
