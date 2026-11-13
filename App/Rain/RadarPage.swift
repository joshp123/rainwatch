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

    var body: some View {
        MapReader { proxy in
            Map(initialPosition: .region(MKCoordinateRegion(center: place, latitudinalMeters: 60_000, longitudinalMeters: 60_000)),
                interactionModes: .pan) {
                Annotation("", coordinate: place) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 2))
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .onMapCameraChange(frequency: .continuous) { cameraChanges += 1 }
            .overlay { rain(proxy) }
        }
        .overlay(alignment: .topLeading) { timeLabel }
        .focusable()
        .digitalCrownRotation($index, from: 0, through: Double(max(frames.count - 1, 0)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .task { await load() }
        .task(id: Int(index)) { await loadImage(at: Int(index)) }
        .ignoresSafeArea(edges: .bottom)
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
                .opacity(0.85)
                .frame(width: southEast.x - northWest.x, height: southEast.y - northWest.y)
                .position(x: (northWest.x + southEast.x) / 2, y: (northWest.y + southEast.y) / 2)
                .allowsHitTesting(false)
        }
    }

    private var timeLabel: some View {
        Group {
            if let problem {
                Text(problem)
            } else if let frame = frames[safe: Int(index)] {
                Text(Radar.label(for: frame.date))
            } else {
                ProgressView()
            }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: Capsule())
        .padding(.leading, 8)
    }

    private func load() async {
        do {
            frames = try await Radar.frames()
            index = Double(frames.lastIndex { $0.date <= .now } ?? 0)
        } catch {
            problem = "No radar"
        }
    }

    private func loadImage(at index: Int) async {
        guard let frame = frames[safe: index], images[frame.date] == nil,
              let (data, _) = try? await URLSession.shared.data(from: frame.url),
              let uiImage = UIImage(data: data) else { return }
        images[frame.date] = Image(uiImage: uiImage)
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

    static func label(for date: Date) -> String {
        let minutes = Int((date.timeIntervalSinceNow / 60).rounded())
        let clock = RainCopy.clock(date)
        if abs(minutes) < 3 { return "Now" }
        return minutes > 0 ? "\(clock), in \(minutes) min" : "\(clock), \(-minutes) min ago"
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
