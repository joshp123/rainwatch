import Foundation

/// Real Buienradar nowcasts fetched on 13 November 2026 at 13:30 (graph heights, 0–100, every five
/// minutes), from `graphdata.buienradar.nl` RainNL3Hour and RainEU3Hour. Places are the nearest town.
public enum Scenario: String, CaseIterable, Sendable {
    case dry = "Dry"
    case showerComing = "Shower coming, Boxtel"
    case onAndOff = "Showers on and off, Doetinchem"
    case drizzleStops = "Drizzle stops, returns, Tholen"
    case rainingEasing = "Raining, easing off, Glasgow"
    case rainComing = "Rain in 10 min, Oslo"
    case rainAllWindow = "Rain all two hours, Madrid"

    /// The town in the scenario's name.
    public var place: String {
        rawValue.components(separatedBy: ", ").last.map { $0 == "Dry" ? "Rotterdam" : $0 } ?? "Rotterdam"
    }

    public static let start: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 13, minute: 30))!
    }()

    public var forecast: RainForecast { forecast(at: Self.start) }

    /// The same forecast moved to start at `start`, to sit under another clock.
    public func forecast(at start: Date) -> RainForecast {
        RainForecast(start: start, heights: heights + Array(repeating: 0, count: max(0, 25 - heights.count)))
    }

    private var heights: [Double] {
        switch self {
        case .dry: []
        case .showerComing: [0, 0, 0, 0, 0, 0, 6, 26, 20, 14, 4]
        case .onAndOff: [0, 0, 0, 0, 0, 2, 10, 26, 32, 40, 12, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2]
        case .drizzleStops: [6, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 2, 10, 8, 6, 2]
        case .rainingEasing: [22, 22, 6, 2, 6, 30, 24, 14, 14, 16, 10, 10, 2, 2, 4, 2, 0, 2, 0, 2]
        case .rainComing: [0, 0, 16, 40, 41, 42, 38, 32, 36, 20, 12, 4, 2]
        case .rainAllWindow: [43, 50, 44, 28, 22, 38, 40, 47, 49, 59, 49, 2, 6, 18, 46, 43, 2, 6, 4, 0, 2, 2, 4, 2, 2]
        }
    }
}
