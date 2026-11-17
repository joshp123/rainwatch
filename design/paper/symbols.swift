import AppKit
let names = CommandLine.arguments.dropFirst()
let weights: [(String, NSFont.Weight)] = [("regular", .regular), ("medium", .medium), ("semibold", .semibold), ("bold", .bold)]
let S: CGFloat = 4
for name in names {
    for (wname, w) in weights {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { print("MISSING", name); break }
        let cfg = NSImage.SymbolConfiguration(pointSize: 100, weight: w)
        guard let img = base.withSymbolConfiguration(cfg) else { continue }
        let size = img.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * S), pixelsHigh: Int(size.height * S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        img.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "sym/\(name)-\(wname).png"))
    }
}
