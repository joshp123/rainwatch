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

    /// How far the forecast reaches, said no further than it does: "over 2 hours" only when it
    /// covers two hours. A KNMI run covers two hours from its radar time, so a forecast a few minutes
    /// old says "over an hour".
    private var reach: (words: String, value: String, unit: String) {
        let minutes = forecast.minutesKnown
        if minutes >= 120 { return (localized("over 2 hours"), "2+", localized("HRS")) }
        if minutes >= 60 { return (localized("over an hour"), "1+", localized("HRS")) }
        let five = max(5, minutes / 5 * 5)
        return (localized("over \(five) min"), "\(five)+", localized("MIN"))
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
        guard forecast.hasRain else { return localized("Dry for \(reach.words)") }
        // Only "dry" or "rain", so the longest headline still fits one line; the graph and the
        // line under it say how hard.
        guard let minutes = minutesLeft, let change else { return localized("Rain for \(reach.words)") }
        if minutes >= 60 || hourly {
            return isRainingNow ? localized("Rain until \(Self.clock(change))") : localized("Dry until \(Self.clock(change))")
        }
        return isRainingNow ? localized("Rain stops in \(minutes) min") : localized("Dry for \(minutes) min")
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
            return ends.isEmpty ? localized("\(next.intensity.phrase) from \(Self.clock(next.start))")
                : "\(next.intensity.phrase) \(Self.clock(next.start))\(ends)"
        }
        // "Rain until 15:10" already says when it turns dry; say how hard it rains instead.
        if ends.isEmpty, (minutesLeft ?? 0) >= 60 { return peakPhrase }
        return ends.isEmpty ? localized("Dry from \(Self.clock(next.start))") : "\(localized("Dry")) \(Self.clock(next.start))\(ends)"
    }

    public static var hourlyLabel: String { localized("Hourly forecast") }

    /// True when the line under the headline is about rain. Blue means rain, so only then is the
    /// line blue; a line about a dry spell is grey.
    public var detailIsAboutRain: Bool {
        guard !hourly, forecast.hasRain else { return false }
        guard let next = spells.dropFirst().first else { return isRainingNow }
        if next.isRain { return true }
        return next.end >= forecast.forecastEnd && (minutesLeft ?? 0) >= 60
    }

    private var peakPhrase: String? {
        guard let peak = forecast.samples.filter({ $0.date < forecast.forecastEnd }).max(by: { $0.height < $1.height }) else { return nil }
        return localized("Heaviest around \(Self.clock(peak.date))")
    }

    /// Circular middle, read top to bottom as one phrase, always about rain, as the blue line is:
    /// "IN 30 MIN" until rain arrives when it is dry, "FOR 5 MIN" while it lasts when it is raining.
    /// An hour or more reads "1+ HRS", so the number never needs three digits. With no rain in
    /// sight there is no arc and the two lines sit as one block: "Dry", "2+ HRS". An hourly
    /// forecast's change is at the next whole hour, so it reads "<1 HR" rather than a count of
    /// minutes it doesn't know.
    public var circular: (lead: String?, value: String, unit: String?) {
        guard forecast.hasRain else { return (nil, localized("Dry"), "\(reach.value) \(reach.unit)") }
        let lead = isRainingNow ? localized("FOR") : localized("IN")
        guard let minutesLeft else { return (lead, reach.value, reach.unit) }
        if minutesLeft >= 60 { return (lead, "1+", localized("HRS")) }
        return hourly ? (lead, "<1", localized("HR")) : (lead, "\(minutesLeft)", localized("MIN"))
    }

    /// Inline and corner: the headline itself, so every family says the same thing.
    public var short: String { headline }

    /// What VoiceOver reads for any family: the headline, then what follows.
    public var spoken: String {
        [headline, detail].compactMap { $0 }.joined(separator: ". ")
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
