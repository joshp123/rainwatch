import SwiftUI

/// The rain line: a monotone cubic through each five-minute height (Fritsch and Carlson), so
/// the curve is smooth without steps at each sample, and still never dips below zero or rises
/// above a real peak.
public enum RainCurve {
    /// Any rain gets at least this fraction of full height, so drizzle never looks dry.
    static let traceFloor = 0.16

    public enum Scale: Sendable {
        /// The square root of Buienradar's graph height, as the app has drawn rain until now. It
        /// lifts drizzle off the baseline, but Buienradar's height flattens above 2 mm/h, so a
        /// downpour stands little taller than light rain.
        case squareRoot
        /// Rain in mm/h, a little compressed, full height at Buienradar's Heavy line (11.3 mm/h).
        /// Drizzle is a thin band, light rain a fifth of the height, moderate rain half: the
        /// steps of `Intensity`, so the height agrees with the words.
        case rate
    }

    public static func display(_ height: Double, _ scale: Scale = .rate) -> Double {
        guard height > 0 else { return 0 }
        switch scale {
        case .squareRoot: return max(traceFloor, (min(height, 100) / 100).squareRoot())
        case .rate: return max(0.06, pow(min(1, RainScale.rate(height: height) / RainScale.rate(height: 75)), 0.75))
        }
    }

    /// Points along the curve as (time 0…1, height 0…1).
    static func points(_ forecast: RainForecast, scale: Scale = .rate, subdivisions: Int = 10) -> [(t: Double, v: Double)] {
        // Each sample covers the five minutes after it, so it is drawn at the middle of them: the
        // line then rises around the moment rain starts, where the dot is, not before it.
        // Only the steps before the forecast stops: the last one marks where it ends.
        let steps = forecast.samples.filter { $0.date < forecast.forecastEnd }
        let values = steps.map { display($0.height, scale) }
        let times = steps.map { forecast.position(of: $0.date.addingTimeInterval(RainForecast.step / 2)) }
        guard values.count > 1 else {
            return values.isEmpty ? [] : [(0, values[0]), (min(1, forecast.position(of: forecast.forecastEnd)), values[0])]
        }

        // Tangents: the mean of the neighbouring slopes, flat at peaks, troughs and dry samples, then
        // limited so no segment overshoots or dips below zero.
        let n = values.count
        var slopes = (0..<(n - 1)).map { (values[$0 + 1] - values[$0]) / (times[$0 + 1] - times[$0]) }
        slopes = slopes.map { $0.isFinite ? $0 : 0 }
        var tangents = [Double](repeating: 0, count: n)
        for k in 1..<(n - 1) {
            let (before, after) = (slopes[k - 1], slopes[k])
            tangents[k] = before * after <= 0 ? 0 : (before + after) / 2
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
        // The last sample holds until the forecast stops, which may be before the end of the axis.
        let stop = min(1, forecast.position(of: forecast.forecastEnd))
        if let last = result.last, last.t < stop { result.append((stop, values[n - 1])) }
        return result.filter { $0.t <= stop }
    }
}

extension RainCurve {
    /// The curve cut into its wet stretches, each starting and ending on the baseline, so dry time
    /// draws nothing at all (a zero-height area leaves a coloured hairline along the baseline).
    static func wetRuns(_ forecast: RainForecast, scale: Scale) -> [[(t: Double, v: Double)]] {
        var runs: [[(t: Double, v: Double)]] = []
        var run: [(t: Double, v: Double)] = []
        var lastDry: (t: Double, v: Double)?
        for point in points(forecast, scale: scale) {
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
    var scale: RainCurve.Scale = .rate

    public init(forecast: RainForecast, scale: RainCurve.Scale = .rate) {
        self.forecast = forecast
        self.scale = scale
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            for run in RainCurve.wetRuns(forecast, scale: scale) {
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
    var scale: RainCurve.Scale = .rate

    public init(forecast: RainForecast, scale: RainCurve.Scale = .rate) {
        self.forecast = forecast
        self.scale = scale
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            for run in RainCurve.wetRuns(forecast, scale: scale) {
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

    public init(forecast: RainForecast, startAngle: Angle, sweep: Angle, baseline: Double, full: Double,
                floorAtBaseline rainFloor: Double? = nil, scale: RainCurve.Scale = .rate) {
        self.forecast = forecast
        self.startAngle = startAngle
        self.sweep = sweep
        self.baseline = baseline
        self.full = full
        self.rainFloor = rainFloor
        self.scale = scale
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
            let curve = RainCurve.points(forecast, scale: scale)
            path.move(to: point(0, 0))
            for p in curve { path.addLine(to: point(p.t, p.v)) }
            for p in curve.reversed() { path.addLine(to: point(p.t, 0)) }
            path.closeSubpath()
        }
    }
}

/// The rain as one bar for each five minutes, standing on the arc: a tall bar among short ones is
/// a burst of heavy rain.
public struct RadialRainBars: Shape {
    let forecast: RainForecast
    var startAngle: Angle
    var sweep: Angle
    var baseline: Double
    var full: Double
    var scale: RainCurve.Scale
    /// The part of each five minutes the bar fills; the rest is the gap between bars.
    var fill = 0.62

    public func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let half = min(rect.width, rect.height) / 2
        return Path { path in
            for sample in forecast.samples where sample.date < forecast.forecastEnd && sample.height > 0 {
                let t = forecast.position(of: sample.date)
                let width = RainForecast.step / forecast.span
                let from = startAngle + sweep * (t + width * (1 - fill) / 2)
                let to = startAngle + sweep * min(1, t + width * (1 + fill) / 2)
                let outer = half * (baseline + RainCurve.display(sample.height, scale) * (full - baseline))
                path.addArc(center: centre, radius: outer, startAngle: from, endAngle: to, clockwise: false)
                path.addArc(center: centre, radius: half * baseline, startAngle: to, endAngle: from, clockwise: true)
                path.closeSubpath()
            }
        }
    }
}

/// The gauge's grey track, already stroked. Its ends are round like Apple's gauges, except an end
/// where rain is falling, which is cut square so the cap can't poke out from under the rain.
public struct GaugeTrack: Shape {
    var startAngle: Angle
    var sweep: Angle
    var radius: Double
    var lineWidth: CGFloat
    var roundStart = true
    var roundEnd = true

    public func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 * radius
        func end(_ angle: Angle) -> Path {
            let p = CGPoint(x: centre.x + r * cos(angle.radians), y: centre.y + r * sin(angle.radians))
            return Path(ellipseIn: CGRect(x: p.x - lineWidth / 2, y: p.y - lineWidth / 2, width: lineWidth, height: lineWidth))
        }
        var track = Path { path in
            path.addArc(center: centre, radius: r, startAngle: startAngle, endAngle: startAngle + sweep, clockwise: false)
        }
        .strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
        if roundStart { track = track.union(end(startAngle)) }
        if roundEnd { track = track.union(end(startAngle + sweep)) }
        return track
    }
}

/// A shape with a hole cut round the change dot, as Apple's gauge indicator has. The hole is in the
/// path itself, so it survives tinted faces, which keep only alpha: a dark ring round the dot would
/// turn solid there and fuse the dot to the rain.
public struct Holed<Content: Shape>: Shape {
    var content: Content
    var stroke: StrokeStyle?
    var hole: Path?

    public func path(in rect: CGRect) -> Path {
        let path = stroke.map { content.path(in: rect).strokedPath($0) } ?? content.path(in: rect)
        return hole.map { path.subtracting($0) } ?? path
    }
}

extension Shape {
    /// This shape, stroked first if `stroke` is given, with `hole` cut out of it.
    func cut(_ hole: Path?, stroke: StrokeStyle? = nil) -> Holed<Self> {
        Holed(content: self, stroke: stroke, hole: hole)
    }
}

extension Path {
    static func disc(_ centre: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }
}
