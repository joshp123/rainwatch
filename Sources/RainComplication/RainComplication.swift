#if os(watchOS)
import RainGraph
import SwiftUI
import WidgetKit

public struct RainEntry: TimelineEntry {
    public let date: Date
    public let forecast: RainForecast
}

/// Mock-up provider with fixed data. The real one fetches Buienradar's three-hour graph once and
/// returns an entry every five minutes, each showing now to two hours, so the line stays current
/// between the system's widget reloads.
struct RainProvider: TimelineProvider {
    func placeholder(in context: Context) -> RainEntry {
        RainEntry(date: Scenario.start, forecast: Scenario.showerComing.forecast)
    }

    func getSnapshot(in context: Context, completion: @escaping (RainEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RainEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

public struct RainWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "rain", provider: RainProvider()) { entry in
            RainComplicationView(forecast: entry.forecast)
        }
        .configurationDisplayName("Rain")
        .description("Buienradar rain for the next two hours.")
        .supportedFamilies([.accessoryCorner, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Corner only, untested on a device: the Buienradar line itself along the edge.
/// `widgetCurvesContent` curves text, SF Symbols and images, so the curve goes in as thin image
/// slices inside one `Text`, hoping the system turns each slice to follow the edge.
public struct RainLineCornerWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "rain-line", provider: RainProvider()) { entry in
            RainLineCornerView(forecast: entry.forecast)
        }
        .configurationDisplayName("Rain line")
        .description("Buienradar's rain line along the edge.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct RainLineCornerView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let forecast: RainForecast

    var body: some View {
        let palette: RainPalette = renderingMode == .fullColor ? .fullColour : .tinted(.white)
        Self.lineSlices(forecast, palette: palette)
            .widgetAccentable()
            .widgetCurvesContent()
            .widgetLabel {
                Text(RainCopy(forecast).short)
            }
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

struct RainComplicationView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let forecast: RainForecast

    private var palette: RainPalette {
        renderingMode == .fullColor ? .fullColour : .tinted(.white)
    }

    var body: some View {
        switch family {
        case .accessoryCorner:
            // The sparkline follows the edge; the words sit inside it.
            RainGlyphs.text(forecast, palette: palette)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .widgetAccentable()
                .widgetCurvesContent()
                .widgetLabel {
                    Text(RainCopy(forecast).short)
                }
        case .accessoryCircular:
            CircularRainGauge(forecast: forecast, palette: palette)
                .widgetLabel {
                    // Drawn along the bezel only in Infograph's top slot; ignored elsewhere.
                    Text("\(RainCopy(forecast).short)  \(RainGlyphs.string(forecast, slots: 12))")
                }
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularRainView(forecast: forecast, palette: palette)
                .containerBackground(for: .widget) { forecast.hasRain ? palette.stack : palette.stackDry }
        case .accessoryInline:
            ViewThatFits {
                Text("\(RainCopy(forecast).short) \(RainGlyphs.string(forecast))")
                Text(RainCopy(forecast).short)
            }
        default:
            EmptyView()
        }
    }
}

#Preview("Corner", as: .accessoryCorner) {
    RainWidget()
} timeline: {
    for scenario in Scenario.allCases {
        RainEntry(date: Scenario.start, forecast: scenario.forecast)
    }
}

#Preview("Corner line", as: .accessoryCorner) {
    RainLineCornerWidget()
} timeline: {
    for scenario in Scenario.allCases {
        RainEntry(date: Scenario.start, forecast: scenario.forecast)
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

#Preview("Inline", as: .accessoryInline) {
    RainWidget()
} timeline: {
    for scenario in Scenario.allCases {
        RainEntry(date: Scenario.start, forecast: scenario.forecast)
    }
}
#endif
