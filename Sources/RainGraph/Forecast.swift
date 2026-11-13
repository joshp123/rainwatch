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

    public var isRain: Bool { height > 0 }
}

/// The next two hours of rain at one place. The first sample is now.
public struct RainForecast: Sendable {
    public static let step: TimeInterval = 5 * 60
    public static let window: TimeInterval = 2 * 60 * 60
    /// Buienradar's own scale lines (`borders`): Light, Moderate, Heavy.
    public static let scaleLines: [Double] = [25, 50, 75]

    public var samples: [RainSample]

    public init(samples: [RainSample]) {
        self.samples = samples
    }

    public init(start: Date, heights: [Double]) {
        samples = heights.enumerated().map { index, height in
            RainSample(date: start.addingTimeInterval(Double(index) * Self.step), height: height)
        }
    }

    public var start: Date { samples.first?.date ?? .now }
    public var end: Date { start.addingTimeInterval(Self.window) }

    /// Position of `date` along the window, 0 at now and 1 at two hours.
    public func position(of date: Date) -> Double {
        date.timeIntervalSince(start) / Self.window
    }

    public var outlook: RainOutlook {
        guard let first = samples.first else { return .dry }
        if first.isRain {
            guard let stop = samples.first(where: { !$0.isRain }) else { return .raining }
            return .dryIn(minutes: minutes(until: stop.date))
        }
        guard let rain = samples.first(where: \.isRain) else { return .dry }
        return .rainIn(minutes: minutes(until: rain.date))
    }

    private func minutes(until date: Date) -> Int {
        Int((date.timeIntervalSince(start) / 60).rounded())
    }
}

/// The next change, which is what every family states in words.
public enum RainOutlook: Equatable, Sendable {
    case dry
    case raining
    case rainIn(minutes: Int)
    case dryIn(minutes: Int)

    /// Rectangular and Smart Stack headline.
    public var headline: String {
        switch self {
        case .dry: "Dry"
        case .raining: "Raining"
        case .rainIn(let minutes): "Rain in \(minutes) min"
        case .dryIn(let minutes): "Dry in \(minutes) min"
        }
    }

    /// Corner, inline and bezel labels.
    public var short: String {
        switch self {
        case .dry: "Dry"
        case .raining: "Raining"
        case .rainIn(let minutes): "Rain \(minutes)m"
        case .dryIn(let minutes): "Dry \(minutes)m"
        }
    }

    /// Circular centre: an optional caption over the value.
    public var centre: (caption: String?, value: String) {
        switch self {
        case .dry: (nil, "Dry")
        case .raining: (nil, "Rain")
        case .rainIn(let minutes): ("RAIN", "\(minutes)m")
        case .dryIn(let minutes): ("DRY", "\(minutes)m")
        }
    }
}
