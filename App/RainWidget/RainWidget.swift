import RainGraph
import SwiftUI
import WidgetKit

@main
struct RainWidgets: WidgetBundle {
    var body: some Widget {
        RainWidget()
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
    /// When the forecast was fetched, so an old one can say so.
    var fetched: Date?

    /// The Smart Stack raises the widget while it rains, and more the sooner rain arrives.
    var relevance: TimelineEntryRelevance? {
        guard let forecast, forecast.hasRain else { return TimelineEntryRelevance(score: 0) }
        let copy = RainCopy(forecast)
        guard !copy.isRainingNow, let minutes = copy.minutesLeft else { return TimelineEntryRelevance(score: 1) }
        return TimelineEntryRelevance(score: Float(max(0.2, 1 - Double(minutes) / 120)))
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
        #if DEBUG
        // Set by the app's `-scenario` launch option, to check every state on the real face. It
        // lapses after ten minutes, so a forgotten test never stays on the wrist.
        let defaults = UserDefaults(suiteName: Place.appGroup)
        if let name = defaults?.string(forKey: "debugScenario"),
           let set = defaults?.object(forKey: "debugScenarioSet") as? Date, now.timeIntervalSince(set) < 600,
           let scenario = Scenario.allCases.first(where: { "\($0)" == name }) {
            return Timeline(entries: [RainEntry(date: now, forecast: scenario.forecast(at: now))],
                            policy: .after(set.addingTimeInterval(600)))
        }
        #endif
        let place: Place.Found
        do {
            place = try await Place.current(mayAsk: false)
        } catch {
            ReloadLog.record("no location")
            return timeline(cached: Snapshot.saved, otherwise: .noLocation, now: now)
        }
        let source = place.chosen.map { "chosen \($0.name)" } ?? (place.isLive ? "live" : "saved \(RainCopy.clock(place.at))")
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
        var entries = snapshot.forecasts(from: now).map { RainEntry(date: $0.now, forecast: $0, fetched: snapshot.fetched) }
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
        .configurationDisplayName(Bundle.main.displayName)
        .description("Rain for the next two hours.")
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
            // The grey disc Apple's own complications sit on, so Rain's edge is as clear as theirs.
            ZStack {
                AccessoryWidgetBackground()
                CircularRainGauge(forecast: forecast, palette: palette)
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularRainView(forecast: forecast, palette: palette, fetched: entry.fetched)
                .containerBackground(for: .widget) { forecast.hasRain ? palette.stack : palette.stackDry }
        case .accessoryCorner:
            // Words along the edge; a drop in the corner, filled when rain is due.
            Image(systemName: forecast.hasRain ? "drop.fill" : "drop")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.rain)
                .widgetAccentable()
                .widgetLabel { Text(RainCopy(forecast).short) }
                .containerBackground(for: .widget) { Color.clear }
        default:
            Text(RainCopy(forecast).short)
                .containerBackground(for: .widget) { Color.clear }
        }
    }

    /// What the widget shows without a forecast it can trust, in the same layout as the forecast.
    @ViewBuilder private var problem: some View {
        let (headline, detail, short) = problemText
        switch family {
        case .accessoryCircular:
            // Two lines at the sizes "Dry" uses. A bare clock time here read as a second clock.
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("No")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(short ?? "DATA")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.rain)
                        .widgetAccentable()
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
            ("Last forecast \(RainCopy.clock(since))", "Open Rain to refresh", "DATA")
        case .noLocation:
            ("Location needed", "Open Rain to share it", "PLACE")
        case .noForecast, nil:
            ("No forecast", "Buienradar can't be reached", "DATA")
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
