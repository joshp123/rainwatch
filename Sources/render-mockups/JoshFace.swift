import AppKit
import RainGraph
import SwiftUI

/// Josh's own Modular Ultra face (a watch screenshot from 5 November), with the rain widgets put
/// into its slots at true size, next to Apple's own complications. Slot positions were measured
/// from the screenshot.
struct JoshFace: View {
    /// The screenshot shows 14:13 on Friday 13 November.
    static let clock: Date = Scenario.start.addingTimeInterval(43 * 60)

    let screenshot: NSImage
    let forecast: RainForecast
    var middle: CircularRainGauge.Middle = .minutes

    static let topMiddleSlot = CGPoint(x: 105.5, y: 38.5)
    static let largeSlot = CGRect(x: 12, y: 117, width: 190, height: 78)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: screenshot)
                .resizable()
                .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
            Circle().fill(.black)
                .frame(width: 48, height: 48)
                .position(Self.topMiddleSlot)
            CircularRainGauge(forecast: forecast, palette: .fullColour, middle: middle)
                .frame(width: Ultra3.circular, height: Ultra3.circular)
                .position(Self.topMiddleSlot)
            Rectangle().fill(.black)
                .frame(width: 204, height: 80)
                .position(x: Self.largeSlot.midX, y: Self.largeSlot.midY)
            RectangularRainView(forecast: forecast, palette: .fullColour)
                .frame(width: Self.largeSlot.width, height: Self.largeSlot.height)
                .position(x: Self.largeSlot.midX, y: Self.largeSlot.midY)
        }
        .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
        .clipShape(RoundedRectangle(cornerRadius: Ultra3.cornerRadius, style: .continuous))
    }
}

/// Josh's face as his Ultra 3 drew it on 13 November (`renders/watch/face.png`), with the circle
/// redrawn in the bottom middle slot, where he put Rain, between Apple's Sunrise and World Clock.
struct RealFace: View {
    let screenshot: NSImage
    let forecast: RainForecast

    static let bottomMiddleSlot = CGPoint(x: 105.5, y: 217)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: screenshot)
                .resizable()
                .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
            Circle().fill(.black)
                .frame(width: 52, height: 52)
                .position(Self.bottomMiddleSlot)
            CircularRainGauge(forecast: forecast, palette: .fullColour, plate: true)
                .frame(width: Ultra3.circular, height: Ultra3.circular)
                .position(Self.bottomMiddleSlot)
        }
        .frame(width: Ultra3.screen.width, height: Ultra3.screen.height)
    }
}

/// The bottom row of the real face, enlarged, for each kind of forecast.
struct RealFaceRow: View {
    let screenshot: NSImage
    static let scenarios: [Scenario] = [.dry, .showerComing, .drizzleStops, .rainingEasing, .rainAllWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Self.scenarios, id: \.self) { scenario in
                HStack(spacing: 16) {
                    RealFace(screenshot: screenshot, forecast: scenario.forecast)
                        .frame(width: Ultra3.screen.width, height: 64, alignment: .bottom)
                        .clipped()
                    Text(scenario.rawValue)
                        .font(RainFont.rounded(11, .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 110, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(.black)
    }
}
