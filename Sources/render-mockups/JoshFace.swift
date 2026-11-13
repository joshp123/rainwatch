import AppKit
import RainGraph
import SwiftUI

/// Josh's own Modular Ultra face (a watch screenshot from 5 November), with the rain widgets put
/// into its slots at true size, next to Apple's own complications. Slot positions were measured
/// from the screenshot.
struct JoshFace: View {
    let screenshot: NSImage
    let forecast: RainForecast
    var growth: CircularRainGauge.Growth = .outward

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
            CircularRainGauge(forecast: forecast, palette: .fullColour, growth: growth)
                .frame(width: 45, height: 45)
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
