import CoreLocation
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
    let date: Date
    /// Nil when there is no forecast to show; `problem` then says why.
    let forecast: RainForecast?
    var problem: Problem?
    /// When the data was made, so an old forecast can say so.
    var issued: Date?
    var source: Snapshot.Source?

    /// The Smart Stack raises the widget while it rains, and more the sooner rain arrives.
    var relevance: TimelineEntryRelevance? {
        guard let forecast, forecast.hasRain else { return TimelineEntryRelevance(score: 0) }
        let copy = RainCopy(forecast)
        guard !copy.isRainingNow, let minutes = copy.minutesLeft else { return TimelineEntryRelevance(score: 1) }
        return TimelineEntryRelevance(score: Float(max(0.2, 1 - Double(minutes) / 120)))
    }
}

/// Each reload fetches once (KNMI's square from our server, or Apple's forecast outside KNMI's area)
/// and writes an entry for every minute until the data is an hour old, then a stale entry that
/// withdraws the countdown. It asks to be reloaded after 15 minutes; watchOS reloads complications
/// on the active face about every 15 to 20. If a reload is late or fails, the stale entry still
/// appears on time, because entries show at their own dates.
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
        let family = "\(context.family)"
        Task {
            // watchOS does not say why it reloads; the app logs when it asked for one.
            Log.event("timeline asked (\(family))")
            completion(await Log.stage("Timeline") { await Self.timeline(now: .now) })
        }
    }

    static func timeline(now: Date) async -> Timeline<RainEntry> {
        #if DEBUG
        // Set by the app's `-scenario` launch option, to check every state on the real face. It
        // lapses after ten minutes, so a forgotten test never stays on the wrist.
        let defaults = UserDefaults(suiteName: Place.appGroup)
        if let name = defaults?.string(forKey: "debugScenario"),
           let set = defaults?.object(forKey: "debugScenarioSet") as? Date, now.timeIntervalSince(set) < 600,
           let entry = debugEntry(name, age: defaults?.integer(forKey: "debugAge") ?? 0, set: set, now: now) {
            return Timeline(entries: [entry], policy: .after(set.addingTimeInterval(600)))
        }
        #endif
        let place: Place.Found
        do {
            place = try await Place.current(mayAsk: false)
        } catch {
            // Never the forecast for where the wearer last was: with location refused, that is
            // not where they are.
            let problem = Problem(error as? Place.Failure ?? .notFound)
            Log.event("timeline: problem \(problem), next reload in \(Int(reloadAfter / 60)) min")
            return Timeline(entries: [RainEntry(date: now, forecast: nil, problem: problem)],
                            policy: .after(now.addingTimeInterval(reloadAfter)))
        }
        // A fix is where the wearer was. An hour after it the face has no place, on time even if
        // watchOS reloads late, as an hour-old forecast is withdrawn on time.
        let placeExpires = place.chosen == nil ? place.at.addingTimeInterval(Place.trustFor) : nil
        let fetch: Situation.Fetch
        do {
            let snapshot = try await Snapshot.fetch(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, now: now)
            fetch = .fetched(snapshot)
        } catch Snapshot.Failure.offline {
            fetch = .unreachable
        } catch {
            fetch = .refused
        }
        // The same rules as the app (`Situation.after`): a saved forecast stands in for a failed
        // fetch only if it is for this place and under an hour old.
        let situation = Situation.after(fetch, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, saved: Snapshot.saved, now: now)
        let entries: [RainEntry]
        switch situation {
        case let .forecast(_, snapshot, _):
            // Once Allow Once has run out, the next reload finds no place and says Location Expired.
            entries = Situation.schedule(snapshot, now: now, placeExpires: placeExpires)
                .map { RainEntry(date: $0.date, situation: $0.situation) }
        case .problem:
            entries = [RainEntry(date: now, situation: situation)]
        }
        Log.event("timeline: \(Self.describe(entries)), next reload in \(Int(reloadAfter / 60)) min")
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(reloadAfter)))
    }

    /// The states a timeline moves through, for the log: "forecast for 42 min, then problem ...".
    private static func describe(_ entries: [RainEntry]) -> String {
        var parts: [String] = []
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            var end = index
            while end + 1 < entries.count, (entries[end + 1].forecast == nil) == (entry.forecast == nil) { end += 1 }
            let minutes = Int(entries[end].date.timeIntervalSince(entry.date) / 60) + 1
            if entry.forecast != nil {
                parts.append("forecast (\(entry.source?.rawValue ?? "?"), data \(entry.issued.map { Log.age(of: $0, now: entry.date) } ?? "?")) for \(minutes) min")
            } else {
                parts.append("problem \(entry.problem.map { "\($0)" } ?? "?")")
            }
            index = end + 1
        }
        return parts.joined(separator: ", then ")
    }

    #if DEBUG
    /// The face for a saved forecast, or for a state with none: `stale`, `noLocation`, `noForecast`.
    /// `age` makes the forecast that many minutes old, as the app's `-age` does.
    static func debugEntry(_ name: String, age: Int, set: Date, now: Date) -> RainEntry? {
        if let problem = Problem.named(name, launched: set) { return RainEntry(date: now, forecast: nil, problem: problem) }
        if let scenario = Scenario.allCases.first(where: { "\($0)" == name }) {
            let age = max(Scenario.age, Double(age) * 60)
            let run = Date(timeIntervalSince1970: ((set.timeIntervalSince1970 - age) / 300).rounded(.down) * 300)
            let forecast = RainForecast.at(now, from: scenario.forecast(at: run.addingTimeInterval(Scenario.age)).samples)
            return forecast.map { RainEntry(date: now, forecast: $0, issued: run, source: .knmi) }
        }
        if let scenario = AppleScenario.allCases.first(where: { "\($0)" == name }), let forecast = scenario.forecast(at: now) {
            return RainEntry(date: now, forecast: forecast, issued: now.addingTimeInterval(-Double(max(5, age)) * 60),
                             source: scenario.resolution == .hourly ? .appleHourly : .appleMinute)
        }
        return nil
    }
    #endif

}

extension RainEntry {
    init(date: Date, situation: Situation) {
        switch situation {
        case let .forecast(forecast, snapshot, _):
            self.init(date: date, forecast: forecast, issued: snapshot.issued, source: snapshot.source)
        case let .problem(problem):
            self.init(date: date, forecast: nil, problem: problem)
        }
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
        .description(Text(localized("When the next rain starts or stops.")))
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
        Group {
            if let forecast = entry.forecast {
                view(for: forecast)
            } else {
                problem
            }
        }
        .hidesTextForDesign(Self.hidesText)
    }

    #if DEBUG
    static var hidesText: Bool { UserDefaults(suiteName: Place.appGroup)?.bool(forKey: "debugHideText") ?? false }
    #else
    static let hidesText = false
    #endif

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
            RectangularRainView(forecast: forecast, palette: palette, issued: entry.issued, appleWeather: entry.source?.isApple ?? false)
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
                    Text(localized("No"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    // Grey, not blue: blue means rain, and nothing is known about rain here.
                    Text(short ?? localized("DATA"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondary)
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

    /// The face's words for a problem are the app's (`Problem`), so the two never disagree.
    private var problemText: (headline: String, detail: String, short: String?) {
        let problem = entry.problem ?? .forecastUnavailable
        return (problem.faceHeadline, problem.faceHint, problem.circleWord)
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
