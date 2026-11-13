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

    /// Rectangular and Smart Stack headline. Minutes under an hour, the clock time beyond, so it
    /// always fits on one line.
    public var headline: String {
        guard forecast.hasRain else { return "Dry for 2+ hours" }
        guard let minutes = minutesLeft, let change else { return "\(now?.intensity.phrase ?? "Rain") for 2+ hours" }
        let state = isRainingNow ? "Rain" : "Dry"
        if minutes >= 60 { return "\(state) until \(Self.clock(change))" }
        return isRainingNow ? "Rain stops in \(minutes) min" : "Dry for \(minutes) min"
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
        // "Rain until 15:10" already says when it turns dry; say how hard it rains instead.
        if ends.isEmpty, (minutesLeft ?? 0) >= 60 { return peakPhrase }
        return ends.isEmpty ? "Dry from \(Self.clock(next.start))" : "Dry \(Self.clock(next.start))\(ends)"
    }

    private var peakPhrase: String? {
        guard let peak = forecast.samples.filter({ $0.date < forecast.end }).max(by: { $0.height < $1.height }) else { return nil }
        return "Heaviest around \(Self.clock(peak.date))"
    }

    /// Circular middle, read top to bottom as one phrase: "IN 30 MIN" to the change at the dot, or
    /// "FOR 2+ HRS" when the weather stays the same for the whole window. The line says what changes.
    public var circular: (lead: String?, value: String, unit: String?) {
        guard forecast.hasRain else { return (nil, "Dry", "FOR 2+ HRS") }
        guard let minutesLeft else { return ("FOR", "2+", "HRS") }
        return ("IN", "\(minutesLeft)", "MIN")
    }

    /// Inline and corner: the headline itself, so every family says the same thing.
    public var short: String { headline }

    /// What VoiceOver reads for any family: the headline, then what follows.
    public var spoken: String {
        [headline, detail].compactMap { $0 }.joined(separator: ". ")
    }

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    public static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter
    }()
}
