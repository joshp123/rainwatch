import Foundation

/// Fixed forecasts for the mock-ups, as Buienradar graph heights (0–100) every five minutes from 13:05.
public enum Scenario: String, CaseIterable, Sendable {
    case showerComing = "Shower coming"
    case stoppingSoon = "Raining, stops, returns"
    case downpour = "Heavy downpour coming"
    case dry = "Dry"
    case liveRotterdam = "Live Rotterdam, 13 Nov 13:05"

    public static let start: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 13, minute: 5))!
    }()

    public var forecast: RainForecast {
        RainForecast(start: Self.start, heights: heights + Array(repeating: 0, count: max(0, 25 - heights.count)))
    }

    private var heights: [Double] {
        switch self {
        case .showerComing:
            [0, 0, 0, 0, 0, 6, 18, 34, 52, 58, 46, 30, 16, 6, 0, 0, 0, 0, 0, 4, 10, 8]
        case .stoppingSoon:
            [38, 44, 36, 24, 14, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 22, 30, 20, 8]
        case .downpour:
            [0, 0, 0, 0, 0, 0, 0, 0, 10, 30, 62, 88, 96, 80, 50, 26, 12, 4]
        case .dry:
            []
        case .liveRotterdam:
            // graphdata.buienradar.nl RainNL3Hour, 51.92 N 4.48 E, fetched 13 Nov 2026 13:05.
            [0, 8, 40, 18, 2]
        }
    }
}
