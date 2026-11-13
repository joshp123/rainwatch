import RainGraph
import SwiftUI

/// Apple Watch Ultra 3 screen in points (422×514 px at 2x).
enum Ultra3 {
    static let screen = CGSize(width: 211, height: 257)
    static let cornerRadius: CGFloat = 46
    static var centre: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }
    static let circular: CGFloat = 50
    static let rectangular = CGSize(width: 193, height: 82)
    static let smartStack = CGSize(width: 198, height: 81.5)
}

/// Corner family on the Ultra, proven route: the sparkline as block glyphs, which the system
/// curves along the edge; the words sit inside. The arcs are centred on the screen.
struct CornerMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        let mid = Angle.degrees(237)
        let levels = RainGlyphs.levels(forecast)
        ZStack {
            CurvedText(
                runs: levels.map { .init(string: String(Array("▁▂▃▄▅▆▇█")[$0]), color: $0 == 0 ? palette.baseline : palette.rain) },
                font: RainFont.rounded(13, .semibold),
                centre: Ultra3.centre,
                radius: 114,
                midAngle: mid,
                tracking: 0.5
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
        let mid = Angle.degrees(237)
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
            runs: [.init(string: forecast.outlook.short, color: palette.primary)],
            font: RainFont.rounded(12, .semibold),
            centre: Ultra3.centre,
            radius: 95,
            midAngle: midAngle
        )
    }
}

struct CircularMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        CircularRainView(forecast: forecast, palette: palette)
            .padding(1)
            .background(Circle().fill(palette.plate))
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
            .padding(.top, 8)
            .padding(.bottom, 7)
            .frame(width: Ultra3.smartStack.width, height: Ultra3.smartStack.height)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.stack))
    }
}

/// Inline slots draw one line of text in the face's colour; glyph colours do not survive.
struct InlineMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        Text("\(RainGlyphs.string(forecast)) \(forecast.outlook.short)")
            .font(RainFont.rounded(14, .semibold))
            .foregroundStyle(palette.primary)
            .fixedSize()
    }
}

struct ScreenShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous)
            .fill(.black)
            .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Ultra3.cornerRadius + 12, style: .continuous)
                    .fill(Color(white: 0.17))
            )
    }
}

/// A plain face with corner slots, like Wayfinder or Waypoint on the Ultra.
struct CornerFace<Corner: View>: View {
    let forecast: RainForecast
    let palette: RainPalette
    @ViewBuilder let corner: Corner

    var body: some View {
        ZStack {
            ScreenShape()
            ZStack {
                corner
                Text("13:05")
                    .font(RainFont.rounded(60, .semibold))
                    .foregroundStyle(palette.primary)
                    .monospacedDigit()
                    .position(x: Ultra3.centre.x, y: Ultra3.centre.y + 4)
                CircularMock(forecast: forecast, palette: palette)
                    .position(x: Ultra3.centre.x, y: Ultra3.screen.height - 44)
            }
            .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
            .clipShape(RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous))
        }
    }
}

/// A modular face like Modular Ultra or Siri Modular: top line, clock, large rectangular slot.
struct ModularFace: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        ZStack {
            ScreenShape()
            VStack(alignment: .leading, spacing: 8) {
                InlineMock(forecast: forecast, palette: palette)
                    .padding(.top, 16)
                    .padding(.leading, 8)
                HStack {
                    Text("13:05")
                        .font(RainFont.rounded(46, .semibold))
                        .foregroundStyle(palette.primary)
                        .monospacedDigit()
                    Spacer()
                    CircularMock(forecast: forecast, palette: palette)
                }
                RectangularMock(forecast: forecast, palette: palette)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
            .clipShape(RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous))
        }
    }
}
