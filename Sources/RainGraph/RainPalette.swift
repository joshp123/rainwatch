import SwiftUI
#if !os(watchOS)
import CoreText
#endif

/// Colours for one rendering mode. Height carries the meaning; colour only repeats it,
/// because tinted faces and Ultra Night Mode reduce everything to one hue.
public struct RainPalette: Sendable {
    public var rain: Color
    public var primary: Color
    public var secondary: Color
    public var baseline: Color
    public var grid: Color
    /// Stand-in for `AccessoryWidgetBackground` and the Smart Stack background.
    public var plate: Color
    public var stack: Color
    /// Smart Stack background when no rain is forecast, so the card's colour says rain or not.
    public var stackDry: Color = Color(white: 0.13)

    /// Buienradar's own graph fill (`fillColor` in its graph feed).
    public static let buienradarBlue = Color(red: 0x5A / 255, green: 0x9B / 255, blue: 0xD3 / 255)

    public static let fullColour = RainPalette(
        rain: buienradarBlue,
        primary: .white,
        secondary: .white.opacity(0.62),
        baseline: .white.opacity(0.38),
        grid: .white.opacity(0.16),
        plate: .white.opacity(0.13),
        stack: Color(red: 0.07, green: 0.13, blue: 0.21)
    )

    /// Accented mode: the curve is the accent group, everything else white.
    public static func tinted(_ tint: Color) -> RainPalette {
        RainPalette(
            rain: tint,
            primary: .white,
            secondary: .white.opacity(0.62),
            baseline: .white.opacity(0.38),
            grid: .white.opacity(0.16),
            plate: .white.opacity(0.13),
            stack: .white.opacity(0.13)
        )
    }

    /// Apple Watch Ultra Night Mode turns the whole face red.
    public static let nightMode: RainPalette = {
        let red = Color(red: 1, green: 0.16, blue: 0.12)
        return RainPalette(
            rain: red,
            primary: red,
            secondary: red.opacity(0.8),
            baseline: red.opacity(0.6),
            grid: red.opacity(0.2),
            plate: red.opacity(0.14),
            stack: red.opacity(0.14)
        )
    }()
}

/// The watch's rounded face font. The mock renderer on the Mac uses SF Compact Rounded so the
/// renders match the watch; on watchOS this is the system rounded font, which is the same face.
public enum RainFont {
    public static func rounded(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        #if os(watchOS)
        .system(size: size, weight: weight, design: .rounded)
        #else
        let descriptor = compactRounded[".SFCompactRounded-\(name(weight))"]
        return descriptor.map { Font(CTFontCreateWithFontDescriptor($0, size, nil)) } ?? .system(size: size, weight: weight, design: .rounded)
        #endif
    }

    #if !os(watchOS)
    /// macOS only exposes the watch face font by file, not by name.
    nonisolated(unsafe) private static let compactRounded: [String: CTFontDescriptor] = {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/SFCompactRounded.ttf") as CFURL
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor] ?? []
        return Dictionary(descriptors.compactMap { descriptor in
            (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String).map { ($0, descriptor) }
        }, uniquingKeysWith: { first, _ in first })
    }()
    #endif

    private static func name(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold: "Bold"
        case .semibold: "Semibold"
        case .medium: "Medium"
        default: "Regular"
        }
    }
}

/// Draws no text: debug builds use it for the design file's pictures, which have the words laid
/// over them as editable text (`design/README.md`).
struct NoText: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {}
}

extension View {
    @ViewBuilder public func hidesTextForDesign(_ hides: Bool) -> some View {
        if hides { textRenderer(NoText()) } else { self }
    }
}
