import Foundation

/// One five-minute step of a rain forecast.
public struct RainSample: Hashable, Sendable, Codable {
    public var date: Date
    /// Rain in mm/h: 0 is dry, nil is no data. No data is never drawn or worded as dry.
    public var rate: Double?

    public init(date: Date, rate: Double?) {
        self.date = date
        self.rate = rate
    }

    /// Height on the graph, 0–100, on Buienradar's scale (`RainScale`).
    public var height: Double { RainScale.height(rate ?? 0) }

    /// Any measurable rain counts: Josh wants to know if he gets wet at all.
    public var isRain: Bool { (rate ?? 0) > 0 }
}

/// Buienradar's graph scale, which the app's lines, words and scale marks were designed on. Its
/// graph feed gives the height as 20 per mm/h up to 2 mm/h, then 3.75 per mm/h: every one of the
/// 34 distinct pairs of `dataValue` and `percentageValue` in `research/live-data` fits
/// floor(height). Full height is 18 mm/h; Light 25 is 1.25 mm/h, Moderate 50 is 4.7, Heavy 75 is 11.3.
public enum RainScale {
    public static func height(_ rate: Double) -> Double {
        guard rate > 0 else { return 0 }
        return rate <= 2 ? 20 * rate : min(100, 40 + (rate - 2) * 3.75)
    }

    public static func rate(height: Double) -> Double {
        guard height > 0 else { return 0 }
        return height <= 40 ? height / 20 : 2 + (height - 40) / 3.75
    }
}

/// How hard it rains, on Buienradar's graph lines (Light 25, Moderate 50, Heavy 75).
public enum Intensity: Int, Comparable, Sendable {
    case drizzle, light, moderate, heavy

    public init(height: Double) {
        switch height {
        case 75...: self = .heavy
        case 50...: self = .moderate
        case 25...: self = .light
        default: self = .drizzle
        }
    }

    public static func < (a: Intensity, b: Intensity) -> Bool { a.rawValue < b.rawValue }

    /// Sentence start, as in "Light rain 14:10–14:45".
    public var phrase: String {
        switch self {
        case .drizzle: localized("Drizzle")
        case .light: localized("Light rain")
        case .moderate: localized("Rain")
        case .heavy: localized("Heavy rain")
        }
    }
}

/// A stretch of the forecast that is all dry or all wet.
public struct RainSpell: Equatable, Sendable {
    public var isRain: Bool
    public var start: Date
    public var end: Date
    public var peak: Double

    public var intensity: Intensity { Intensity(height: peak) }
}

/// The rain at one place from now, for up to two hours. The first sample holds now. The forecast
/// may stop before the two hours are up: a KNMI run covers two hours from its radar time, so it has
/// less left the older it is, and Apple's minute forecast covers one hour. Views draw it to where it
/// stops and the words claim nothing beyond it.
public struct RainForecast: Sendable {
    /// How finely the forecast knows when rain starts and stops.
    public enum Resolution: String, Codable, Sendable {
        /// KNMI's forecast, or Apple's minute forecast in five-minute steps.
        case fiveMinutes
        /// Apple's hourly forecast: rain is known per clock hour, not to the minute.
        case hourly
    }

    public static let step: TimeInterval = 5 * 60
    public static let window: TimeInterval = 2 * 60 * 60
    /// Buienradar's own scale lines (`borders`): Light, Moderate, Heavy.
    public static let scaleLines: [Double] = [25, 50, 75]

    public var samples: [RainSample]
    /// The moment the forecast is shown. Durations count from here, not from the first sample,
    /// which is the five-minute step that holds now.
    public var now: Date
    public var resolution: Resolution
    /// The length of the time axis: two hours, or longer for the radar's strip.
    public var span: TimeInterval

    public init(samples: [RainSample], now: Date? = nil, resolution: Resolution = .fiveMinutes, span: TimeInterval = window) {
        self.samples = samples
        self.now = now ?? samples.first?.date ?? .now
        self.resolution = resolution
        self.span = span
    }

    public var start: Date { samples.first?.date ?? now }
    /// The end of the time axis.
    public var end: Date { start.addingTimeInterval(span) }
    /// Where the forecast stops: the end of the axis, or the last step's time when the data runs out
    /// sooner. A KNMI run's last frame is at 120 minutes, so its forecast ends there.
    public var forecastEnd: Date {
        min(end, samples.last?.date ?? start)
    }

    /// Position of `date` along the axis, 0 at its start and 1 at its end.
    public func position(of date: Date) -> Double {
        date.timeIntervalSince(start) / span
    }

    /// Whole minutes the forecast reaches beyond now.
    public var minutesKnown: Int { max(0, Int(forecastEnd.timeIntervalSince(now) / 60)) }

    /// Dry gaps shorter than this between two wet stretches can't be used to go out, so the
    /// words treat them as wet. The line still shows them.
    public static let shortestUsefulGap: TimeInterval = 10 * 60

    /// The forecast cut into dry and wet stretches. Each sample covers the five minutes after it, up
    /// to where the forecast stops.
    public var spells: [RainSpell] {
        var spells = rawSpells
        var index = 1
        while index < spells.count - 1 {
            let gap = spells[index]
            if !gap.isRain, gap.end.timeIntervalSince(gap.start) < Self.shortestUsefulGap {
                let merged = RainSpell(isRain: true, start: spells[index - 1].start, end: spells[index + 1].end,
                                       peak: max(spells[index - 1].peak, spells[index + 1].peak))
                spells.replaceSubrange(index - 1...index + 1, with: [merged])
                index = max(1, index - 1)
            } else {
                index += 1
            }
        }
        return spells
    }

    private var rawSpells: [RainSpell] {
        let stop = forecastEnd
        var spells: [RainSpell] = []
        for sample in samples where sample.date < stop {
            let sampleEnd = min(sample.date.addingTimeInterval(Self.step), stop)
            if var last = spells.last, last.isRain == sample.isRain {
                last.end = sampleEnd
                last.peak = max(last.peak, sample.height)
                spells[spells.count - 1] = last
            } else {
                spells.append(RainSpell(isRain: sample.isRain, start: sample.date, end: sampleEnd, peak: sample.height))
            }
        }
        return spells
    }

    public var hasRain: Bool { samples.contains { $0.isRain && $0.date < forecastEnd } }

    public func minutes(until date: Date) -> Int {
        max(1, Int((date.timeIntervalSince(now) / 60).rounded()))
    }
}

extension RainForecast {
    /// One forecast per minute from `now`, each showing what is left of the samples from that
    /// minute, so a widget counts down exactly between the system's reloads.
    public static func timeline(from samples: [RainSample], now: Date, minutes: Int = 60,
                                resolution: Resolution = .fiveMinutes) -> [RainForecast] {
        (0..<minutes).compactMap { minute in
            at(now.addingTimeInterval(Double(minute) * 60), from: samples, resolution: resolution)
        }
    }

    /// Up to two hours from `moment`: the samples from the step that holds it, stopping at the
    /// first step without data. Nil when there is no data for `moment` itself.
    public static func at(_ moment: Date, from samples: [RainSample], resolution: Resolution = .fiveMinutes) -> RainForecast? {
        guard let first = samples.lastIndex(where: { $0.date <= moment }) else { return nil }
        let stop = samples[first].date.addingTimeInterval(window)
        var picked: [RainSample] = []
        for sample in samples[first...] {
            guard sample.date <= stop, sample.rate != nil else { break }
            picked.append(sample)
        }
        let forecast = RainForecast(samples: picked, now: moment, resolution: resolution)
        guard !picked.isEmpty, forecast.forecastEnd > moment else { return nil }
        return forecast
    }
}
