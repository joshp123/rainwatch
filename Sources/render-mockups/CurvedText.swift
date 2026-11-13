import SwiftUI

/// Draws text along a circle, tops of the letters outwards, reading clockwise.
/// Stands in for what WidgetKit does on the watch with `widgetCurvesContent` and `widgetLabel`.
struct CurvedText: View {
    struct Run {
        var string: String
        var color: Color
    }

    var runs: [Run]
    var font: Font
    var centre: CGPoint
    var radius: CGFloat
    var midAngle: Angle
    var tracking: CGFloat = 0.6
    /// Longer text shrinks to this sweep, as the watch fits a corner label to its corner.
    var maxSweep: Angle = .degrees(70)

    var body: some View {
        Canvas { context, _ in
            let glyphs = runs.flatMap { run in
                run.string.map { context.resolve(Text(String($0)).font(font).foregroundStyle(run.color)) }
            }
            let sizes = glyphs.map { $0.measure(in: CGSize(width: 200, height: 200)) }
            let natural = sizes.reduce(0) { $0 + $1.width } + tracking * CGFloat(max(0, glyphs.count - 1))
            let scale = min(1, CGFloat(maxSweep.radians) * radius / natural)
            var angle = midAngle.radians - Double(natural * scale / radius) / 2

            for (glyph, size) in zip(glyphs, sizes) {
                let half = Double(size.width * scale / 2 / radius)
                angle += half
                let baseline = glyph.firstBaseline(in: size)
                var g = context
                g.translateBy(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
                g.rotate(by: .radians(angle + .pi / 2))
                g.scaleBy(x: scale, y: scale)
                g.draw(glyph, at: CGPoint(x: -size.width / 2, y: -baseline), anchor: .topLeading)
                angle += half + Double(tracking * scale / radius)
            }
        }
    }
}
