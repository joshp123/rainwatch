import SwiftUI

/// The Buienradar line: a smooth curve through each five-minute height, with flat tangents at
/// every sample so it never dips below zero or rises above a real peak.
enum RainCurve {
    /// Any rain gets at least this fraction of full height, so drizzle never looks dry.
    static let traceFloor = 0.16

    /// Drawn height for a Buienradar graph height. The square root keeps Buienradar's order and
    /// scale lines but lifts drizzle and light rain, which is most Dutch rain, off the baseline
    /// of a graph only 20 to 40 points tall.
    public static func display(_ height: Double) -> Double {
        height > 0 ? max(traceFloor, (min(height, 100) / 100).squareRoot()) : 0
    }

    /// Points along the curve as (time 0…1, height 0…1).
    static func points(_ forecast: RainForecast, subdivisions: Int = 10) -> [(t: Double, v: Double)] {
        let values = forecast.samples.map { display($0.height) }
        let times = forecast.samples.map { forecast.position(of: $0.date) }
        guard values.count > 1 else { return values.isEmpty ? [] : [(0, values[0])] }

        var result: [(t: Double, v: Double)] = [(times[0], values[0])]
        for index in 1..<values.count {
            let (t0, t1, v0, v1) = (times[index - 1], times[index], values[index - 1], values[index])
            let dt = t1 - t0
            for step in 1...subdivisions {
                let s = Double(step) / Double(subdivisions)
                let t = bezier(s, t0, t0 + dt * 0.25, t0 + dt * 0.75, t1)
                let v = bezier(s, v0, v0, v1, v1)
                result.append((min(t, 1), v))
            }
        }
        return result.filter { $0.t <= 1 }
    }

    private static func bezier(_ s: Double, _ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> Double {
        let r = 1 - s
        return r * r * r * p0 + 3 * r * r * s * p1 + 3 * r * s * s * p2 + s * s * s * p3
    }
}

/// Filled rain area over a straight time axis.
public struct RainArea: Shape {
    let forecast: RainForecast

    public init(forecast: RainForecast) {
        self.forecast = forecast
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            for point in RainCurve.points(forecast) {
                path.addLine(to: CGPoint(x: rect.minX + point.t * rect.width, y: rect.maxY - point.v * rect.height))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
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

    public init(forecast: RainForecast, startAngle: Angle, sweep: Angle, baseline: Double, full: Double, floorAtBaseline rainFloor: Double? = nil) {
        self.forecast = forecast
        self.startAngle = startAngle
        self.sweep = sweep
        self.baseline = baseline
        self.full = full
        self.rainFloor = rainFloor
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
            let curve = RainCurve.points(forecast)
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

    public init(startAngle: Angle, sweep: Angle, radius: Double) {
        self.startAngle = startAngle
        self.sweep = sweep
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: min(rect.width, rect.height) / 2 * radius,
                startAngle: startAngle,
                endAngle: startAngle + sweep,
                clockwise: false
            )
        }
    }
}
