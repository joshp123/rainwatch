import MapKit
import RainGraph
import SwiftUI

/// Buienradar's radar frames over an Apple Map: the past hour and its forecast to two hours ahead,
/// every five minutes. The Digital Crown moves through time; the map stays put around you.
struct RadarPage: View {
    let place: CLLocationCoordinate2D

    @State private var frames: [Radar.Frame] = []
    @State private var images: [Date: Image] = [:]
    @State private var index = 0.0
    @State private var cameraChanges = 0
    @State private var problem: String?
    @FocusState private var crownFocused: Bool
    @State private var dragStart = 0.0

    var body: some View {
        MapReader { proxy in
            // 120 km across: showers move 30 to 60 km/h, so this shows what can arrive within two hours.
            Map(initialPosition: .region(MKCoordinateRegion(center: place, latitudinalMeters: 120_000, longitudinalMeters: 120_000)),
                interactionModes: []) {
                Annotation("", coordinate: place) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 2))
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .continuous) { cameraChanges += 1 }
            .overlay { rain(proxy) }
        }
        .navigationTitle(title)
        .gesture(DragGesture(minimumDistance: 8).onChanged { drag in
            // A drag across the screen scrubs about an hour, like the crown.
            let step = -Double(drag.translation.width / 14)
            index = min(max(dragStart + step, 0), Double(max(frames.count - 1, 0))).rounded()
        }.onEnded { _ in dragStart = index })
        .focusable()
        .focused($crownFocused)
        .onAppear { crownFocused = true }
        .digitalCrownRotation($index, from: 0, through: Double(max(frames.count - 1, 0)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .task { await load() }
        .task(id: Int(index)) { await loadImage(at: Int(index)) }
    }

    /// The frame placed by its corners, which keeps it aligned however the map is panned:
    /// Buienradar's frames and Apple's map both use Web Mercator.
    @ViewBuilder private func rain(_ proxy: MapProxy) -> some View {
        let _ = cameraChanges
        if let frame = frames[safe: Int(index)], let image = images[frame.date],
           let northWest = proxy.convert(Radar.northWest, to: .local),
           let southEast = proxy.convert(Radar.southEast, to: .local) {
            image
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .opacity(0.9)
                .frame(width: southEast.x - northWest.x, height: southEast.y - northWest.y)
                .position(x: (northWest.x + southEast.x) / 2, y: (northWest.y + southEast.y) / 2)
                .allowsHitTesting(false)
        }
    }

    private var title: String {
        if problem != nil { return "No radar" }
        guard let frame = frames[safe: Int(index)] else { return "Radar" }
        return Radar.label(for: frame.date)
    }

    private func load() async {
        do {
            frames = try await Radar.frames()
            index = Double(frames.lastIndex { $0.date <= .now } ?? 0)
            dragStart = index
        } catch {
            problem = "No radar"
        }
    }

    private func loadImage(at index: Int) async {
        guard let frame = frames[safe: index], images[frame.date] == nil,
              let (data, _) = try? await URLSession.shared.data(from: frame.url),
              let cgImage = UIImage(data: data)?.cgImage,
              let recoloured = Radar.forDarkMap(cgImage) else { return }
        images[frame.date] = Image(decorative: recoloured, scale: 1)
    }
}

/// Buienradar's Dutch radar: frames every five minutes with its forecast, and the corners its own
/// website uses to place them ("nlRadarWebMercator": 54.8 N 0 E to 49.5 N 10 E).
enum Radar {
    struct Frame: Sendable {
        let date: Date
        let url: URL
    }

    static let northWest = CLLocationCoordinate2D(latitude: 54.8, longitude: 0)
    static let southEast = CLLocationCoordinate2D(latitude: 49.5, longitude: 10)

    static func frames() async throws -> [Frame] {
        // The key is the one Buienradar's own website sends.
        let url = URL(string: "https://image-lite.buienradar.nl/3.0/metadata/radarMapRain5mNL?history=12&forecast=24&ak=3c4a3037-85e6-4d1e-ad6c-f3f6e4b75f2f")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let metadata = try JSONDecoder().decode(Metadata.self, from: data)
        return metadata.times.compactMap { time in
            guard let date = utc.date(from: time.timestamp), let url = URL(string: time.url) else { return nil }
            return Frame(date: date, url: url)
        }
    }

    /// Buienradar draws light rain pale and heavy rain dark, for its light map. On the watch's dark
    /// map that hides the heaviest rain, so heavier rain becomes brighter and more opaque instead,
    /// in Buienradar's blue, with its red kept for downpours.
    static func forDarkMap(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space, bitmapInfo: info) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3]) / 255
            guard alpha > 0.05 else {
                pixels[i + 3] = 0
                continue
            }
            let r = Double(pixels[i]) / 255 / alpha, g = Double(pixels[i + 1]) / 255 / alpha, b = Double(pixels[i + 2]) / 255 / alpha
            let downpour = r > b + 0.15
            let intensity = downpour ? 1 : min(1, max(0, 1 - (0.3 * r + 0.59 * g + 0.11 * b)) * 1.6)
            // Buienradar's blue (#5A9BD3) for light rain, towards white for heavy, red for downpours.
            let (cr, cg, cb) = downpour ? (1.0, 0.3, 0.3) : (0.35 + 0.65 * intensity, 0.61 + 0.39 * intensity, 0.83 + 0.17 * intensity)
            let a = 0.45 + 0.55 * intensity
            pixels[i] = UInt8(cr * a * 255)
            pixels[i + 1] = UInt8(cg * a * 255)
            pixels[i + 2] = UInt8(cb * a * 255)
            pixels[i + 3] = UInt8(a * 255)
        }
        return pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: width * 4, space: space, bitmapInfo: info)?.makeImage()
        }
    }

    static func label(for date: Date) -> String {
        let minutes = Int((date.timeIntervalSinceNow / 60).rounded())
        if abs(minutes) < 3 { return "Now" }
        return minutes > 0 ? "In \(minutes) min" : "\(-minutes) min ago"
    }

    private struct Metadata: Decodable {
        struct Time: Decodable {
            let timestamp: String
            let url: String
        }

        let times: [Time]
    }

    private static let utc: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
