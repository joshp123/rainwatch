import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Rectangular family: the large slot on Modular Ultra, and the Smart Stack.
/// The headline says whether it is dry now and for how long; the line shows the whole two hours.
public struct RectangularRainView: View {
    let forecast: RainForecast
    let palette: RainPalette

    public init(forecast: RainForecast, palette: RainPalette) {
        self.forecast = forecast
        self.palette = palette
    }

    public var body: some View {
        let copy = RainCopy(forecast)
        VStack(alignment: .leading, spacing: 1) {
            Label {
                Text(copy.headline)
                    .foregroundStyle(palette.primary)
            } icon: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(palette.rain)
                    .accentable()
            }
            .labelStyle(HeadlineLabelStyle())
            .font(RainFont.rounded(14.5, .semibold))
            if let detail = copy.detail {
                Text(detail)
                    .font(RainFont.rounded(12, .medium))
                    .foregroundStyle(palette.rain)
                    .accentable()
            }
            RainChart(forecast: forecast, palette: palette)
                .padding(.top, 3)
            TimeAxis(forecast: forecast, palette: palette)
                .padding(.top, 4)
        }
        .lineLimit(1)
    }
}

struct HeadlineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// Height is intensity on Buienradar's own scale; left to right is now to two hours.
/// The dot marks when the weather changes, the moment the headline counts down to.
struct RainChart: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                ForEach(RainForecast.scaleLines, id: \.self) { line in
                    Path { path in
                        let y = size.height * (1 - RainCurve.display(line))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    .stroke(palette.grid, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                }
                RainArea(forecast: forecast)
                    .fill(palette.rain)
                    .accentable()
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    for hour in forecast.hourMarks {
                        let x = size.width * forecast.position(of: hour)
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: size.height + 4))
                    }
                }
                .stroke(palette.baseline, lineWidth: 1.5)
                if let change = RainCopy(forecast).change {
                    ChangeDot(palette: palette)
                        .position(x: size.width * forecast.position(of: change), y: size.height)
                }
            }
        }
    }
}

/// Apple's gauge indicator: a white dot with a dark ring, so it reads on any colour.
struct ChangeDot: View {
    let palette: RainPalette

    var body: some View {
        Circle()
            .fill(palette.primary)
            .frame(width: 5, height: 5)
            .padding(1.5)
            .background(Circle().fill(.black))
    }
}

struct TimeAxis: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Text("Now")
                ForEach(forecast.hourMarks, id: \.self) { hour in
                    let x = proxy.size.width * forecast.position(of: hour)
                    if x > 30, x < proxy.size.width - 14 {
                        Text(RainCopy.clock(hour))
                            .fixedSize()
                            .position(x: x, y: proxy.size.height / 2)
                    }
                }
            }
        }
        .font(RainFont.rounded(10.5, .medium))
        .foregroundStyle(palette.secondary)
        .frame(height: 12)
    }
}

/// Circular family. The arc is Buienradar's graph bent round: a 240° arc open at the bottom, like
/// Apple's gauges, running clockwise from now at the lower left to two hours at the lower right.
/// The track is the baseline; rain rises from it towards the rim, on Buienradar's linear scale, so
/// a heavy peak stands well above a light one. The dot marks the next change.
/// With no rain there is no line, only "Dry".
public struct CircularRainGauge: View {
    public enum Middle: Sendable {
        /// Minutes until the change at the dot.
        case minutes
        /// Nothing, so the graph can use the whole circle.
        case none
    }

    let forecast: RainForecast
    let palette: RainPalette
    let middle: Middle

    static let start = Angle.degrees(150)
    static let sweep = Angle.degrees(240)

    public init(forecast: RainForecast, palette: RainPalette, middle: Middle = .minutes) {
        self.forecast = forecast
        self.palette = palette
        self.middle = middle
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let half = side / 2
            let stroke = side * 0.045
            let halfStroke = stroke / side
            let track = middle == .minutes ? 0.58 : 0.42
            let floor = track + halfStroke
            let copy = RainCopy(forecast)
            ZStack {
                if forecast.hasRain {
                    ArcLine(startAngle: Self.start, sweep: Self.sweep, radius: track)
                        .stroke(palette.baseline, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    RadialRainArea(forecast: forecast, startAngle: Self.start, sweep: Self.sweep,
                                   baseline: track - halfStroke, full: 0.99, floorAtBaseline: floor)
                        .fill(palette.rain)
                        .accentable()
                    if let change = copy.change {
                        let angle = Self.start.radians + forecast.position(of: change) * Self.sweep.radians
                        ChangeDot(palette: palette)
                            .position(x: half + half * track * cos(angle), y: half + half * track * sin(angle))
                    }
                }
                if middle == .minutes || !forecast.hasRain {
                    centre(side: side, copy: copy)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// The words sit in boxes measured against the ring at 45 points, so they can never touch it:
    /// the hole inside the track has a radius of about 11.5 points, and the gap at the bottom is
    /// free of the arc below its ends. Long words shrink to fit their box rather than spill out.
    private func centre(side: CGFloat, copy: RainCopy) -> some View {
        let (lead, value, unit) = copy.circular
        let u = side / 45
        return ZStack {
            if forecast.hasRain {
                if let lead {
                    small(lead, u: u)
                        .frame(width: 13 * u, height: 7 * u)
                        .position(x: side / 2, y: side / 2 - 7 * u)
                }
                Text(value)
                    .font(RainFont.rounded(13 * u, .semibold))
                    .foregroundStyle(palette.primary)
                    .minimumScaleFactor(0.6)
                    .frame(width: 18 * u, height: 11 * u)
                    .position(x: side / 2, y: side / 2 + 1.5 * u)
                if let unit {
                    small(unit, u: u)
                        .frame(width: 16 * u, height: 7 * u)
                        .position(x: side / 2, y: side / 2 + 11 * u)
                }
            } else {
                VStack(spacing: 0) {
                    Text(value)
                        .font(RainFont.rounded(17 * u, .semibold))
                        .foregroundStyle(palette.primary)
                    if let unit {
                        small(unit, u: u)
                    }
                }
            }
        }
        .frame(width: side, height: side)
    }

    private func small(_ text: String, u: CGFloat) -> some View {
        Text(text)
            .font(RainFont.rounded(7 * u, .bold))
            .foregroundStyle(palette.secondary)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}

extension RainForecast {
    /// Whole clock hours inside the window, for ticks and labels.
    var hourMarks: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        guard var hour = calendar.nextDate(after: start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) else { return [] }
        var marks: [Date] = []
        while hour <= end {
            marks.append(hour)
            hour = hour.addingTimeInterval(3600)
        }
        return marks
    }
}

extension View {
    @ViewBuilder func accentable() -> some View {
        #if canImport(WidgetKit)
        widgetAccentable()
        #else
        self
        #endif
    }
}
