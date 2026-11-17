import MapKit
import RainGraph
import SwiftUI

/// KNMI's radar over an Apple Map, played as a loop from half an hour ago to two hours ahead: six
/// frames of observed radar, then the forecast. The frames are drawn on the watch from the same
/// squares of KNMI's 1 km grid that the rain line comes from, smoothed as Buienradar smooths its
/// picture. The strip at the bottom is the rain line for where you are, with a marker at the frame
/// on the map, so a shower reaching the yellow dot shows as the line rising under the marker. The
/// map keeps the dot in the middle of what the strip leaves free. Turning the Digital Crown pauses
/// and steps five minutes a click; tapping plays again. The map starts close, at the radar's own
/// precision, and zooms out to see what is coming.
struct RadarPage: View {
    let place: CLLocationCoordinate2D
    let forecast: RainForecast

    enum Zoom: Double {
        /// About 30 km across: the radar's cells are 1 km, so closer only shows bigger cells.
        case near = 30_000
        /// About 120 km across: showers move 30 to 60 km an hour, so this shows two hours' worth.
        case region = 120_000
    }

    @State private var radar: Radar?
    @State private var frames: [Radar.Frame] = []
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
        if problem {
            // Nothing to play, so no playback controls: say so, and offer to try again, which loads
            // the radar afresh.
            ContentUnavailableView {
                Label("Radar Unavailable", systemImage: "map")
            } description: {
                Text("KNMI’s radar can’t be reached.")
            } actions: {
                Button("Try Again") { problem = false }
            }
        } else {
            player
        }
    }

    @ViewBuilder private var player: some View {
        // Read here, not inside MapReader's closure: SwiftUI does not run that closure again when
        // state it reads changes, so the picture would stay on its first frame.
        let image = frames[safe: index]?.image
        let changes = cameraChanges
        MapReader { proxy in
            Map(position: $camera, interactionModes: [])
                .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                // MapKit centres the region, and keeps Apple's legal link, above the timeline.
                .safeAreaPadding(.bottom, Self.timelineHeight)
                .onMapCameraChange(frequency: .continuous) { cameraChanges += 1 }
                .overlay { RainPicture(proxy: proxy, image: image, place: place, cameraChanges: changes) }
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
        .task(id: zoom) { await load(zoom) }
        .task(id: playing && !dimmed && scenePhase == .active && !frames.isEmpty) { await play() }
    }

    /// The timeline sits on the bottom edge; its padding clears the screen's rounded corners.
    static let timelineHeight: CGFloat = 70

    /// The moment on the map and where it sits in the rain line for your spot. Solid black under
    /// it keeps it legible and leaves the map round you uncovered.
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
                    .fixedSize()
                Spacer(minLength: 4)
                // KNMI's licence (CC BY 4.0) asks for its name with its data. It sits on the black
                // band, where no map label can run under it.
                Text("Source: KNMI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            if let radar, let first = frames.first?.date {
                RadarStrip(series: radar.series, now: nowFrameDate ?? first,
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

    /// Downloads the squares the view needs, once per zoom, then draws every frame. The first time
    /// it opens on the present and plays forward into the forecast.
    private func load(_ zoom: Zoom) async {
        let first = radar == nil
        do {
            let loaded = try await Radar.load(around: place, view: zoom.rawValue, reusing: radar)
            radar = loaded
            let drawn = await Task.detached(priority: .userInitiated) { loaded.frames(around: place, view: zoom.rawValue) }.value
            guard !Task.isCancelled else { return }
            frames = drawn
        } catch {
            problem = true
            return
        }
        if first {
            index = frames.lastIndex { $0.date <= .now } ?? 0
            crown = Double(index)
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
            index = next
            crown = Double(next)
        }
    }
}

/// The frame placed by its corners, which keeps it aligned however the map moves: the picture is
/// drawn in Web Mercator, as Apple's map is. The yellow dot for where you are goes on top, so rain
/// never hides it.
struct RainPicture: View {
    let proxy: MapProxy
    let image: Radar.Image?
    let place: CLLocationCoordinate2D
    /// Changes whenever the map moves, so the picture follows it.
    let cameraChanges: Int

    var body: some View {
        ZStack {
            if let image, let northWest = proxy.convert(image.northWest, to: .local),
               let southEast = proxy.convert(image.southEast, to: .local) {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: southEast.x - northWest.x, height: southEast.y - northWest.y)
                    .position(x: (northWest.x + southEast.x) / 2, y: (northWest.y + southEast.y) / 2)
            }
            if let point = proxy.convert(place, to: .local) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 2))
                    .position(point)
            }
        }
        // Rain fades out under the clock and the buttons, so they stay readable over a downpour.
        .mask {
            VStack(spacing: 0) {
                Color.clear.frame(height: 40)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 26)
                Color.black
            }
        }
        .allowsHitTesting(false)
    }
}

/// The rain line for where you are across the radar loop, observed radar and then the forecast,
/// with a marker at the frame on the map. Whole hours get fainter ticks. Where KNMI has no data,
/// the baseline is dotted rather than drawn as dry.
struct RadarStrip: View {
    let series: RainForecast
    let now: Date
    let selected: Date

    static let labelHeight: CGFloat = 13

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let plot = proxy.size.height - Self.labelHeight
            let x = { (date: Date) in width * series.position(of: date) }
            ZStack(alignment: .topLeading) {
                ForEach(stretches, id: \.start) { stretch in
                    if stretch.known {
                        Rectangle()
                            .fill(.white.opacity(0.35))
                            .frame(width: max(0, x(stretch.end) - x(stretch.start)), height: 1)
                            .offset(x: x(stretch.start), y: plot - 1)
                    } else {
                        Path { path in
                            path.move(to: CGPoint(x: x(stretch.start) + 2, y: plot - 0.5))
                            path.addLine(to: CGPoint(x: x(stretch.end) - 2, y: plot - 0.5))
                        }
                        .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 4]))
                    }
                }
                RainArea(forecast: series)
                    .fill(RainPalette.buienradarBlue.opacity(0.55))
                    .frame(width: width, height: plot - 1)
                RainEdge(forecast: series)
                    .stroke(RainPalette.buienradarBlue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: width, height: plot - 1)
                ForEach(ticks, id: \.self) { tick in
                    Rectangle().fill(.white.opacity(tick == now ? 0.8 : 0.35)).frame(width: 1, height: 4)
                        .position(x: x(tick), y: plot + 1)
                    Text(tick == now ? "Now" : RainCopy.clock(tick))
                        .font(.system(size: 11, weight: .medium))
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

    /// Runs of steps with and without data.
    private var stretches: [(start: Date, end: Date, known: Bool)] {
        var result: [(start: Date, end: Date, known: Bool)] = []
        for sample in series.samples {
            let end = min(sample.date.addingTimeInterval(RainForecast.step), series.end)
            if let last = result.last, last.known == (sample.rate != nil) {
                result[result.count - 1].end = end
            } else {
                result.append((sample.date, end, sample.rate != nil))
            }
        }
        return result
    }

    /// "Now" and whole hours, leaving out hours so close to "Now" that the two read as one label.
    private var ticks: [Date] {
        let calendar = Calendar.current
        var hours: [Date] = []
        var hour = calendar.nextDate(after: series.start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
        while let current = hour, current < series.end {
            if abs(current.timeIntervalSince(now)) >= 40 * 60 { hours.append(current) }
            hour = calendar.date(byAdding: .hour, value: 1, to: current)
        }
        return [now] + hours
    }
}

/// The squares of KNMI's grid under the map, from BuienWatch's server: `latest`, then one request
/// per row of squares that has rain, because squares in a row sit together in the pack.
struct Radar: Sendable {
    struct Frame: Sendable {
        let date: Date
        let image: Image?
    }

    /// A frame drawn for the map, with its corners.
    struct Image: @unchecked Sendable {
        let cgImage: CGImage
        let northWest: CLLocationCoordinate2D
        let southEast: CLLocationCoordinate2D
    }

    let latest: KNMI.Latest
    /// Squares downloaded so far, by index in the pack. Dry squares need no download.
    let squares: [Int: [UInt8]]
    /// The rain line for the place across all frames.
    let series: RainForecast

    /// The part of the map the picture covers for a view `view` metres across, in km from the place:
    /// the watch screen is taller than wide, the map centres the place above the timeline, and the
    /// grid is turned a few degrees from north, so it reaches further than the view each way.
    static func reach(view: Double) -> (west: Double, east: Double, north: Double, south: Double) {
        let km = view / 1000
        return (0.62 * km, 0.62 * km, 0.6 * km, 0.5 * km)
    }

    static func load(around place: CLLocationCoordinate2D, view: Double, reusing old: Radar?) async throws -> Radar {
        let latest: KNMI.Latest
        if let old, Date.now.timeIntervalSince(old.latest.run) < 10 * 60 {
            latest = old.latest
        } else {
            latest = try await KNMI.latest()
        }
        var squares = old?.latest.run == latest.run ? old?.squares ?? [:] : [:]
        let (rows, columns) = squareSpan(around: place, view: view, latest: latest)
        try await withThrowingTaskGroup(of: [Int: [UInt8]].self) { group in
            for row in rows {
                let wanted = columns.filter { latest.squares[row * latest.columns + $0] > 0 && squares[row * latest.columns + $0] == nil }
                guard let first = wanted.first, let last = wanted.last else { continue }
                group.addTask { try await KNMI.squares((row * latest.columns + first)...(row * latest.columns + last), in: latest) }
            }
            for try await row in group { squares.merge(row) { $1 } }
        }
        let cell = KNMI.cell(latitude: place.latitude, longitude: place.longitude)
        let samples = (0..<latest.frames).map { frame in
            RainSample(date: latest.date(ofFrame: frame),
                       rate: cell.flatMap { KNMI.rate(value(latest: latest, squares: squares, row: $0.row, column: $0.column, frame: frame)) })
        }
        let span = Double(latest.frames - 1) * Double(latest.stepMinutes) * 60
        return Radar(latest: latest, squares: squares, series: RainForecast(samples: samples, span: span))
    }

    /// Rows and columns of squares under the picture.
    private static func squareSpan(around place: CLLocationCoordinate2D, view: Double, latest: KNMI.Latest) -> (ClosedRange<Int>, ClosedRange<Int>) {
        let box = bounds(around: place, view: view)
        var xs: [Double] = [], ys: [Double] = []
        for latitude in [box.north, (box.north + box.south) / 2, box.south] {
            for longitude in [box.west, (box.west + box.east) / 2, box.east] {
                let point = KNMI.gridPoint(latitude: latitude, longitude: longitude)
                xs.append(point.x); ys.append(point.y)
            }
        }
        let size = Double(latest.squareKm)
        func clamp(_ value: Double, _ count: Int) -> Int { min(max(Int((value / size).rounded(.down)), 0), count - 1) }
        return (clamp(ys.min()! - 2, latest.rows)...clamp(ys.max()! + 2, latest.rows),
                clamp(xs.min()! - 2, latest.columns)...clamp(xs.max()! + 2, latest.columns))
    }

    /// The picture's corners in degrees.
    static func bounds(around place: CLLocationCoordinate2D, view: Double) -> (north: Double, south: Double, west: Double, east: Double) {
        let reach = reach(view: view)
        let perDegreeLongitude = 111.32 * cos(place.latitude * .pi / 180)
        return (place.latitude + reach.north / 111.2, place.latitude - reach.south / 111.2,
                place.longitude - reach.west / perDegreeLongitude, place.longitude + reach.east / perDegreeLongitude)
    }

    /// One cell's byte for a frame: 0 dry, 255 no data, else rain (KNMI.rate).
    static func value(latest: KNMI.Latest, squares: [Int: [UInt8]], row: Int, column: Int, frame: Int) -> UInt8 {
        guard (0..<KNMI.rows).contains(row), (0..<KNMI.columns).contains(column) else { return 255 }
        let size = latest.squareKm
        let index = (row / size) * latest.columns + column / size
        switch latest.squares[index] {
        case 0: return 0
        case ..<0: return 255
        default:
            guard let square = squares[index] else { return 255 }
            let width = min(size, KNMI.columns - (column / size) * size)
            return square[((row % size) * width + column % size) * latest.frames + frame]
        }
    }

    /// Every frame drawn for a view `view` metres across.
    func frames(around place: CLLocationCoordinate2D, view: Double) -> [Frame] {
        let painter = Painter(radar: self, place: place, view: view)
        return (0..<latest.frames).map { frame in
            Frame(date: latest.date(ofFrame: frame), image: painter.image(frame: frame))
        }
    }
}

/// Draws a frame the way Buienradar draws its radar picture: the 1 km cells blended smoothly into
/// each other rather than shown as squares, so a shower has soft edges and a brighter core
/// (`server/evidence/` shows the same minute from Buienradar and from KNMI's cells). Each pixel of
/// the picture is a point on the map in Web Mercator; it takes the four cells round that point on
/// KNMI's grid and blends them by distance.
private struct Painter {
    let radar: Radar
    let width: Int
    let height: Int
    let northWest: CLLocationCoordinate2D
    let southEast: CLLocationCoordinate2D
    /// For each pixel, the grid point it falls on.
    let points: [(x: Double, y: Double)]
    /// The cells round those points: top row, left column, and how many.
    let top: Int, left: Int, cellWidth: Int, cellHeight: Int
    /// Close up, the cells keep a soft but visible edge, so drizzle reads as rain rather than haze;
    /// wide out they are blended into each other, where a shower is only a few cells across.
    let close: Bool

    init(radar: Radar, place: CLLocationCoordinate2D, view: Double) {
        self.radar = radar
        close = view < 60_000
        let box = Radar.bounds(around: place, view: view)
        // Eight pixels per cell close up and two wide out, so the blend between cells is smooth.
        let kmPerPixel = view / 1000 / 240
        let reach = Radar.reach(view: view)
        width = Int(((reach.west + reach.east) / kmPerPixel).rounded())
        height = Int(((reach.north + reach.south) / kmPerPixel).rounded())
        northWest = CLLocationCoordinate2D(latitude: box.north, longitude: box.west)
        southEast = CLLocationCoordinate2D(latitude: box.south, longitude: box.east)
        func mercator(_ latitude: Double) -> Double { log(tan(.pi / 4 + latitude * .pi / 360)) }
        let northY = mercator(box.north), southY = mercator(box.south)
        var points: [(x: Double, y: Double)] = []
        points.reserveCapacity(width * height)
        for row in 0..<height {
            let y = northY - (Double(row) + 0.5) / Double(height) * (northY - southY)
            let latitude = (2 * atan(exp(y)) - .pi / 2) * 180 / .pi
            for column in 0..<width {
                let longitude = box.west + (Double(column) + 0.5) / Double(width) * (box.east - box.west)
                points.append(KNMI.gridPoint(latitude: latitude, longitude: longitude))
            }
        }
        self.points = points
        let ys = points.map(\.y), xs = points.map(\.x)
        let first = (row: Int(((ys.min() ?? 0) - 1.5).rounded(.down)), column: Int(((xs.min() ?? 0) - 1.5).rounded(.down)))
        let last = (row: Int(((ys.max() ?? 0) + 1.5).rounded(.down)), column: Int(((xs.max() ?? 0) + 1.5).rounded(.down)))
        top = first.row
        left = first.column
        cellHeight = last.row - first.row + 1
        cellWidth = last.column - first.column + 1
    }

    /// Wide out, dry counts as far below the lightest rain (1), so rain fades out gradually between
    /// a wet and a dry cell.
    static let dry: Float = -10

    func image(frame: Int) -> Radar.Image? {
        // The cells this picture needs, as rain level (dry far below 0) and no-data share.
        var level = [Float](repeating: close ? 0 : Self.dry, count: cellWidth * cellHeight)
        var missing = [Float](repeating: 0, count: cellWidth * cellHeight)
        var wet = [Float](repeating: 0, count: cellWidth * cellHeight)
        for row in 0..<cellHeight {
            for column in 0..<cellWidth {
                let value = Radar.value(latest: radar.latest, squares: radar.squares, row: top + row, column: left + column, frame: frame)
                let i = row * cellWidth + column
                if value == 255 { missing[i] = 1 } else if value > 0 { level[i] = Float(value); wet[i] = 1 }
            }
        }
        // Wide out, a light blur first rounds the corners of the 1 km cells.
        if !close {
            level = Self.soften(level, width: cellWidth, height: cellHeight)
            missing = Self.soften(missing, width: cellWidth, height: cellHeight)
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (pixel, point) in points.enumerated() {
            // Cell centres sit at half-cell positions.
            let fx = point.x - 0.5 - Double(left), fy = point.y - 0.5 - Double(top)
            let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
            guard x0 >= 0, y0 >= 0, x0 + 1 < cellWidth, y0 + 1 < cellHeight else { continue }
            let tx = Float(fx - Double(x0)), ty = Float(fy - Double(y0))
            let i = y0 * cellWidth + x0
            func blend(_ grid: [Float]) -> Float {
                let upper = grid[i] * (1 - tx) + grid[i + 1] * tx
                let lower = grid[i + cellWidth] * (1 - tx) + grid[i + cellWidth + 1] * tx
                return upper * (1 - ty) + lower * ty
            }
            let presence: Float, rain: Float
            if close {
                // The edge comes from where cells are wet, half way between a wet and a dry cell
                // whatever the rain's strength; the strength from the wet cells alone.
                let share = blend(wet)
                presence = Self.smoothstep(0.38, 0.62, share)
                rain = share > 0 ? blend(level) / share : 0
            } else {
                rain = blend(level)
                presence = Self.smoothstep(-4, 3, rain)
            }
            let (r, g, b, a) = Self.colour(level: rain, presence: presence, missing: blend(missing))
            pixels[pixel * 4] = UInt8(r * a * 255)
            pixels[pixel * 4 + 1] = UInt8(g * a * 255)
            pixels[pixel * 4 + 2] = UInt8(b * a * 255)
            pixels[pixel * 4 + 3] = UInt8(a * 255)
        }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let image = pixels.withUnsafeMutableBytes({ buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }) else { return nil }
        return Radar.Image(cgImage: image, northWest: northWest, southEast: southEast)
    }

    /// A 1-2-1 blur across and down.
    static func soften(_ grid: [Float], width: Int, height: Int) -> [Float] {
        var across = grid
        for row in 0..<height {
            for column in 1..<max(1, width - 1) {
                let i = row * width + column
                across[i] = (grid[i - 1] + 2 * grid[i] + grid[i + 1]) / 4
            }
        }
        var down = across
        for row in 1..<max(1, height - 1) {
            for column in 0..<width {
                let i = row * width + column
                down[i] = (across[i - width] + 2 * across[i] + across[i + width]) / 4
            }
        }
        return down
    }

    /// Light rain in Buienradar's blue, heavier rain brighter and more opaque, towards white, with
    /// red kept for downpours from 10 mm/h (DESIGN.md, rule 2). Where the radar has no data, a grey
    /// veil, so it never reads as dry. `level` is KNMI's byte scale: 1 is 0.1 mm/h, 51 is 1, 101 is 10.
    static func colour(level: Float, presence: Float, missing: Float) -> (Float, Float, Float, Float) {
        let veil = (r: Float(0.55), g: Float(0.55), b: Float(0.6), a: 0.4 * missing)
        guard presence > 0 else { return (veil.r, veil.g, veil.b, veil.a) }
        let blue: (Float, Float, Float) = (0.35, 0.61, 0.83)
        let light: (Float, Float, Float) = (0.62, 0.82, 1)
        let white: (Float, Float, Float) = (0.93, 0.97, 1)
        let red: (Float, Float, Float) = (1, 0.3, 0.3)
        let colour: (Float, Float, Float)
        let opacity: Float
        switch level {
        case ..<51:
            // Drizzle stays see-through, so heavier rain and the map's labels stand out from it.
            colour = mix(blue, light, smoothstep(1, 51, level)); opacity = 0.5 + 0.25 * smoothstep(1, 51, level)
        case ..<86:
            colour = mix(light, white, smoothstep(51, 86, level)); opacity = 0.75 + 0.2 * smoothstep(51, 86, level)
        default:
            colour = mix(white, red, smoothstep(91, 101, level)); opacity = 0.95 + 0.05 * smoothstep(91, 101, level)
        }
        let a = presence * opacity
        // Rain over a no-data veil: the rain wins where there is any.
        let total = a + veil.a * (1 - a)
        guard total > 0 else { return (0, 0, 0, 0) }
        func over(_ c: Float, _ v: Float) -> Float { (c * a + v * veil.a * (1 - a)) / total }
        return (over(colour.0, veil.r), over(colour.1, veil.g), over(colour.2, veil.b), total)
    }

    static func smoothstep(_ low: Float, _ high: Float, _ x: Float) -> Float {
        let t = min(max((x - low) / (high - low), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ a: (Float, Float, Float), _ b: (Float, Float, Float), _ t: Float) -> (Float, Float, Float) {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
