import SwiftUI

/// The Buienradar line: a monotone cubic through each five-minute height (Fritsch and Carlson), so
/// the curve is smooth without steps at each sample, and still never dips below zero or rises
/// above a real peak.
public enum RainCurve {
    /// Any rain gets at least this fraction of full height, so drizzle never looks dry.
    static let traceFloor = 0.16

    public enum Scale: Sendable {
        /// Lifts drizzle and light rain, which is most Dutch rain, off the baseline of a flat graph
        /// only 20 to 40 points tall, keeping Buienradar's order and scale lines.
        case squareRoot
        /// Buienradar's own height, so a heavy peak stands clearly above a light one.
        case linear
    }

    public static func display(_ height: Double, _ scale: Scale = .squareRoot) -> Double {
        guard height > 0 else { return 0 }
        let fraction = min(height, 100) / 100
        switch scale {
        case .squareRoot: return max(traceFloor, fraction.squareRoot())
        case .linear: return max(0.1, fraction)
        }
    }

    /// Points along the curve as (time 0…1, height 0…1).
    static func points(_ forecast: RainForecast, scale: Scale = .squareRoot, subdivisions: Int = 10) -> [(t: Double, v: Double)] {
        // Each sample covers the five minutes after it, so it is drawn at the middle of them: the
        // line then rises around the moment rain starts, where the dot is, not before it.
        let values = forecast.samples.map { display($0.height, scale) }
        let times = forecast.samples.map { forecast.position(of: $0.date.addingTimeInterval(RainForecast.step / 2)) }
        guard values.count > 1 else { return values.isEmpty ? [] : [(0, values[0])] }

        // Tangents: the mean of the neighbouring slopes, flat at peaks and troughs and beside a dry
        // sample, then limited so no segment overshoots.
        let n = values.count
        var slopes = (0..<(n - 1)).map { (values[$0 + 1] - values[$0]) / (times[$0 + 1] - times[$0]) }
        slopes = slopes.map { $0.isFinite ? $0 : 0 }
        var tangents = [Double](repeating: 0, count: n)
        for k in 1..<(n - 1) {
            let (before, after) = (slopes[k - 1], slopes[k])
            let flat = before * after <= 0 || values[k - 1] == 0 || values[k + 1] == 0
            tangents[k] = flat ? 0 : (before + after) / 2
        }
        for k in 0..<(n - 1) where slopes[k] != 0 {
            let a = tangents[k] / slopes[k], b = tangents[k + 1] / slopes[k]
            let length = (a * a + b * b).squareRoot()
            if length > 3 {
                tangents[k] = 3 / length * a * slopes[k]
                tangents[k + 1] = 3 / length * b * slopes[k]
            }
        }

        var result: [(t: Double, v: Double)] = [(0, values[0]), (times[0], values[0])]
        for k in 0..<(n - 1) {
            let (t0, t1) = (times[k], times[k + 1])
            let h = t1 - t0
            for step in 1...subdivisions {
                let s = Double(step) / Double(subdivisions)
                let (s2, s3) = (s * s, s * s * s)
                let v = (2 * s3 - 3 * s2 + 1) * values[k] + (s3 - 2 * s2 + s) * h * tangents[k]
                    + (-2 * s3 + 3 * s2) * values[k + 1] + (s3 - s2) * h * tangents[k + 1]
                result.append((min(t0 + s * h, 1), max(0, v)))
            }
        }
        return result.filter { $0.t <= 1 }
    }
}

extension RainCurve {
    /// The curve cut into its wet stretches, each starting and ending on the baseline, so dry time
    /// draws nothing at all (a zero-height area leaves a coloured hairline along the baseline).
    /// `gap` is a stretch of time left empty around the change dot, so the dot never touches the
    /// rain on any face (tinted faces keep only alpha, so a dark ring or a cut-out doesn't survive).
    static func wetRuns(_ forecast: RainForecast, scale: Scale, gap: ClosedRange<Double>? = nil) -> [[(t: Double, v: Double)]] {
        var runs: [[(t: Double, v: Double)]] = []
        var run: [(t: Double, v: Double)] = []
        var lastDry: (t: Double, v: Double)?
        for var point in points(forecast, scale: scale) {
            if let gap, gap.contains(point.t) { point.v = 0 }
            if point.v > 0.0005 {
                if run.isEmpty { run.append((lastDry?.t ?? point.t, 0)) }
                run.append(point)
            } else {
                if !run.isEmpty {
                    run.append((point.t, 0))
                    runs.append(run)
                    run = []
                }
                lastDry = point
            }
        }
        if !run.isEmpty { runs.append(run + [(run.last!.t, 0)]) }
        return runs
    }
}

/// Filled rain area over a straight time axis, wet stretches only.
public struct RainArea: Shape {
    let forecast: RainForecast
    var scale: RainCurve.Scale = .squareRoot
    var gap: ClosedRange<Double>?

    public init(forecast: RainForecast, scale: RainCurve.Scale = .squareRoot, gap: ClosedRange<Double>? = nil) {
        self.forecast = forecast
        self.scale = scale
        self.gap = gap
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            for run in RainCurve.wetRuns(forecast, scale: scale, gap: gap) {
                for (index, point) in run.enumerated() {
                    let p = CGPoint(x: rect.minX + point.t * rect.width, y: rect.maxY - point.v * rect.height)
                    index == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                path.closeSubpath()
            }
        }
    }
}

/// The top edge of the rain area, to stroke as the line itself: "height of line to show rain
/// intensity", as Josh put it. A bright edge reads better at wrist distance than a flat fill.
public struct RainEdge: Shape {
    let forecast: RainForecast
    var scale: RainCurve.Scale = .squareRoot
    var gap: ClosedRange<Double>?

    public init(forecast: RainForecast, scale: RainCurve.Scale = .squareRoot, gap: ClosedRange<Double>? = nil) {
        self.forecast = forecast
        self.scale = scale
        self.gap = gap
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            for run in RainCurve.wetRuns(forecast, scale: scale, gap: gap) {
                for (index, point) in run.dropFirst().dropLast().enumerated() {
                    let p = CGPoint(x: rect.minX + point.t * rect.width, y: rect.maxY - point.v * rect.height)
                    index == 0 ? path.move(to: p) : path.addLine(to: p)
                }
            }
        }
    }
}

/// The same area bent round an arc: time runs clockwise along the arc, height grows outwards.
/// Angles are clockwise from three o'clock, as on screen.
public struct RadialRainArea: Shape {
    let forecast: RainForecast
    var startAngle: Angle
    var sweep: Angle
    /// Baseline radius and full-height radius, as fractions of half the frame. Any rain reaches at
    /// least `rainFloor`, so drizzle covers a track drawn between `baseline` and `rainFloor`.
    var baseline: Double
    var full: Double
    var rainFloor: Double?
    var scale: RainCurve.Scale
    var gap: ClosedRange<Double>?

    public init(forecast: RainForecast, startAngle: Angle, sweep: Angle, baseline: Double, full: Double,
                floorAtBaseline rainFloor: Double? = nil, scale: RainCurve.Scale = .squareRoot, gap: ClosedRange<Double>? = nil) {
        self.forecast = forecast
        self.startAngle = startAngle
        self.sweep = sweep
        self.baseline = baseline
        self.full = full
        self.rainFloor = rainFloor
        self.scale = scale
        self.gap = gap
    }

    public func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let half = min(rect.width, rect.height) / 2
        func point(_ t: Double, _ v: Double) -> CGPoint {
            let angle = startAngle.radians + t * sweep.radians
            let base = v > 0 ? (rainFloor ?? baseline) : baseline
            let radius = half * (base + v * (full - base))
            return CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
        }
        return Path { path in
            let curve = RainCurve.points(forecast, scale: scale).map { point in
                (t: point.t, v: gap?.contains(point.t) == true ? 0 : point.v)
            }
            path.move(to: point(0, 0))
            for p in curve { path.addLine(to: point(p.t, p.v)) }
            for p in curve.reversed() { path.addLine(to: point(p.t, 0)) }
            path.closeSubpath()
        }
    }
}

public struct ArcLine: Shape {
    var startAngle: Angle
    var sweep: Angle
    var radius: Double
    /// A stretch of the arc, as fractions 0…1 of the sweep, left undrawn round the change dot.
    var gap: ClosedRange<Double>?

    public init(startAngle: Angle, sweep: Angle, radius: Double, gap: ClosedRange<Double>? = nil) {
        self.startAngle = startAngle
        self.sweep = sweep
        self.radius = radius
        self.gap = gap
    }

    public func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 * radius
        let pieces: [ClosedRange<Double>] = gap.map { [0...max(0, $0.lowerBound), min(1, $0.upperBound)...1] } ?? [0...1]
        return Path { path in
            for piece in pieces where piece.upperBound - piece.lowerBound > 0.001 {
                path.move(to: CGPoint(x: centre.x + r * cos((startAngle + sweep * piece.lowerBound).radians),
                                      y: centre.y + r * sin((startAngle + sweep * piece.lowerBound).radians)))
                path.addArc(center: centre, radius: r, startAngle: startAngle + sweep * piece.lowerBound,
                            endAngle: startAngle + sweep * piece.upperBound, clockwise: false)
            }
        }
    }
}
