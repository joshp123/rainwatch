import RainGraph
import SwiftUI

/// Apple Watch Ultra 3 screen in points (422×514 px at 2x).
enum Ultra3 {
    static let screen = CGSize(width: 211, height: 257)
    static let cornerRadius: CGFloat = 46
    static var centre: CGPoint { CGPoint(x: screen.width / 2, y: screen.height / 2) }
    /// Circular slot on Josh's Modular Ultra face, measured on his watch on 14 November: 45 points,
    /// the size of the grey disc. Apple's guidelines say 50 for 49 mm watches; the face uses less.
    static let circular: CGFloat = 45
    static let rectangular = CGSize(width: 193, height: 82)
    static let smartStack = CGSize(width: 198, height: 81.5)
}

/// Corner family on the Ultra: the headline curved along the edge, and a drop in the corner,
/// filled when rain is due. The arcs are centred on the screen.
struct CornerMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        let mid = Angle.degrees(231)
        ZStack {
            Image(systemName: forecast.hasRain ? "drop.fill" : "drop")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.rain)
                .position(x: Ultra3.centre.x + 86 * cos(mid.radians), y: Ultra3.centre.y + 86 * sin(mid.radians))
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
            radius: 112,
            midAngle: midAngle,
            maxSweep: .degrees(40)
        )
    }
}

struct CircularMock: View {
    let forecast: RainForecast
    let palette: RainPalette

    var body: some View {
        CircularRainGauge(forecast: forecast, palette: palette, plate: true)
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
        // The inline slot across the top of Siri Modular: the headline alone.
        Text(RainCopy(forecast).short)
        .font(RainFont.rounded(14, .semibold))
        .foregroundStyle(palette.primary)
        .lineLimit(1)
        .frame(width: 180, alignment: .leading)
    }
}

