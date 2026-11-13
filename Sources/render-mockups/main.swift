import AppKit
import RainGraph
import SwiftUI

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "renders", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

@MainActor
func render(_ view: some View, to name: String) throws {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = 3
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

/// Every family for every scenario, at Ultra 3 size.
struct FamilySheet: View {
    let palette: RainPalette

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 20) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                Caption(title: "Corner: glyphs", detail: "Wayfinder, Waypoint")
                Caption(title: "Corner: line", detail: "Needs device test")
                Caption(title: "Circular", detail: "Most faces")
                Caption(title: "Rectangular", detail: "Modular Ultra")
                Caption(title: "Smart Stack", detail: "Scroll the crown")
                Caption(title: "Inline", detail: "Top line")
            }
            ForEach(Scenario.allCases, id: \.self) { scenario in
                let forecast = scenario.forecast
                GridRow(alignment: .center) {
                    Caption(title: scenario.rawValue)
                        .frame(width: 112, alignment: .leading)
                    CornerTile { CornerMock(forecast: forecast, palette: palette) }
                    CornerTile { CornerLineMock(forecast: forecast, palette: palette) }
                    CircularMock(forecast: forecast, palette: palette)
                    RectangularMock(forecast: forecast, palette: palette)
                    SmartStackMock(forecast: forecast, palette: palette)
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

struct FaceSheet: View {
    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            let shower = Scenario.showerComing.forecast
            let downpour = Scenario.downpour.forecast
            face("Corner glyphs, shower coming", CornerFace(forecast: shower, palette: .fullColour) {
                CornerMock(forecast: shower, palette: .fullColour)
            })
            face("Corner line, shower coming", CornerFace(forecast: shower, palette: .fullColour) {
                CornerLineMock(forecast: shower, palette: .fullColour)
            })
            face("Night Mode, downpour", CornerFace(forecast: downpour, palette: .nightMode) {
                CornerLineMock(forecast: downpour, palette: .nightMode)
            })
            face("Modular, raining then dry", ModularFace(forecast: Scenario.stoppingSoon.forecast, palette: .fullColour))
            face("Modular, tinted face", ModularFace(forecast: shower, palette: .tinted(.orange)))
        }
        .padding(28)
        .background(.black)
    }

    func face(_ title: String, _ face: some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(title: title)
            face
        }
    }
}

try MainActor.assumeIsolated {
    try render(FaceSheet(), to: "ultra-faces.png")
    try render(FamilySheet(palette: .fullColour), to: "families.png")
    try render(FamilySheet(palette: .nightMode), to: "families-night-mode.png")
}
