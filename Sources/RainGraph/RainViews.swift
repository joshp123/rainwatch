import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Rectangular family: Modular Ultra's large slot, other modular faces, and the Smart Stack.
/// The headline says the next change; the line shows the whole two hours.
public struct RectangularRainView: View {
    let forecast: RainForecast
    let palette: RainPalette

    public init(forecast: RainForecast, palette: RainPalette) {
        self.forecast = forecast
        self.palette = palette
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(palette.rain)
                    .accentable()
                Text(forecast.outlook.headline)
                    .foregroundStyle(palette.primary)
            }
            .font(RainFont.rounded(15, .semibold))

            RainChart(forecast: forecast, palette: palette)
            TimeAxis(forecast: forecast, palette: palette)
        }
    }
}

/// Height is intensity on Buienradar's own scale; left to right is now to two hours.
struct RainChart: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                ForEach(RainForecast.scaleLines, id: \.self) { line in
                    Path { path in
                        let y = size.height * (1 - line / 100)
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
                    for hour in hourMarks {
                        let x = size.width * forecast.position(of: hour)
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: size.height + 3))
                    }
                }
                .stroke(palette.baseline, lineWidth: 1.5)
            }
        }
    }

    private var hourMarks: [Date] { forecast.hourMarks }
}

struct TimeAxis: View {
    let forecast: RainForecast
    let palette: RainPalette

    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Text("Now")
                ForEach(forecast.hourMarks, id: \.self) { hour in
                    let x = proxy.size.width * forecast.position(of: hour)
                    if x > 30, x < proxy.size.width - 14 {
                        Text(Self.clock.string(from: hour))
                            .fixedSize()
                            .position(x: x, y: proxy.size.height / 2)
                    }
                }
            }
        }
        .font(RainFont.rounded(11, .medium))
        .foregroundStyle(palette.secondary)
        .frame(height: 13)
    }
}

/// Circular family. The ring is a gauge arc like Apple's own circular gauges: time runs
/// clockwise from now at the lower left, past one hour at the top, to two hours at the lower right.
public struct CircularRainView: View {
    let forecast: RainForecast
    let palette: RainPalette

    static let start = Angle.degrees(135)
    static let sweep = Angle.degrees(270)

    public init(forecast: RainForecast, palette: RainPalette) {
        self.forecast = forecast
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            RadialRainArea(forecast: forecast, startAngle: Self.start, sweep: Self.sweep, baseline: 0.6, full: 1)
                .fill(palette.rain)
                .accentable()
            ArcLine(startAngle: Self.start, sweep: Self.sweep, radius: 0.6)
                .stroke(palette.baseline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            centre
        }
    }

    private var centre: some View {
        let (caption, value) = forecast.outlook.centre
        return VStack(spacing: -1) {
            if let caption {
                Text(caption)
                    .font(RainFont.rounded(7.5, .bold))
                    .foregroundStyle(palette.secondary)
            }
            Text(value)
                .font(RainFont.rounded(12.5, .semibold))
                .foregroundStyle(palette.primary)
        }
        .minimumScaleFactor(0.7)
    }
}

extension RainForecast {
    /// Whole clock hours inside the window, for ticks and labels.
    var hourMarks: [Date] {
        let calendar = Calendar.current
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
