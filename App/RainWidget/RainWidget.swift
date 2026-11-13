import RainGraph
import SwiftUI
import WidgetKit

@main
struct RainWidgets: WidgetBundle {
    var body: some Widget {
        RainWidget()
        RainLineCornerWidget()
    }
}

struct RainEntry: TimelineEntry {
    let date: Date
    /// Nil when there is no forecast to show; `problem` then says why.
    let forecast: RainForecast?
    var problem: String?

    /// The Smart Stack raises the widget when rain is forecast within the two hours.
    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: forecast?.hasRain == true ? 1 : 0)
    }
}

/// One Buienradar fetch gives an entry every minute for about 45 minutes, each showing that minute to
/// two hours ahead. The timeline asks to be reloaded when the entries run out.
struct RainProvider: TimelineProvider {
    func placeholder(in context: Context) -> RainEntry {
        RainEntry(date: .now, forecast: Scenario.showerComing.forecast)
    }

    func getSnapshot(in context: Context, completion: @escaping (RainEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RainEntry>) -> Void) {
        let completion = SendableCompletion(completion)
        Task {
            completion(await Self.timeline(now: .now))
        }
    }

    static func timeline(now: Date) async -> Timeline<RainEntry> {
        do {
            let place = try await Place.current()
            let samples = try await Buienradar.samples(latitude: place.latitude, longitude: place.longitude)
            let entries = RainForecast.timeline(from: samples, now: now).map { RainEntry(date: $0.now, forecast: $0) }
            if let last = entries.last {
                return Timeline(entries: entries, policy: .after(last.date))
            }
        } catch Place.Failure.noLocation {
            return failure("Open Rain to share your location", now: now)
        } catch {}
        return failure("No forecast", now: now)
    }

    private static func failure(_ problem: String, now: Date) -> Timeline<RainEntry> {
        Timeline(entries: [RainEntry(date: now, forecast: nil, problem: problem)], policy: .after(now.addingTimeInterval(15 * 60)))
    }
}

/// WidgetKit's completion handler is not Sendable; it is safe to call once from any thread.
private struct SendableCompletion: @unchecked Sendable {
    let call: (Timeline<RainEntry>) -> Void
    init(_ call: @escaping (Timeline<RainEntry>) -> Void) { self.call = call }
    func callAsFunction(_ timeline: Timeline<RainEntry>) { call(timeline) }
}

struct RainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "rain", provider: RainProvider()) { entry in
            RainComplicationView(entry: entry)
        }
        .configurationDisplayName("Rain")
        .description("Buienradar rain for the next two hours.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct RainComplicationView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: RainEntry

    private var palette: RainPalette {
        renderingMode == .fullColor ? .fullColour : .tinted(.white)
    }

    var body: some View {
        if let forecast = entry.forecast {
            view(for: forecast)
        } else {
            problem
        }
    }

    @ViewBuilder private func view(for forecast: RainForecast) -> some View {
        switch family {
        case .accessoryCircular:
            CircularRainGauge(forecast: forecast, palette: palette)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularRainView(forecast: forecast, palette: palette)
                .containerBackground(for: .widget) { forecast.hasRain ? palette.stack : palette.stackDry }
        case .accessoryCorner:
            RainGlyphs.text(forecast, palette: palette)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .widgetAccentable()
                .widgetCurvesContent()
                .widgetLabel { Text(RainCopy(forecast).short) }
                .containerBackground(for: .widget) { Color.clear }
        default:
            ViewThatFits {
                Text("\(RainCopy(forecast).short) \(RainGlyphs.string(forecast))")
                Text(RainCopy(forecast).short)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    @ViewBuilder private var problem: some View {
        let message = entry.problem ?? "No forecast"
        switch family {
        case .accessoryCircular:
            // Apple's own gauges show "--" when they have no value.
            Text("--")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .widgetLabel(message)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            Label(message, systemImage: "drop")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .containerBackground(for: .widget) { palette.stackDry }
        default:
            Text(message)
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}

/// Corner only, an experiment: the Buienradar line itself along the edge. `widgetCurvesContent`
/// curves text, SF Symbols and images, so the curve goes in as thin image slices inside one
/// `Text`, in the hope that the system turns each slice to follow the edge.
struct RainLineCornerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "rain-line", provider: RainProvider()) { entry in
            RainLineCornerView(entry: entry)
        }
        .configurationDisplayName("Rain line")
        .description("Buienradar's rain line along the edge.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct RainLineCornerView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: RainEntry

    var body: some View {
        let palette: RainPalette = renderingMode == .fullColor ? .fullColour : .tinted(.white)
        Group {
            if let forecast = entry.forecast {
                Self.lineSlices(forecast, palette: palette)
                    .widgetAccentable()
                    .widgetCurvesContent()
                    .widgetLabel { Text(RainCopy(forecast).short) }
            } else {
                Text(entry.problem ?? "No forecast")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    @MainActor
    static func lineSlices(_ forecast: RainForecast, palette: RainPalette, slices: Int = 24) -> Text {
        let slice = CGSize(width: 3, height: 13)
        return (0..<slices).reduce(Text("")) { text, index in
            let renderer = ImageRenderer(content:
                ZStack(alignment: .bottom) {
                    RainArea(forecast: forecast).fill(palette.rain)
                    Rectangle().fill(palette.baseline).frame(height: 1.5)
                }
                .frame(width: slice.width * CGFloat(slices), height: slice.height)
                .offset(x: -slice.width * CGFloat(index))
                .frame(width: slice.width, height: slice.height, alignment: .leading)
                .clipped()
            )
            renderer.scale = 2
            guard let image = renderer.cgImage else { return text }
            return text + Text(Image(decorative: image, scale: 2))
        }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    RainWidget()
} timeline: {
    for scenario in Scenario.allCases {
        RainEntry(date: Scenario.start, forecast: scenario.forecast)
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    RainWidget()
} timeline: {
    for scenario in Scenario.allCases {
        RainEntry(date: Scenario.start, forecast: scenario.forecast)
    }
}
