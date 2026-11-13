import Foundation

/// One five-minute step of Buienradar's nowcast.
/// `height` is Buienradar's own graph height (`percentageValue`, 0–100), the value its website plots.
public struct RainSample: Hashable, Sendable {
    public var date: Date
    public var height: Double

    public init(date: Date, height: Double) {
        self.date = date
        self.height = height
    }

    /// Any measurable rain counts: Josh wants to know if he gets wet at all.
    public var isRain: Bool { height > 0 }
}

/// How hard it rains, on Buienradar's own graph lines (Light 25, Moderate 50, Heavy 75).
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
        case .drizzle: "Drizzle"
        case .light: "Light rain"
        case .moderate: "Rain"
        case .heavy: "Heavy rain"
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

/// The next two hours of rain at one place. The first sample is now.
public struct RainForecast: Sendable {
    public static let step: TimeInterval = 5 * 60
    public static let window: TimeInterval = 2 * 60 * 60
    /// Buienradar's own scale lines (`borders`): Light, Moderate, Heavy.
    public static let scaleLines: [Double] = [25, 50, 75]

    public var samples: [RainSample]
    /// The moment the forecast is shown. Durations count from here, not from the first sample,
    /// because Buienradar's feed starts at the next five-minute step.
    public var now: Date

    public init(samples: [RainSample], now: Date? = nil) {
        self.samples = samples
        self.now = now ?? samples.first?.date ?? .now
    }

    public init(start: Date, heights: [Double]) {
        samples = heights.enumerated().map { index, height in
            RainSample(date: start.addingTimeInterval(Double(index) * Self.step), height: height)
        }
        now = start
    }

    public var start: Date { samples.first?.date ?? .now }
    public var end: Date { start.addingTimeInterval(Self.window) }

    /// Position of `date` along the window, 0 at now and 1 at two hours.
    public func position(of date: Date) -> Double {
        date.timeIntervalSince(start) / Self.window
    }

    /// Dry gaps shorter than this between two wet stretches can't be used to go out, so the
    /// words treat them as wet. The line still shows them.
    public static let shortestUsefulGap: TimeInterval = 10 * 60

    /// The window cut into dry and wet stretches. Each sample covers the five minutes after it.
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
        let inWindow = samples.filter { $0.date < end }
        var spells: [RainSpell] = []
        for sample in inWindow {
            let sampleEnd = min(sample.date.addingTimeInterval(Self.step), end)
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

    public var hasRain: Bool { samples.contains { $0.isRain && $0.date < end } }

    public func minutes(until date: Date) -> Int {
        max(1, Int((date.timeIntervalSince(now) / 60).rounded()))
    }
}

extension RainForecast {
    /// One forecast per minute from `now`, each showing the two hours from that minute, while the
    /// samples cover them. One fetch of Buienradar's three-hour feed gives about 45 minutes, so a
    /// widget counts down exactly between the system's reloads.
    public static func timeline(from samples: [RainSample], now: Date, minutes: Int = 60) -> [RainForecast] {
        (0..<minutes).compactMap { minute in
            at(now.addingTimeInterval(Double(minute) * 60), from: samples)
        }
    }

    /// The two hours from `moment`, or nil when the samples no longer cover them.
    public static func at(_ moment: Date, from samples: [RainSample]) -> RainForecast? {
        let perWindow = Int(window / step) + 1
        let first = samples.lastIndex { $0.date <= moment } ?? 0
        guard first + perWindow <= samples.count else { return nil }
        return RainForecast(samples: Array(samples[first..<(first + perWindow)]), now: moment)
    }
}
