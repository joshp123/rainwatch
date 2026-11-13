import AppKit
import RainGraph
import SwiftUI

let arguments = Array(CommandLine.arguments.dropFirst())
let output = URL(fileURLWithPath: arguments.first ?? "renders", isDirectory: true)
let screenshot = arguments.count > 1 ? NSImage(contentsOfFile: arguments[1]) : nil
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

@MainActor
func render(_ view: some View, to name: String, scale: CGFloat = 3) throws {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    try data?.write(to: output.appendingPathComponent(name))
    print(output.appendingPathComponent(name).path)
}

struct Caption: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(RainFont.rounded(12, .semibold)).foregroundStyle(.white.opacity(0.9))
            if let detail {
                Text(detail).font(RainFont.rounded(10, .medium)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

/// Every family for every forecast, at Ultra 3 size.
struct FamilySheet: View {
    let palette: RainPalette

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 20) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                Caption(title: "Circular", detail: "Modular Ultra")
                Caption(title: "Rectangular", detail: "Modular Ultra")
                Caption(title: "Smart Stack", detail: "Turn the crown")
                Caption(title: "Corner", detail: "Wayfinder, Waypoint")
                Caption(title: "Inline", detail: "Top line")
            }
            ForEach(Scenario.allCases, id: \.self) { scenario in
                let forecast = scenario.forecast
                GridRow(alignment: .center) {
                    Caption(title: scenario.rawValue)
                        .frame(width: 120, alignment: .leading)
                    CircularMock(forecast: forecast, palette: palette)
                    RectangularMock(forecast: forecast, palette: palette)
                    SmartStackMock(forecast: forecast, palette: palette)
                    CornerTile { CornerMock(forecast: forecast, palette: palette) }
                    InlineMock(forecast: forecast, palette: palette)
                }
            }
        }
        .padding(28)
        .background(.black)
    }
}

/// The top-left corner of the Ultra screen.
struct CornerTile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: 100, height: 92, alignment: .topLeading)
            .background(alignment: .topLeading) {
                UnevenRoundedRectangle(topLeadingRadius: Ultra3.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 140, height: 130)
            }
            .clipped()
    }
}

/// The two circular variants on Josh's own face, for the forecasts that look most different.
struct FaceSheet: View {
    let screenshot: NSImage
    static let scenarios: [Scenario] = [.dry, .showerComing, .drizzleStops, .rainingEasing, .rainAllWindow]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                ForEach(Self.scenarios, id: \.self) { Caption(title: $0.rawValue) }
            }
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                ForEach(Self.scenarios, id: \.self) { scenario in
                    JoshFace(screenshot: screenshot, forecast: scenario.forecast)
                }
            }
        }
        .padding(24)
        .background(.black)
    }
}

/// The circular gauge alone, large, to judge the drawing.
struct CircularDetail: View {
    var body: some View {
        Grid(horizontalSpacing: 22, verticalSpacing: 18) {
            ForEach([RainPalette.fullColour, .nightMode].indices, id: \.self) { index in
                GridRow {
                    ForEach(Scenario.allCases, id: \.self) { scenario in
                        VStack(spacing: 8) {
                            CircularRainGauge(forecast: scenario.forecast, palette: [RainPalette.fullColour, .nightMode][index])
                                .frame(width: 45, height: 45)
                                .scaleEffect(2.4)
                                .frame(width: 108, height: 108)
                            Text(scenario.rawValue)
                                .font(RainFont.rounded(10, .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 108)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(.black)
    }
}

/// The two middles for the circular gauge, enlarged and on Josh's face at true size.
struct MiddleComparison: View {
    let screenshot: NSImage
    static let scenarios: [Scenario] = [.dry, .showerComing, .drizzleStops, .rainingEasing, .rainComing, .rainAllWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach([CircularRainGauge.Middle.minutes, .none], id: \.self) { middle in
                HStack(alignment: .center, spacing: 18) {
                    Caption(title: middle == .minutes ? "Minutes" : "Graph only",
                            detail: middle == .minutes ? "until the dot" : "whole circle for the line")
                        .frame(width: 110, alignment: .leading)
                    ForEach(Self.scenarios, id: \.self) { scenario in
                        CircularRainGauge(forecast: scenario.forecast, palette: .fullColour, middle: middle)
                            .frame(width: 45, height: 45)
                            .scaleEffect(2.2)
                            .frame(width: 100, height: 100)
                    }
                    JoshFace(screenshot: screenshot, forecast: Scenario.rainComing.forecast, middle: middle)
                        .frame(width: Ultra3.screen.width, height: 80, alignment: .top)
                        .clipped()
                }
            }
            HStack(spacing: 18) {
                Color.clear.frame(width: 110, height: 1)
                ForEach(Self.scenarios, id: \.self) { scenario in
                    Text(scenario.rawValue)
                        .font(RainFont.rounded(10, .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                }
                Text("True size on your face (Oslo)")
                    .font(RainFont.rounded(10, .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: Ultra3.screen.width)
            }
        }
        .padding(24)
        .background(.black)
    }
}

/// The app's first page at Ultra 3 size, with the watch's own title bar: place on the left in the
/// app's tint, time on the right.
struct AppScreen: View {
    let scenario: Scenario

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            HStack {
                Text(scenario.place)
                    .foregroundStyle(RainPalette.buienradarBlue)
                Spacer()
                Text("13:30")
                    .foregroundStyle(.white)
            }
            .font(RainFont.rounded(16, .semibold))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            ForecastDetailView(forecast: scenario.forecast, fetched: Scenario.start)
                .padding(.horizontal, 10)
                .padding(.top, 38)
                .padding(.bottom, 12)
        }
        .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
        .clipShape(RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous))
    }
}

struct AppSheet: View {
    static let scenarios: [Scenario] = [.showerComing, .drizzleStops, .rainingEasing, .rainAllWindow, .dry]

    var body: some View {
        HStack(spacing: 22) {
            ForEach(Self.scenarios, id: \.self) { AppScreen(scenario: $0) }
        }
        .padding(24)
        .background(Color(white: 0.12))
    }
}

try MainActor.assumeIsolated {
    try render(AppSheet(), to: "app-now.png", scale: 2)
    if let screenshot {
        try render(MiddleComparison(screenshot: screenshot), to: "circular-middles.png")
    }
    if let screenshot {
        try render(FaceSheet(screenshot: screenshot), to: "on-your-face.png", scale: 2)
        for scenario in [Scenario.showerComing, .drizzleStops] {
            try render(JoshFace(screenshot: screenshot, forecast: scenario.forecast), to: "face-\(scenario).png", scale: 2)
        }
    }
    try render(CircularDetail(), to: "circular-detail.png")
    try render(FamilySheet(palette: .fullColour), to: "families.png")
    try render(FamilySheet(palette: .nightMode), to: "families-night-mode.png")
}
