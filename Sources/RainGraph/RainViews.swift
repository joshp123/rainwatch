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
                .padding(.top, 1)
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
                        path.addLine(to: CGPoint(x: x, y: size.height + 3))
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

/// Circular family, drawn like Apple's own gauges (the Weather temperature gauge sits next to it on
/// Josh's face): a 240° arc open at the bottom, one value in the middle, a short word in the gap.
/// The arc is the next two hours, clockwise from now at the lower left. Dry is a thin track; rain
/// thickens it inwards by intensity. The dot marks the change the middle value names.
public struct CircularRainGauge: View {
    let forecast: RainForecast
    let palette: RainPalette

    static let start = Angle.degrees(150)
    static let sweep = Angle.degrees(240)

    public init(forecast: RainForecast, palette: RainPalette) {
        self.forecast = forecast
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let half = side / 2
            let stroke = side * 0.06
            let track = 1 - stroke / side
            let inner = track - stroke / side
            let copy = RainCopy(forecast)
            ZStack {
                ArcLine(startAngle: Self.start, sweep: Self.sweep, radius: track)
                    .stroke(palette.baseline, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                RadialRainArea(forecast: forecast, startAngle: Self.start, sweep: Self.sweep,
                               baseline: 1, full: inner - 0.22, floorAtBaseline: inner)
                    .fill(palette.rain)
                    .accentable()
                if let change = copy.change {
                    let angle = Self.start.radians + forecast.position(of: change) * Self.sweep.radians
                    ChangeDot(palette: palette)
                        .position(x: half + half * track * cos(angle), y: half + half * track * sin(angle))
                }
                Text(copy.circular.value)
                    .font(RainFont.rounded(side * (copy.circular.value.count > 4 ? 0.29 : 0.33), .semibold))
                    .foregroundStyle(palette.primary)
                    .offset(y: -side * 0.02)
                if let label = copy.circular.gapLabel {
                    Text(label)
                        .font(RainFont.rounded(side * 0.19, .bold))
                        .foregroundStyle(label == "RAIN" ? palette.rain : palette.primary)
                        .position(x: half, y: side * 0.86)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
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
