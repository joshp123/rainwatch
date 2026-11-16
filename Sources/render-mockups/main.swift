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
                row(scenario.rawValue, scenario.forecast)
            }
            // The same KNMI run 45 minutes old: the line and the arc stop 75 minutes ahead.
            if let aged = RainForecast.at(Scenario.start.addingTimeInterval(35 * 60), from: Scenario.rainComing.forecast.samples) {
                row("Rain in 25 min, 45 min old", aged)
            }
            // Layout examples for Apple's data, not real forecasts: the minute forecast reaches an
            // hour, the hourly one rain by clock hour.
            row("Apple, next hour (example)", RainForecast(samples: Array(Scenario.rainComing.forecast.samples.prefix(12))), apple: true)
            row("Apple, hourly (example)", Self.hourly, apple: true)
        }
        .padding(28)
        .background(.black)
    }
}

extension FamilySheet {
    @ViewBuilder func row(_ title: String, _ forecast: RainForecast, apple: Bool = false) -> some View {
        GridRow(alignment: .center) {
            Caption(title: title)
                .frame(width: 120, alignment: .leading)
            CircularMock(forecast: forecast, palette: palette)
            RectangularMock(forecast: forecast, palette: palette, appleWeather: apple)
            SmartStackMock(forecast: forecast, palette: palette, appleWeather: apple)
            CornerTile { CornerMock(forecast: forecast, palette: palette) }
            InlineMock(forecast: forecast, palette: palette)
        }
    }

    /// Dry until the next hour, then an hour of light rain, from 13:45.
    static var hourly: RainForecast {
        let hour = Calendar.current.dateInterval(of: .hour, for: Scenario.start)!.start
        let rates: [Double] = [0, 0.8, 0]
        let samples = (0..<36).map { RainSample(date: hour.addingTimeInterval(Double($0) * RainForecast.step), rate: rates[$0 / 12]) }
        return RainForecast.at(Scenario.start, from: samples, resolution: .hourly)!
    }
}

/// The top-left corner of the Ultra screen.
struct CornerTile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: 100, height: 92, alignment: .topLeading)
            .background(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
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
                    JoshFace(screenshot: screenshot, forecast: scenario.forecast(at: JoshFace.clock))
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
        Grid(alignment: .top, horizontalSpacing: 22, verticalSpacing: 18) {
            ForEach([RainPalette.fullColour, .nightMode].indices, id: \.self) { index in
                GridRow {
                    ForEach(Scenario.allCases, id: \.self) { scenario in
                        VStack(spacing: 8) {
                            CircularRainGauge(forecast: scenario.forecast, palette: [RainPalette.fullColour, .nightMode][index], plate: true)
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
                    JoshFace(screenshot: screenshot, forecast: Scenario.rainComing.forecast(at: JoshFace.clock), middle: middle)
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
                Text("True size on your face (Alkmaar)")
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
            ForecastDetailView(forecast: scenario.forecast, issued: Scenario.start)
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
    if let screenshot {
        try render(MiddleComparison(screenshot: screenshot), to: "circular-middles.png")
    }
    if let screenshot {
        try render(FaceSheet(screenshot: screenshot), to: "on-your-face.png", scale: 2)
        for scenario in [Scenario.showerComing, .drizzleStops] {
            try render(JoshFace(screenshot: screenshot, forecast: scenario.forecast(at: JoshFace.clock)), to: "face-\(scenario).png", scale: 2)
        }
    }
    try render(CircularDetail(), to: "circular-detail.png")
    try render(FamilySheet(palette: .fullColour), to: "families.png")
    try render(FamilySheet(palette: .nightMode), to: "families-night-mode.png")
}
