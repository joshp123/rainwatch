import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Apple's WeatherKit, outside KNMI's area. The developer account gets 500,000 calls a month for all
/// its apps, and Apple's terms forbid sharing results through a server (`research/europe-sources.md`,
/// section 3), so each refresh makes at most one call, asking for the minute and the hourly forecast
/// together: the minute forecast where Apple has one, the hourly forecast elsewhere.
public enum AppleWeather {
    public struct Result: Sendable {
        public let samples: [RainSample]
        /// When Apple made the forecast.
        public let issued: Date
        /// Until when Apple says the forecast holds.
        public let expires: Date
        public let resolution: RainForecast.Resolution
    }

    /// A minute or an hour is wet when Apple gives it at least an even chance, as the server counts a
    /// KNMI cell wet when at least half of its blend's versions say so. A wet step below 0.1 mm/h is
    /// drawn as 0.1, the lightest rain KNMI's files show.
    static let wetChance = 0.5
    static let lightest = 0.1

    #if canImport(WeatherKit)
    public static func forecast(latitude: Double, longitude: Double, now: Date = .now) async throws -> Result {
        // Rounded to about 1 km, as the location question promises.
        let location = CLLocation(latitude: (latitude * 100).rounded() / 100, longitude: (longitude * 100).rounded() / 100)
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        // Five hours: an hourly forecast is kept for up to an hour, then shows two hours from then.
        let (minute, hourly) = try await WeatherService.shared.weather(
            for: location, including: .minute, .hourly(startDate: hour, endDate: hour.addingTimeInterval(5 * 3600)))
        if let minute, !minute.forecast.isEmpty {
            return Result(samples: fiveMinuteSteps(minute.forecast.map { ($0.date, $0.precipitationChance, mmPerHour($0.precipitationIntensity)) }),
                          issued: minute.metadata.date, expires: minute.metadata.expirationDate, resolution: .fiveMinutes)
        }
        let samples = hourSteps(hourly.forecast.map { ($0.date, $0.precipitationChance, $0.precipitationAmount.converted(to: .millimeters).value) })
        return Result(samples: samples, issued: hourly.metadata.date, expires: hourly.metadata.expirationDate, resolution: .hourly)
    }

    /// Apple gives rain intensity as a speed.
    private static func mmPerHour(_ speed: Measurement<UnitSpeed>) -> Double {
        speed.converted(to: .kilometersPerHour).value * 1_000_000
    }
    #endif

    /// Apple's hours in the app's five-minute steps: an hour is wet when Apple gives it at least an
    /// even chance, at its amount in mm/h, the same all hour.
    static func hourSteps(_ hours: [(date: Date, chance: Double, amount: Double)]) -> [RainSample] {
        hours.flatMap { hour in
            let rate = hour.chance >= wetChance && hour.amount > 0 ? max(lightest, hour.amount) : 0
            return (0..<12).map { RainSample(date: hour.date.addingTimeInterval(Double($0) * RainForecast.step), rate: rate) }
        }
    }

    /// Apple's minutes in the app's five-minute steps: a step is wet when most of its minutes are,
    /// at their average intensity.
    static func fiveMinuteSteps(_ minutes: [(date: Date, chance: Double, rate: Double)]) -> [RainSample] {
        stride(from: 0, to: minutes.count, by: 5).map { first in
            // The last step may be short: Apple's hour ends on its 61st minute.
            let block = minutes[first..<min(first + 5, minutes.count)]
            let wet = block.filter { $0.chance >= wetChance && $0.rate > 0 }
            let rate = wet.count * 2 > block.count ? max(lightest, wet.map(\.rate).reduce(0, +) / Double(wet.count)) : 0
            return RainSample(date: block.first!.date, rate: rate)
        }
    }
}

/// Apple's Weather mark and the link to its legal page, which its terms require wherever its data
/// is shown. Fetched once and kept in the app group: the mark changes rarely.
public struct AppleWeatherCredit: Codable, Sendable {
    public let legalPage: URL
    public let legalText: String

    /// Where `legalPageURL` led on 17 November 2026, for when the attribution hasn't loaded yet.
    public static let fallbackLegalPage = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    public let markFile: URL

    public static var saved: AppleWeatherCredit? {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(AppleWeatherCredit.self, from: $0) }
            .flatMap { FileManager.default.fileExists(atPath: $0.markFile.path) ? $0 : nil }
    }

    #if canImport(WeatherKit)
    public static func load() async -> AppleWeatherCredit? {
        if let saved { return saved }
        guard let attribution = try? await WeatherService.shared.attribution,
              let (mark, _) = try? await URLSession.shared.data(from: attribution.combinedMarkDarkURL) else { return nil }
        let markFile = file.deletingLastPathComponent().appendingPathComponent("apple-weather-mark.png")
        guard (try? mark.write(to: markFile)) != nil else { return nil }
        let loaded = AppleWeatherCredit(legalPage: attribution.legalPageURL, legalText: attribution.legalAttributionText, markFile: markFile)
        try? JSONEncoder().encode(loaded).write(to: file)
        return loaded
    }
    #endif

    private static var file: URL {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Place.appGroup)
            ?? FileManager.default.temporaryDirectory
        return folder.appendingPathComponent("Library/apple-weather.json")
    }
}
