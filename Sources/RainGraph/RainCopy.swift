import Foundation

/// The words. One rule everywhere: say what the weather is doing now and how long that lasts,
/// because people look as they are about to leave, to know whether they will get wet. Nothing is
/// claimed beyond where the forecast stops.
public struct RainCopy: Sendable {
    let forecast: RainForecast

    public init(_ forecast: RainForecast) {
        self.forecast = forecast
    }

    private var spells: [RainSpell] { forecast.spells }
    private var now: RainSpell? { spells.first }
    private var lastsWholeForecast: Bool { spells.count == 1 }
    private var hourly: Bool { forecast.resolution == .hourly }

    /// How far the forecast reaches, said no further than it does: "2+ hours" only when it covers
    /// two hours. A KNMI run covers two hours from its radar time, so a forecast a few minutes old
    /// says "1+ hours".
    private var reach: (words: String, value: String, unit: String) {
        let minutes = forecast.minutesKnown
        if minutes >= 120 { return ("2+ hours", "2+", "HRS") }
        if minutes >= 60 { return ("1+ hours", "1+", "HRS") }
        let five = max(5, minutes / 5 * 5)
        return ("\(five)+ min", "\(five)+", "MIN")
    }

    /// Minutes the current state lasts, nil if it lasts as far as the forecast reaches.
    public var minutesLeft: Int? {
        guard let now, !lastsWholeForecast else { return nil }
        return forecast.minutes(until: now.end)
    }

    /// When the current state ends, for the marker on the line.
    public var change: Date? {
        guard let now, !lastsWholeForecast else { return nil }
        return now.end
    }

    public var isRainingNow: Bool { now?.isRain ?? false }

    /// Rectangular and Smart Stack headline. Minutes under an hour, the clock time beyond, so it
    /// always fits on one line. An hourly forecast knows only which hour rain falls in, so it
    /// always names the hour.
    public var headline: String {
        guard forecast.hasRain else { return "Dry for \(reach.words)" }
        guard let minutes = minutesLeft, let change else { return "\(now?.intensity.phrase ?? "Rain") for \(reach.words)" }
        let state = isRainingNow ? "Rain" : "Dry"
        if minutes >= 60 || hourly { return "\(state) until \(Self.clock(change))" }
        return isRainingNow ? "Rain stops in \(minutes) min" : "Dry for \(minutes) min"
    }

    /// The line under the headline: what follows, with clock times. For an hourly forecast it says
    /// so instead, because its times are whole hours, not when rain starts.
    public var detail: String? {
        if hourly { return Self.hourlyLabel }
        guard forecast.hasRain else { return nil }
        let following = Array(spells.dropFirst())
        guard let next = following.first else {
            return isRainingNow ? peakPhrase : nil
        }
        let ends = next.end < forecast.forecastEnd ? "–\(Self.clock(next.end))" : ""
        if next.isRain {
            // Rain that lasts as far as the forecast reaches has no end to give.
            return ends.isEmpty ? "\(next.intensity.phrase) from \(Self.clock(next.start))"
                : "\(next.intensity.phrase) \(Self.clock(next.start))\(ends)"
        }
        // "Rain until 15:10" already says when it turns dry; say how hard it rains instead.
        if ends.isEmpty, (minutesLeft ?? 0) >= 60 { return peakPhrase }
        return ends.isEmpty ? "Dry from \(Self.clock(next.start))" : "Dry \(Self.clock(next.start))\(ends)"
    }

    public static let hourlyLabel = "Hourly forecast"

    private var peakPhrase: String? {
        guard let peak = forecast.samples.filter({ $0.date < forecast.forecastEnd }).max(by: { $0.height < $1.height }) else { return nil }
        return "Heaviest around \(Self.clock(peak.date))"
    }

    /// Circular middle, read top to bottom as one phrase, always about rain, as the blue line is:
    /// "IN 30 MIN" until rain arrives when it is dry, "FOR 5 MIN" while it lasts when it is raining.
    /// The same three words can then never mean opposite things. An hour or more reads "1+ HRS",
    /// so the number never needs three digits. Dry says how long under it, "2+ HRS": "FOR 2+ HRS"
    /// is wider than the disc at a readable size. An hourly forecast's change is at the next whole
    /// hour, so it reads "<1 HR" rather than a count of minutes it doesn't know.
    public var circular: (lead: String?, value: String, unit: String?) {
        guard forecast.hasRain else { return (nil, "Dry", "\(reach.value) \(reach.unit)") }
        guard let minutesLeft else { return ("FOR", reach.value, reach.unit) }
        let lead = isRainingNow ? "FOR" : "IN"
        if minutesLeft >= 60 { return (lead, "1+", "HRS") }
        return hourly ? (lead, "<1", "HR") : (lead, "\(minutesLeft)", "MIN")
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

    /// The wearer's own time zone and clock format.
    static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("jjmm")
        return formatter
    }()
}
