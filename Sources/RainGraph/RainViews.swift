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
        GeometryReader { proxy in
            // The line needs about 22 points to show how hard it rains. Slots shorter than the
            // Modular Ultra one can't hold it under two lines of words, so the second line goes,
            // as Apple's Heart Rate complication shows one line over its chart.
            let detail = proxy.size.height >= 74 ? copy.detail : nil
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
                // Matched to Apple's Stocks rows beside it on Josh's face, about 16 points.
                .font(RainFont.rounded(16, .semibold))
                if let detail {
                    Text(detail)
                        .font(RainFont.rounded(13.5, .medium))
                        .foregroundStyle(palette.rain)
                        .accentable()
                }
                RainChart(forecast: forecast, palette: palette)
                    .padding(.top, 3)
                TimeAxis(forecast: forecast, palette: palette)
                    .padding(.top, 4)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy.spoken)
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
    var scale: RainCurve.Scale = .squareRoot

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                // Under 24 points the three lines merge into a band that reads as a ruler.
                ForEach(size.height >= 24 ? RainForecast.scaleLines : [], id: \.self) { line in
                    Path { path in
                        let y = size.height * (1 - RainCurve.display(line, scale))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    .stroke(palette.grid, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                }
                RainArea(forecast: forecast, scale: scale)
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
    var diameter: CGFloat = 8

    var body: some View {
        Circle()
            .fill(palette.primary)
            .padding(diameter * 0.19)
            .background(Circle().fill(.black))
            .frame(width: diameter, height: diameter)
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
                    // "Now" ends about 22 points in; an hour label any closer reads as "Now 14:00".
                    if x > 50, x < proxy.size.width - 14 {
                        Text(RainCopy.clock(hour))
                            .fixedSize()
                            .position(x: x, y: proxy.size.height / 2)
                    }
                }
            }
        }
        .font(RainFont.rounded(11, .medium))
        .foregroundStyle(palette.secondary)
        .frame(height: 12)
    }
}

/// Circular family. The arc is Buienradar's graph bent round: a 240° arc open at the bottom, like
/// Apple's gauges, running clockwise from now at the lower left to two hours at the lower right.
/// The track is the baseline; rain rises from it towards the rim, so a heavy peak stands well above
/// a light one. The dot marks the next change. With no rain there is no line, only "Dry".
///
/// It sits on the same grey disc as the complications beside it on Josh's face, and its words
/// match theirs: Sunrise and World Clock set two lines of the same size, about 8 points tall, and
/// colour the label (World Clock's "SF" is orange). Here the number is white and the words around
/// it are in Buienradar's blue. Text is never boxed smaller than its line height, which would make
/// the system shrink it.
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
    /// Draw the disc. The widget leaves it to `AccessoryWidgetBackground`.
    let plate: Bool

    static let start = Angle.degrees(150)
    static let sweep = Angle.degrees(240)
    /// Radii as fractions of the slot's radius; the disc behind fills about 0.92 of it.
    static let rim = 0.86
    static let track = 0.65

    public init(forecast: RainForecast, palette: RainPalette, middle: Middle = .minutes, plate: Bool = false) {
        self.forecast = forecast
        self.palette = palette
        self.middle = middle
        self.plate = plate
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let half = side / 2
            let stroke = side * 0.04
            let halfStroke = stroke / side
            let track = middle == .minutes ? Self.track : 0.42
            let copy = RainCopy(forecast)
            ZStack {
                if plate {
                    Circle().fill(palette.plate).frame(width: side * 0.92, height: side * 0.92)
                }
                if forecast.hasRain {
                    ArcLine(startAngle: Self.start, sweep: Self.sweep, radius: track)
                        .stroke(palette.baseline, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    RadialRainArea(forecast: forecast, startAngle: Self.start, sweep: Self.sweep,
                                   baseline: track - halfStroke, full: Self.rim, floorAtBaseline: track + halfStroke,
                                   scale: .squareRoot)
                        .fill(palette.rain)
                        .accentable()
                    if let change = copy.change {
                        let angle = Self.start.radians + forecast.position(of: change) * Self.sweep.radians
                        ChangeDot(palette: palette, diameter: side * 0.1)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RainCopy(forecast).spoken)
    }

    /// Read top to bottom as one phrase: the lead word inside the arc, the number in the middle,
    /// the unit in the gap at the bottom where Apple's gauges put their labels.
    private func centre(side: CGFloat, copy: RainCopy) -> some View {
        let (lead, value, unit) = copy.circular
        let mid = side / 2
        return ZStack {
            if let lead {
                word(lead, side: side, size: 0.2)
                    .position(x: mid, y: mid - side * 0.14)
            }
            // Three characters at the two-character size would touch the arc.
            Text(value)
                .font(RainFont.rounded(side * (value.count > 2 ? 0.23 : 0.28), .semibold))
                .foregroundStyle(palette.primary)
                .fixedSize()
                .position(x: mid, y: mid + side * (lead == nil ? -0.02 : 0.07))
            if let unit {
                word(unit, side: side, size: 0.21)
                    .position(x: mid, y: mid + side * 0.315)
            }
        }
        .frame(width: side, height: side)
    }

    private func word(_ text: String, side: CGFloat, size: CGFloat = 0.22) -> some View {
        Text(text)
            .font(RainFont.rounded(side * size, .semibold))
            .foregroundStyle(palette.rain)
            .accentable()
            .fixedSize()
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
