import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Rectangular family: the large slot on Modular Ultra, and the Smart Stack.
/// The headline says whether it is dry now and for how long; the line shows the whole two hours.
/// Ways to draw the large slot's graph, to compare on the face (design/README.md). `today` is the
/// one in use.
public struct SlotStyle: Sendable {
    /// A solid fill and no dotted scale lines.
    public var solid = false
    public var scale: RainCurve.Scale = .squareRoot
    /// The row of "Now" and the hours under the graph. Without it the graph is taller.
    public var hourLabels = true

    public static let today = SlotStyle()
    /// The numbers the app's `-slotStyle` option takes.
    public static let options: [SlotStyle] = [
        .today,
        SlotStyle(solid: true),
        SlotStyle(solid: true, scale: .cubeRoot),
        SlotStyle(solid: true, scale: .cubeRoot, hourLabels: false),
    ]
}

public struct RectangularRainView: View {
    let forecast: RainForecast
    let palette: RainPalette
    /// When the data was made. Once it is 20 minutes old, the second line says so.
    let issued: Date?
    /// Set for Apple's data, whose terms want its mark wherever it is shown.
    let appleWeather: Bool

    var style = SlotStyle.today

    public init(forecast: RainForecast, palette: RainPalette, issued: Date? = nil, appleWeather: Bool = false, style: SlotStyle = .today) {
        self.style = style
        self.forecast = forecast
        self.palette = palette
        self.issued = issued
        self.appleWeather = appleWeather
    }

    private var isOld: Bool {
        guard let issued else { return false }
        return forecast.now.timeIntervalSince(issued) >= Snapshot.oldAfter
    }

    /// Apple's data names its source on the second line, in place of what follows: the line below
    /// still shows it.
    private var credit: String? {
        guard appleWeather else { return nil }
        return forecast.resolution == .hourly ? "\u{F8FF}Weather, hourly" : "\u{F8FF}Weather"
    }

    public var body: some View {
        let copy = RainCopy(forecast)
        GeometryReader { proxy in
            // The line needs about 22 points to show how hard it rains. Slots shorter than the
            // Modular Ultra one can't hold it under two lines of words, so the second line goes,
            // as Apple's Heart Rate complication shows one line over its chart.
            let roomy = proxy.size.height >= 74
            VStack(alignment: .leading, spacing: 1) {
                // No icon before the headline: it pushed the headline right of the lines below.
                Text(copy.headline)
                    .foregroundStyle(palette.primary)
                    // Matched to Apple's Stocks rows beside it on Josh's face, about 16 points.
                    .font(RainFont.rounded(16, .semibold))
                // An old forecast always says its time, in any slot: where there is room for only
                // one line of words, as on Modular Ultra, it takes the place of the hour labels.
                if isOld, let issued {
                    Text("Forecast from \(RainCopy.clock(issued))")
                        .font(RainFont.rounded(13.5, .medium))
                        .foregroundStyle(palette.secondary)
                } else if roomy, let credit {
                    Text(credit)
                        .font(RainFont.rounded(13.5, .medium))
                        .foregroundStyle(palette.secondary)
                } else if roomy, let detail = copy.detail, copy.detailIsAboutRain {
                    Text(detail)
                        .font(RainFont.rounded(13.5, .medium))
                        .foregroundStyle(palette.rain)
                        .accentable()
                } else if roomy, let detail = copy.detail {
                    Text(detail)
                        .font(RainFont.rounded(13.5, .medium))
                        .foregroundStyle(palette.secondary)
                }
                RainChart(forecast: forecast, palette: palette, scale: style.scale, solid: style.solid)
                    .padding(.top, 3)
                if !style.hourLabels {
                    Color.clear.frame(height: 6)
                } else if roomy || !isOld {
                    TimeAxis(forecast: forecast, palette: palette)
                        .padding(.top, 4)
                } else {
                    Color.clear.frame(height: 5)
                }
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy.spoken)
    }
}

/// Height is intensity on Buienradar's graph scale; left to right is now to two hours.
/// The dot marks when the weather changes, the moment the headline counts down to.
struct RainChart: View {
    let forecast: RainForecast
    let palette: RainPalette
    var scale: RainCurve.Scale = .squareRoot
    var solid = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                // Under 24 points the three lines merge into a band that reads as a ruler.
                ForEach(size.height >= 24 && !solid ? RainForecast.scaleLines : [], id: \.self) { line in
                    Path { path in
                        let y = size.height * (1 - RainCurve.display(line, scale))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    .stroke(palette.grid, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                }
                let dot = RainCopy(forecast).change.map { CGPoint(x: size.width * forecast.position(of: $0), y: size.height) }
                // The dot's radius plus 2 points.
                let hole = dot.map { Path.disc($0, radius: 4.5) }
                RainArea(forecast: forecast, scale: scale)
                    .cut(hole)
                    .fill(palette.rain.opacity(solid ? 0.9 : 0.55))
                    .accentable()
                RainEdge(forecast: forecast, scale: scale)
                    .cut(hole, stroke: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .fill(palette.rain)
                    .accentable()
                // Past where the forecast stops, the baseline is dotted: no forecast yet, not dry.
                let known = size.width * min(1, forecast.position(of: forecast.forecastEnd))
                if forecast.end.timeIntervalSince(forecast.forecastEnd) > 10 * 60 {
                    Path { path in
                        path.move(to: CGPoint(x: known + 3, y: size.height))
                        path.addLine(to: CGPoint(x: size.width, y: size.height))
                    }
                    .stroke(palette.baseline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 4]))
                }
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: known, y: size.height))
                    for hour in forecast.hourMarks {
                        let x = size.width * forecast.position(of: hour)
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: size.height + 4))
                    }
                }
                .cut(hole, stroke: StrokeStyle(lineWidth: 1.5))
                .fill(palette.baseline)
                if let dot {
                    ChangeDot(palette: palette).position(dot)
                }
            }
        }
    }
}

/// Apple's gauge indicator: a white dot, with nothing drawn close round it.
struct ChangeDot: View {
    let palette: RainPalette
    var diameter: CGFloat = 8

    var body: some View {
        Circle()
            .fill(palette.primary)
            .frame(width: diameter * 0.62, height: diameter * 0.62)
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
                    } else if x > 50 {
                        // Too near the edge to centre: right-align it, so there are always two anchors.
                        Text(RainCopy.clock(hour))
                            .fixedSize()
                            .frame(width: proxy.size.width, alignment: .trailing)
                    }
                }
            }
        }
        .font(RainFont.rounded(11, .medium))
        .foregroundStyle(palette.secondary)
        .frame(height: 12)
    }
}

/// Circular family. The arc is the rain graph bent round: a 240° arc open at the bottom, like
/// Apple's gauges, running clockwise from now at the lower left to two hours at the lower right.
/// The track is the baseline, drawn as far as the forecast reaches; rain rises from it to the rim on
/// the square root of the graph height, so peaks show (Josh: "the one thing i MISS is simulating the height of the peaks"). In
/// the 94 saved forecasts the typical wet peak is 12 of 100: on a linear scale that stood 0.4
/// points high, on the square root 2.2. The dot marks the next change. With no rain there is no line, only "Dry".
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
    /// Radii as fractions of the slot's radius; the disc behind fills the slot.
    static let rim = 0.98
    static let track = 0.66

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
            // Apple's minimum line weight is 2 points.
            let stroke = max(2, side * 0.045)
            let halfStroke = stroke / side
            let track = middle == .minutes ? Self.track : 0.42
            let copy = RainCopy(forecast)
            ZStack {
                if plate {
                    Circle().fill(palette.plate)
                }
                if forecast.hasRain {
                    let dot = copy.change.map { change -> CGPoint in
                        let angle = Self.start.radians + forecast.position(of: change) * Self.sweep.radians
                        return CGPoint(x: half + half * track * cos(angle), y: half + half * track * sin(angle))
                    }
                    let hole = side * 0.065
                    // The rain is cut straight across, along the radii either side of the dot: a
                    // round hole would leave a fleck of a short spell of rain beyond it.
                    let wedge = copy.change.map { change -> Path in
                        let angle = Self.start + Self.sweep * forecast.position(of: change)
                        let spread = Angle(radians: hole / (half * track))
                        return Path { path in
                            path.move(to: CGPoint(x: half, y: half))
                            path.addArc(center: CGPoint(x: half, y: half), radius: half,
                                        startAngle: angle - spread, endAngle: angle + spread, clockwise: false)
                            path.closeSubpath()
                        }
                    }
                    // The track runs as far as the forecast does: an older forecast has a shorter arc.
                    GaugeTrack(startAngle: Self.start, sweep: Self.sweep * min(1, forecast.position(of: forecast.forecastEnd)),
                               radius: track, lineWidth: stroke,
                               roundStart: (forecast.samples.first?.height ?? 0) == 0,
                               roundEnd: (forecast.samples.last?.height ?? 0) == 0)
                        .cut(dot.map { Path.disc($0, radius: hole) })
                        .fill(palette.baseline)
                    RadialRainArea(forecast: forecast, startAngle: Self.start, sweep: Self.sweep,
                                   baseline: track - halfStroke, full: Self.rim, floorAtBaseline: track + halfStroke,
                                   scale: .squareRoot)
                        .cut(wedge)
                        .fill(palette.rain)
                        .accentable()
                    if let dot {
                        ChangeDot(palette: palette, diameter: side * 0.1).position(dot)
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
    /// the unit in the gap at the bottom where Apple's gauges put their labels. Sizes are fractions
    /// of the slot, measured on Josh's watch so that the number is as tall as "07:59" beside it
    /// and the unit as tall as "SF" (the Mac draws this font smaller than the watch does, so only
    /// the real face is a fair ruler). Without an arc, the two lines sit as one
    /// block in the middle, as theirs do.
    private func centre(side: CGFloat, copy: RainCopy) -> some View {
        let (lead, value, unit) = copy.circular
        let mid = side / 2
        return ZStack {
            if forecast.hasRain {
                // Three lines at the neighbours' sizes don't fit inside the arc on a 45 point
                // disc, so the lead word is smaller; the number and the unit match theirs.
                if let lead {
                    // Four letters at the three-letter size would touch the arc.
                    word(lead, side: side, size: lead.count > 3 ? 0.18 : 0.2)
                        .position(x: mid, y: mid - side * 0.15)
                }
                // Three characters at the two-character size would touch the arc.
                Text(value)
                    .font(RainFont.rounded(side * (value.count > 2 ? 0.22 : 0.27), .semibold))
                    .foregroundStyle(palette.primary)
                    .fixedSize()
                    .position(x: mid, y: mid + side * (lead == nil ? 0 : 0.05))
                if let unit {
                    word(unit, side: side)
                        .position(x: mid, y: mid + side * 0.3)
                }
            } else {
                VStack(spacing: 0) {
                    Text(value)
                        .font(RainFont.rounded(side * 0.27, .semibold))
                        .foregroundStyle(palette.primary)
                    if let unit {
                        word(unit, side: side)
                    }
                }
                .fixedSize()
                .position(x: mid, y: mid)
            }
        }
        .frame(width: side, height: side)
    }

    /// The words round the number. Blue means rain, so they are blue only while it rains; when it
    /// is dry they are grey, and a circle with no blue in it means no rain within two hours.
    @ViewBuilder private func word(_ text: String, side: CGFloat, size: CGFloat = 0.243) -> some View {
        let label = Text(text).font(RainFont.rounded(side * size, .semibold))
        if RainCopy(forecast).isRainingNow {
            label.foregroundStyle(palette.rain).accentable().fixedSize()
        } else {
            label.foregroundStyle(palette.secondary).fixedSize()
        }
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
