import SwiftUI

/// The sparkline as text, for the places WidgetKit only curves text: the corner edge, the
/// Infograph bezel and inline slots. One block per slot, its height the slot's highest rain.
public enum RainGlyphs {
    static let blocks: [Character] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    /// 0 is dry. Any rain is at least 1, so drizzle sits visibly above the dry blocks.
    public static func levels(_ forecast: RainForecast, slots: Int = 8) -> [Int] {
        let perSlot = Int(RainForecast.window / RainForecast.step) / slots
        return (0..<slots).map { slot in
            let heights = forecast.samples.dropFirst(slot * perSlot).prefix(perSlot).map(\.height)
            guard let peak = heights.max(), peak > 0 else { return 0 }
            return 1 + Int(min(peak, 100) / 100 * 6.999)
        }
    }

    public static func string(_ forecast: RainForecast, slots: Int = 8) -> String {
        String(levels(forecast, slots: slots).map { blocks[$0] })
    }

    public static func text(_ forecast: RainForecast, palette: RainPalette, slots: Int = 8) -> Text {
        levels(forecast, slots: slots).reduce(Text("")) { text, level in
            text + Text(String(blocks[level])).foregroundStyle(level == 0 ? palette.baseline : palette.rain)
        }
    }
}
