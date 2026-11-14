import MapKit
import RainGraph
import SwiftUI

/// Buienradar's radar over an Apple Map, played as a loop from half an hour ago to two hours
/// ahead, like Buienradar's own watch app. The strip at the bottom is the rain line for where you
/// are, with a marker at the frame on the map, so a shower reaching the yellow dot shows as the
/// line rising under the marker. The map keeps the dot in the middle of what the strip leaves free. Turning the Digital Crown pauses and steps five minutes a click;
/// tapping plays again. The map starts close, at the radar's own precision, and zooms out to see
/// what is coming.
struct RadarPage: View {
    let place: CLLocationCoordinate2D
    let forecast: RainForecast

    enum Zoom: Double {
        /// About 30 km across: the radar's pixels are 650 m, so closer only shows bigger pixels.
        case near = 30_000
        /// About 120 km across: showers move 30 to 60 km an hour, so this shows two hours' worth.
        case region = 120_000
    }

    @State private var frames: [Radar.Frame] = []
    @State private var images: [Date: Radar.Image] = [:]
    @State private var index = 0
    @State private var crown = 0.0
    @State private var playing = true
    @State private var zoom: Zoom
    @State private var camera: MapCameraPosition
    @State private var cameraChanges = 0
    @State private var problem = false
    @FocusState private var crownFocused: Bool
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.scenePhase) private var scenePhase

    init(place: CLLocationCoordinate2D, forecast: RainForecast) {
        self.place = place
        self.forecast = forecast
        // Close when rain is due here, to watch it arrive; wide when not, to show where rain is.
        let start: Zoom = forecast.hasRain ? .near : .region
        _zoom = State(initialValue: start)
        _camera = State(initialValue: Self.camera(place, start))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: []) {
                Annotation("", coordinate: place) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 2))
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            // MapKit centres the region, and keeps Apple's legal link, above the timeline.
            .safeAreaPadding(.bottom, Self.timelineHeight)
            .onMapCameraChange(frequency: .continuous) { cameraChanges += 1 }
            .overlay { rain(proxy) }
        }
        .overlay(alignment: .bottom) { timeline }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { playing.toggle() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    zoom = zoom == .near ? .region : .near
                    withAnimation(.easeInOut(duration: 0.4)) { camera = Self.camera(place, zoom) }
                } label: {
                    Label(zoom == .near ? "Zoom out" : "Zoom in",
                          systemImage: zoom == .near ? "minus.magnifyingglass" : "plus.magnifyingglass")
                }
            }
        }
        // The bar's blur smeared the radar under the back button into streaks.
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .focusable()
        .focused($crownFocused)
        .onAppear { crownFocused = true }
        .digitalCrownRotation($crown, from: 0, through: Double(max(frames.count - 1, 0)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            // Playback moves the crown too; only a turn by hand lands on another frame.
            let turned = Int(value.rounded())
            guard turned != index else { return }
            playing = false
            index = turned
        }
        .task { await load() }
        .task(id: playing && !dimmed && scenePhase == .active && !frames.isEmpty) { await play() }
    }

    /// The timeline sits on the bottom edge; its padding clears the screen's rounded corners.
    static let timelineHeight: CGFloat = 70

    /// The moment on the map and where it sits in the rain line for your spot. No plate: a dark
    /// fade under it keeps it legible and leaves the map round you uncovered.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Button { playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.footnote)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .handGestureShortcut(.primaryAction)
                .accessibilityLabel(playing ? "Pause" : "Play")
                Text(timeLabel)
                    .font(.headline.monospacedDigit())
                    .contentTransition(.identity)
            }
            if problem {
                Text("Radar unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let first = frames.first?.date, let last = frames.last?.date {
                RadarStrip(forecast: forecast, start: first, end: last, now: nowFrameDate ?? first,
                           selected: frames[safe: index]?.date ?? first)
                    .frame(height: 30)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: 30)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.timelineHeight, alignment: .bottom)
        .background(alignment: .bottom) {
            // Solid under the words and the strip: map labels showing through read as part of them.
            // A short fade above keeps the edge soft.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
                Color.black.frame(height: Self.timelineHeight)
            }
            .allowsHitTesting(false)
        }
    }

    /// The frame placed by its corners, which keeps it aligned however the map moves: Buienradar's
    /// frames and Apple's map both use Web Mercator.
    @ViewBuilder private func rain(_ proxy: MapProxy) -> some View {
        let _ = cameraChanges
        if let frame = frames[safe: index], let image = images[frame.date],
           let northWest = proxy.convert(image.northWest, to: .local),
           let southEast = proxy.convert(image.southEast, to: .local) {
            Image(decorative: image.cgImage, scale: 1)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: southEast.x - northWest.x, height: southEast.y - northWest.y)
                .position(x: (northWest.x + southEast.x) / 2, y: (northWest.y + southEast.y) / 2)
                .allowsHitTesting(false)
        }
    }

    private var nowFrameDate: Date? {
        frames.last { $0.date <= .now }?.date
    }

    /// Relative to now, so it can't be mistaken for the watch's own clock above it.
    private var timeLabel: String {
        guard let date = frames[safe: index]?.date else { return "Radar" }
        if date == nowFrameDate { return "Now" }
        let minutes = Int((date.timeIntervalSince(nowFrameDate ?? .now) / 60).rounded())
        return minutes > 0 ? "in \(minutes) min" : "\(-minutes) min ago"
    }

    private static func camera(_ place: CLLocationCoordinate2D, _ zoom: Zoom) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: place, latitudinalMeters: zoom.rawValue, longitudinalMeters: zoom.rawValue))
    }

    private func load() async {
        do {
            frames = try await Radar.frames()
        } catch {
            problem = true
            return
        }
        // Open on the present, then play forward into the forecast.
        index = frames.lastIndex { $0.date <= .now } ?? 0
        crown = Double(index)
        await withTaskGroup(of: (Date, Radar.Image?).self) { group in
            for frame in frames {
                group.addTask { (frame.date, await Radar.image(frame, around: place)) }
            }
            for await (date, image) in group {
                images[date] = image
            }
        }
    }

    /// Half a second a frame, a pause on the last one, then round again from half an hour ago.
    private func play() async {
        guard playing else { return }
        while !Task.isCancelled {
            let last = index == frames.count - 1
            try? await Task.sleep(for: last ? .seconds(1.5) : .milliseconds(450))
            guard !Task.isCancelled else { return }
            let next = last ? 0 : index + 1
            // Wait for a frame that is still downloading rather than show a gap.
            guard let frame = frames[safe: next], images[frame.date] != nil else { continue }
            index = next
            crown = Double(next)
        }
    }
}

/// The rain line for where you are, across the radar loop, with a marker at the frame on the map.
/// Before now there is no forecast, so the line starts at the tick for now; whole hours get fainter
/// ticks. The label above says which moment the marker is at.
struct RadarStrip: View {
    let forecast: RainForecast
    let start: Date
    let end: Date
    let now: Date
    let selected: Date

    static let labelHeight: CGFloat = 13

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let plot = proxy.size.height - Self.labelHeight
            let x = { (date: Date) in width * date.timeIntervalSince(start) / end.timeIntervalSince(start) }
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: width, height: 1)
                    .offset(y: plot - 1)
                RainArea(forecast: forecast)
                    .fill(RainPalette.buienradarBlue)
                    .frame(width: max(0, min(x(forecast.end), width) - x(forecast.start)), height: plot - 1)
                    .offset(x: x(forecast.start))
                ForEach(ticks, id: \.self) { tick in
                    Rectangle().fill(.white.opacity(tick == now ? 0.8 : 0.35)).frame(width: 1, height: 4)
                        .position(x: x(tick), y: plot + 1)
                    Text(tick == now ? "Now" : RainCopy.clock(tick))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: min(max(x(tick), 12), width - 14), y: plot + 8)
                }
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: plot + 2)
                    .overlay(Capsule().stroke(.black.opacity(0.5), lineWidth: 1))
                    .position(x: x(selected), y: plot / 2)
            }
        }
        .accessibilityHidden(true)
    }

    /// "Now" and whole hours, leaving out hours so close to "Now" that the two read as one label.
    private var ticks: [Date] {
        let calendar = Calendar.current
        var hours: [Date] = []
        var hour = calendar.nextDate(after: start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
        while let current = hour, current < end {
            if abs(current.timeIntervalSince(now)) >= 40 * 60 { hours.append(current) }
            hour = calendar.date(byAdding: .hour, value: 1, to: current)
        }
        return [now] + hours
    }
}

/// Buienradar's Dutch radar: frames every five minutes with its forecast. Its website places them
/// with these corners ("nlRadarWebMercator": 54.8 N 0 E to 49.5 N 10 E).
enum Radar {
    struct Frame: Sendable {
        let date: Date
        let url: URL
    }

    /// A frame cut to the area round you, recoloured for the dark map, with its own corners.
    struct Image: @unchecked Sendable {
        let cgImage: CGImage
        let northWest: CLLocationCoordinate2D
        let southEast: CLLocationCoordinate2D
    }

    static let north = 54.8, south = 49.5, west = 0.0, east = 10.0

    static func frames() async throws -> [Frame] {
        // The key is the one Buienradar's own website sends. Six frames back is half an hour;
        // 24 ahead is two hours, the same window as the rain line.
        let url = URL(string: "https://image-lite.buienradar.nl/3.0/metadata/radarMapRain5mNL?history=6&forecast=24&ak=3c4a3037-85e6-4d1e-ad6c-f3f6e4b75f2f")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let metadata = try JSONDecoder().decode(Metadata.self, from: data)
        return metadata.times.compactMap { time in
            guard let date = utc.date(from: time.timestamp), let url = URL(string: time.url) else { return nil }
            return Frame(date: date, url: url)
        }
    }

    /// The frame's pixels within about 85 km of you: enough for the wider view, and a fortieth of
    /// the whole frame to recolour.
    static func image(_ frame: Frame, around place: CLLocationCoordinate2D) async -> Image? {
        guard let (data, _) = try? await URLSession.shared.data(from: frame.url),
              let whole = UIImage(data: data)?.cgImage else { return nil }
        let width = Double(whole.width), height = Double(whole.height)
        let x = { (longitude: Double) in (longitude - west) / (east - west) * width }
        let y = { (latitude: Double) in (mercator(north) - mercator(latitude)) / (mercator(north) - mercator(south)) * height }
        let reach = 0.8
        let left = max(0, x(place.longitude - reach * 1.6).rounded(.down))
        let right = min(width, x(place.longitude + reach * 1.6).rounded(.up))
        let top = max(0, y(place.latitude + reach).rounded(.down))
        let bottom = min(height, y(place.latitude - reach).rounded(.up))
        guard right > left, bottom > top,
              let cut = whole.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top)),
              let recoloured = forDarkMap(cut) else { return nil }
        let longitude = { (px: Double) in west + px / width * (east - west) }
        let latitude = { (py: Double) in latitudeFromMercator(mercator(north) - py / height * (mercator(north) - mercator(south))) }
        return Image(cgImage: recoloured,
                     northWest: CLLocationCoordinate2D(latitude: latitude(top), longitude: longitude(left)),
                     southEast: CLLocationCoordinate2D(latitude: latitude(bottom), longitude: longitude(right)))
    }

    private static func mercator(_ latitude: Double) -> Double {
        log(tan(.pi / 4 + latitude * .pi / 360))
    }

    private static func latitudeFromMercator(_ y: Double) -> Double {
        (2 * atan(exp(y)) - .pi / 2) * 180 / .pi
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
            let a = 0.5 + 0.5 * intensity
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
