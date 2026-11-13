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
    enum Problem {
        /// The last forecast is too old to count down from.
        case stale(since: Date)
        case noLocation
        case noForecast
    }

    let date: Date
    /// Nil when there is no forecast to show; `problem` then says why.
    let forecast: RainForecast?
    var problem: Problem?

    /// The Smart Stack raises the widget when rain is forecast within the two hours.
    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: forecast?.hasRain == true ? 1 : 0)
    }
}

/// Each reload fetches Buienradar once and writes an entry for every minute until the forecast is
/// 30 minutes old, then a stale entry that withdraws the countdown. It asks to be reloaded after
/// 15 minutes; watchOS reloads complications on the active face about every 15 to 20. If a reload
/// is late or fails, the stale entry still appears on time, because entries show at their own dates.
struct RainProvider: TimelineProvider {
    static let reloadAfter: TimeInterval = 15 * 60

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
        let place: Place.Found
        do {
            place = try await Place.current()
        } catch {
            ReloadLog.record("no location")
            return timeline(cached: Snapshot.saved, otherwise: .noLocation, now: now)
        }
        let source = place.isLive ? "live" : "saved \(RainCopy.clock(place.at))"
        do {
            let snapshot = try await Snapshot.fetch(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, now: now)
            ReloadLog.record("fetched, location \(source)")
            return timeline(snapshot, now: now)
        } catch {
            ReloadLog.record("fetch failed, location \(source): \(error.localizedDescription)")
            return timeline(cached: Snapshot.saved, otherwise: .noForecast, now: now)
        }
    }

    static func timeline(_ snapshot: Snapshot, now: Date) -> Timeline<RainEntry> {
        var entries = snapshot.forecasts(from: now).map { RainEntry(date: $0.now, forecast: $0) }
        entries.append(RainEntry(date: max(snapshot.staleAt, now), forecast: nil, problem: .stale(since: snapshot.fetched)))
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(reloadAfter)))
    }

    private static func timeline(cached: Snapshot?, otherwise problem: RainEntry.Problem, now: Date) -> Timeline<RainEntry> {
        if let cached { return timeline(cached, now: now) }
        return Timeline(entries: [RainEntry(date: now, forecast: nil, problem: problem)], policy: .after(now.addingTimeInterval(reloadAfter)))
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
                // Bars only when there is rain; a dry row of bars reads as an underline.
                Text(forecast.hasRain ? "\(RainCopy(forecast).short) \(RainGlyphs.string(forecast))" : RainCopy(forecast).short)
                Text(RainCopy(forecast).short)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    /// What the widget shows without a forecast it can trust, in the same layout as the forecast.
    @ViewBuilder private var problem: some View {
        let (headline, detail, short) = problemText
        switch family {
        case .accessoryCircular:
            // Apple's own gauges show "--" when they have no value.
            VStack(spacing: 0) {
                Text("--")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                if let short {
                    Text(short)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(headline, systemImage: "drop")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(detail)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { palette.stackDry }
        default:
            Text(headline)
                .containerBackground(for: .widget) { Color.clear }
        }
    }

    private var problemText: (headline: String, detail: String, short: String?) {
        switch entry.problem {
        case let .stale(since):
            ("Last forecast \(RainCopy.clock(since))", "Open Rain to refresh", RainCopy.clock(since))
        case .noLocation:
            ("Location needed", "Open Rain to share it", nil)
        case .noForecast, nil:
            ("No forecast", "Buienradar can't be reached", nil)
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
                Text("No forecast")
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
