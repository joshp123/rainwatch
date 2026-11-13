import Foundation

/// The words. One rule everywhere: say what the weather is doing now and how long that lasts,
/// because people open Buienradar as they are about to leave, to know whether they will get wet.
public struct RainCopy: Sendable {
    let forecast: RainForecast

    public init(_ forecast: RainForecast) {
        self.forecast = forecast
    }

    private var spells: [RainSpell] { forecast.spells }
    private var now: RainSpell? { spells.first }
    private var lastsWholeWindow: Bool { spells.count == 1 }

    /// Minutes the current state lasts, nil if it lasts the whole window.
    public var minutesLeft: Int? {
        guard let now, !lastsWholeWindow else { return nil }
        return forecast.minutes(until: now.end)
    }

    /// When the current state ends, for the marker on the line.
    public var change: Date? {
        guard let now, !lastsWholeWindow else { return nil }
        return now.end
    }

    public var isRainingNow: Bool { now?.isRain ?? false }

    /// Rectangular and Smart Stack headline.
    public var headline: String {
        guard forecast.hasRain else { return "No rain forecast" }
        guard let minutes = minutesLeft else { return "\(now?.intensity.phrase ?? "Rain") for 2 hours" }
        let duration = Self.duration(minutes)
        return isRainingNow ? "Rain stops in \(duration)" : "Dry for \(duration)"
    }

    /// The line under the headline: what follows, with clock times.
    public var detail: String? {
        guard forecast.hasRain else { return nil }
        let following = Array(spells.dropFirst())
        guard let next = following.first else {
            return isRainingNow ? peakPhrase : nil
        }
        let ends = next.end < forecast.end ? "–\(Self.clock(next.end))" : ""
        if next.isRain {
            return "\(next.intensity.phrase) \(Self.clock(next.start))\(ends)"
        }
        return ends.isEmpty ? "Dry from \(Self.clock(next.start))" : "Dry \(Self.clock(next.start))\(ends)"
    }

    private var peakPhrase: String? {
        guard let peak = forecast.samples.filter({ $0.date < forecast.end }).max(by: { $0.height < $1.height }) else { return nil }
        return "Heaviest around \(Self.clock(peak.date))"
    }

    /// Circular middle: minutes until the change the dot marks, the way Apple's own Rain
    /// complication counts down ("IN 3M"). The line says whether that change is rain or dry.
    public var circular: (value: String, unit: String?) {
        guard forecast.hasRain else { return ("Dry", nil) }
        guard let minutesLeft else { return ("2H+", nil) }
        return ("\(minutesLeft)", "MIN")
    }

    /// Inline and corner: one short line.
    public var short: String {
        guard forecast.hasRain else { return "No rain" }
        let state = isRainingNow ? "Rain" : "Dry"
        guard let minutes = minutesLeft else { return "\(state) 2h+" }
        return "\(state) \(Self.duration(minutes))"
    }

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter
    }()
}
