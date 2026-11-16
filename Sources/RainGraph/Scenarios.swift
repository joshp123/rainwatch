import Foundation

/// Real KNMI forecasts from BuienWatch's server, read on 16 November 2026 from the run of 00:35 UTC
/// (`server/job.py`, read back with `server/watch_client.py`): rain in mm/h every five minutes from
/// 10 minutes after the run, as a watch sees it after a normal refresh, to where the run stops.
/// Places are the town the cell lies in.
public enum Scenario: String, CaseIterable, Sendable {
    case dry = "Dry, Groningen"
    case showerComing = "Shower coming, Eindhoven"
    case onAndOff = "Rain stops, returns, Hoorn"
    case drizzleStops = "Drizzle stops, returns, Vlissingen"
    case rainingEasing = "Raining, easing off, Den Helder"
    case rainComing = "Rain in 25 min, Alkmaar"
    case rainAllWindow = "Rain all along, Düsseldorf"
    case heavy = "Heavy rain, Osnabrück"

    /// The town in the scenario's name.
    public var place: String {
        rawValue.components(separatedBy: ", ").last ?? "Rotterdam"
    }

    /// The town's latitude and longitude, where the radar page opens.
    public var coordinate: (latitude: Double, longitude: Double) {
        switch self {
        case .dry: (53.22, 6.57)
        case .showerComing: (51.44, 5.48)
        case .onAndOff: (52.64, 5.06)
        case .drizzleStops: (51.44, 3.57)
        case .rainingEasing: (52.96, 4.76)
        case .rainComing: (52.63, 4.75)
        case .rainAllWindow: (51.23, 6.78)
        case .heavy: (52.28, 8.05)
        }
    }

    public static let start: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 1, minute: 45))!
    }()

    /// The run's radar time, 10 minutes before the forecast's start.
    public static let age: TimeInterval = 10 * 60

    public var forecast: RainForecast { forecast(at: Self.start) }

    /// The same forecast moved to start at `start`, to sit under another clock.
    public func forecast(at start: Date) -> RainForecast {
        RainForecast(samples: rates.enumerated().map { index, rate in
            RainSample(date: start.addingTimeInterval(Double(index) * RainForecast.step), rate: rate)
        }, now: start)
    }

    private var rates: [Double] {
        switch self {
        case .dry: Array(repeating: 0, count: 23)
        case .showerComing: [0, 0, 0, 0, 0, 0, 0, 0, 0.13, 0.17, 0.22, 0.14, 0.12, 0.12, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .onAndOff: [0.12, 0.95, 0.36, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.10, 0.12, 0.16, 0.21, 0.17, 0.18, 0.21, 0.18, 0.13]
        case .drizzleStops: [0.12, 0, 0, 0.36, 0.60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .rainingEasing: [3.02, 1.58, 3.16, 5.50, 1.32, 0.40, 0.55, 0.60, 0.48, 0.40, 0.32, 0.29, 0.19, 0.13, 0.13, 0, 0, 0, 0, 0, 0, 0, 0]
        case .rainComing: [0, 0, 0, 0, 0, 0.12, 0.12, 0.24, 0.36, 0.55, 0.66, 0.60, 0.58, 0.42, 0.25, 0.24, 0.20, 0.12, 0.18, 0.12, 0.13, 0.11, 0]
        case .rainAllWindow: [0.36, 0.36, 0.24, 3.31, 1.82, 0.48, 0.79, 0.72, 0.87, 1.20, 1.15, 1.10, 1.05, 1.00, 0.95, 0.72, 0.55, 0.38, 0.24, 0.16, 0.12, 0.14, 0.22]
        case .heavy: [2.40, 5.01, 6.92, 7.24, 2.88, 0.29, 0.24, 0.32, 0.21, 0.28, 0.30, 0.29, 0.19, 0.16, 0, 0, 0.16, 0.12, 0, 0, 0, 0, 0]
        }
    }
}
