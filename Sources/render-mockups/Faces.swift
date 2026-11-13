import RainGraph
import SwiftUI

/// Apple Watch Ultra 3 screen in points (422×514 px at 2x).
enum Ultra3 {
    static let screen = CGSize(width: 211, height: 257)
    static let cornerRadius: CGFloat = 46
    static var centre: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }
    /// Circular slot on Modular Ultra, measured from Josh's screenshot.
    static let circular: CGFloat = 45
    static let rectangular = CGSize(width: 193, height: 82)
    static let smartStack = CGSize(width: 198, height: 81.5)
}

/// Corner family on the Ultra, proven route: the sparkline as block glyphs, which the system
/// curves along the edge; the words sit inside. The arcs are centred on the screen.
struct CornerMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        let mid = Angle.degrees(231)
        let levels = RainGlyphs.levels(forecast)
        ZStack {
            CurvedText(
                runs: levels.map { .init(string: String(Array("▁▂▃▄▅▆▇█")[$0]), color: $0 == 0 ? palette.baseline : palette.rain) },
                font: RainFont.rounded(13, .semibold),
                centre: Ultra3.centre,
                radius: 112,
                midAngle: mid,
                tracking: 0.5,
                maxSweep: .degrees(34)
            )
            CornerLabel(forecast: forecast, palette: palette, midAngle: mid)
        }
        .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
    }
}

/// Corner family, untested route: the Buienradar line itself bent along the edge.
struct CornerLineMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        let mid = Angle.degrees(231)
        let outer: CGFloat = 124
        ZStack {
            Group {
                RadialRainArea(forecast: forecast, startAngle: mid - .degrees(17), sweep: .degrees(34), baseline: 110 / outer, full: 1)
                    .fill(palette.rain)
                ArcLine(startAngle: mid - .degrees(17), sweep: .degrees(34), radius: 110 / outer)
                    .stroke(palette.baseline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            .frame(width: outer * 2, height: outer * 2)
            .position(Ultra3.centre)
            CornerLabel(forecast: forecast, palette: palette, midAngle: mid)
        }
        .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
    }
}

struct CornerLabel: View {
    let forecast: RainForecast
    let palette: RainPalette
    let midAngle: Angle

    var body: some View {
        CurvedText(
            runs: [.init(string: RainCopy(forecast).short, color: palette.primary)],
            font: RainFont.rounded(12, .semibold),
            centre: Ultra3.centre,
            radius: 96,
            midAngle: midAngle,
            maxSweep: .degrees(40)
        )
    }
}

struct CircularMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        CircularRainGauge(forecast: forecast, palette: palette)
            .frame(width: Ultra3.circular, height: Ultra3.circular)
    }
}

struct RectangularMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        RectangularRainView(forecast: forecast, palette: palette)
            .padding(.bottom, 1)
            .frame(width: Ultra3.rectangular.width, height: Ultra3.rectangular.height)
    }
}

struct SmartStackMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        RectangularRainView(forecast: forecast, palette: palette)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(width: Ultra3.smartStack.width, height: Ultra3.smartStack.height)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(forecast.hasRain ? palette.stack : palette.stackDry))
    }
}

/// Inline slots draw one line of text in the face's colour; glyph colours do not survive.
struct InlineMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        // The inline slot across the top of Siri Modular; the watch drops the bars if they don't fit.
        ViewThatFits {
            Text(forecast.hasRain ? "\(RainCopy(forecast).short) \(RainGlyphs.string(forecast))" : RainCopy(forecast).short)
            Text(RainCopy(forecast).short)
        }
        .font(RainFont.rounded(14, .semibold))
        .foregroundStyle(palette.primary)
        .lineLimit(1)
        .frame(width: 180, alignment: .leading)
    }
}

