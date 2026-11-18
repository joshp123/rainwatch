// Written by AI on 2026.11.18 by model claude fable 5.2, from the exporter of the same day by claude opus 5.5.
// Draws everything the launch film shows of the app, with the app's own code (RainGraph), for one
// language: run it with `-AppleLanguages '(nl)'` for Dutch. See marketing/video/README.md.
//   film-export <gen folder> <faces folder> <language>
// Reads <gen>/forecast.json (data.py) and <faces>/<language>/*.png; writes <gen>/<language>/.
import AppKit
import RainGraph
import SwiftUI

let gen = URL(fileURLWithPath: CommandLine.arguments[1])
let facesFolder = URL(fileURLWithPath: CommandLine.arguments[2])
let language = CommandLine.arguments[3]
let out = gen.appendingPathComponent(language)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// ---- The forecast: KNMI's run for the place, its times moved to the clock on the face ----

struct Forecast: Decodable {
    let firstFrameMinutes: Int
    let stepMinutes: Int
    let series: [Double?]
}
let picked = try JSONDecoder().decode(Forecast.self, from: Data(contentsOf: gen.appendingPathComponent("forecast.json")))

/// The face screenshots, one a minute, and the clock each shows.
struct Face: Decodable { let t: Double; let file: String }
let faces = try JSONDecoder().decode([Face].self, from: Data(contentsOf: facesFolder.appendingPathComponent("\(language)/faces.json")))

/// The film opens on the second face, ten minutes before the rain: the run's first wet frame is
/// put eleven minutes after the first face, and every other frame keeps its distance from it.
let firstWet = picked.series.enumerated().first { index, rate in
    picked.firstFrameMinutes + index * picked.stepMinutes > 0 && (rate ?? 0) > 0
}!.offset
let rainStarts = faces[0].t + 11 * 60
let samples = picked.series.enumerated().compactMap { index, rate -> RainSample? in
    let minutes = picked.firstFrameMinutes + index * picked.stepMinutes
    guard minutes >= 0 else { return nil }
    return RainSample(date: Date(timeIntervalSince1970: rainStarts + Double((index - firstWet) * picked.stepMinutes) * 60), rate: rate)
}
func forecast(_ moment: Date) -> RainForecast { RainForecast.at(moment, from: samples)! }

// ---- Rendering ----

/// The watch spaces small text more widely than the Mac draws SF Compact Rounded: matched against
/// the simulator's own screenshots of the face (README, "What is real").
let watchTracking: CGFloat = 0.6

@MainActor func save(_ view: some View, _ name: String, scale: CGFloat) {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = scale
    guard let image = renderer.cgImage,
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("could not render \(name)")
    }
    let url = out.appendingPathComponent(name)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
}

/// The face screenshot with the app's complications drawn into its two slots, at the size and place
/// the face gives them (measured on the simulator's screenshots): the circle 45 points across, the
/// wide slot laid out at 190 x 73.5 points and shrunk to 0.884.
struct FaceShot: View {
    let backdrop: NSImage
    let forecast: RainForecast
    /// Leave slots empty, for when the film has lifted the complications off the face.
    var showsCircle = true
    var showsWide = true
    static let circle = CGPoint(x: 105.5, y: 216.5)
    static let slot = CGPoint(x: 22.5, y: 116)
    static let shrink: CGFloat = 0.884

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: backdrop).resizable().interpolation(.high).frame(width: 211, height: 257)
            // Cover what the screenshot showed in the slots.
            Circle().fill(Color(white: 25 / 255)).frame(width: 46, height: 46).position(Self.circle)
            Rectangle().fill(.black).frame(width: 172, height: 67).position(x: Self.slot.x + 84, y: Self.slot.y + 32.5)
            if showsCircle {
                CircularRainGauge(forecast: forecast, palette: .fullColour)
                    .frame(width: 45, height: 45).position(Self.circle)
            }
            if showsWide {
                WideSlot(forecast: forecast)
                    .scaleEffect(Self.shrink, anchor: .topLeading)
                    .frame(width: 190 * Self.shrink, height: 73.5 * Self.shrink, alignment: .topLeading)
                    .offset(x: Self.slot.x, y: Self.slot.y)
            }
        }
        .frame(width: 211, height: 257, alignment: .topLeading)
    }
}

/// The Infograph Modular face of the two other watches, with the app's complications drawn into its
/// slots the same way. One screenshot each, of the minute the film shows them (face/README.md has
/// where the measurements come from).
struct OtherFace: View {
    struct Layout {
        let name: String
        let frame: CGSize
        let circle: CGPoint
        let circleSize: CGFloat
        let slot: CGPoint
        let slotSize: CGSize
        let shrink: CGFloat
        let cover: CGRect
        static let series = Layout(name: "series", frame: CGSize(width: 208, height: 248), circle: CGPoint(x: 104, y: 216), circleSize: 51,
                                   slot: CGPoint(x: 13.5, y: 107.9), slotSize: CGSize(width: 188.25, height: 67), shrink: 0.962,
                                   cover: CGRect(x: 12, y: 109, width: 185, height: 65))
        static let se = Layout(name: "se", frame: CGSize(width: 184, height: 224), circle: CGPoint(x: 92, y: 194.5), circleSize: 47,
                               slot: CGPoint(x: 6.625, y: 94.25), slotSize: CGSize(width: 177.75, height: 66), shrink: 0.962,
                               cover: CGRect(x: 4.5, y: 95, width: 175, height: 64))
    }
    let layout: Layout
    let backdrop: NSImage
    let forecast: RainForecast

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: backdrop).resizable().interpolation(.high).frame(width: layout.frame.width, height: layout.frame.height)
            Circle().fill(Color(white: 25 / 255)).frame(width: layout.circleSize + 1, height: layout.circleSize + 1).position(layout.circle)
            Rectangle().fill(.black).frame(width: layout.cover.width, height: layout.cover.height).position(x: layout.cover.midX, y: layout.cover.midY)
            CircularRainGauge(forecast: forecast, palette: .fullColour)
                .frame(width: layout.circleSize, height: layout.circleSize).position(layout.circle)
            // These watches space small text 0.3 points wider than the Mac, not the Ultra's 0.6.
            RectangularRainView(forecast: forecast, palette: .fullColour).tracking(0.3)
                .frame(width: layout.slotSize.width, height: layout.slotSize.height)
                .scaleEffect(layout.shrink, anchor: .topLeading)
                .frame(width: layout.slotSize.width * layout.shrink, height: layout.slotSize.height * layout.shrink, alignment: .topLeading)
                .offset(x: layout.slot.x, y: layout.slot.y)
        }
        .frame(width: layout.frame.width, height: layout.frame.height, alignment: .topLeading)
    }
}

/// The wide slot as Modular Ultra lays it out.
struct WideSlot: View {
    let forecast: RainForecast
    var body: some View {
        RectangularRainView(forecast: forecast, palette: .fullColour).tracking(watchTracking).frame(width: 190, height: 73.5)
    }
}

/// The Smart Stack card (render-mockups, SmartStackMock): the wide view on its own card.
struct StackCard: View {
    let forecast: RainForecast
    var body: some View {
        RectangularRainView(forecast: forecast, palette: .fullColour)
            .tracking(watchTracking)
            .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 4)
            .frame(width: 198, height: 81.5)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(forecast.hasRain ? RainPalette.fullColour.stack : RainPalette.fullColour.stackDry))
    }
}

// ---- The line as numbers, for the film to build in 3D ----

struct Words: Encodable {
    let headline: String
    let detail: String?
    let lead: String?
    let value: String
    let unit: String?
}
struct Line: Encodable {
    /// Minutes from the film's first minute, the second face.
    let minute: Int
    let clock: String
    /// Minutes from the film's first minute to the start of this forecast's two-hour axis.
    let axisStart: Double
    /// Wet stretches as [time 0...1 along the axis, height 0...1] points, from the app's own curve (RainArea).
    let runs: [[[Double]]]
    /// Where the forecast stops along the axis, and where the dot is.
    let known: Double
    let dot: Double?
    let raining: Bool
    let hours: [String]
    let hourAt: [Double]
    let now: String
    /// The dotted lines behind the graph: light, moderate and heavy rain (RainForecast.scaleLines).
    let grid: [Double]
    let words: Words
}

func line(_ index: Int) -> Line {
    let moment = Date(timeIntervalSince1970: faces[index].t)
    let f = forecast(moment)
    let copy = RainCopy(f)
    // RainArea draws time across and height up a rectangle: read its points back on a unit square.
    var runs: [[[Double]]] = []
    RainArea(forecast: f).path(in: CGRect(x: 0, y: 0, width: 1, height: 1)).forEach { element in
        switch element {
        case .move(let p): runs.append([[p.x, 1 - p.y]])
        case .line(let p): runs[runs.count - 1].append([p.x, 1 - p.y])
        default: break
        }
    }
    let marks = hourMarks(f)
    let circular = copy.circular
    return Line(minute: index - 1, clock: RainCopy.clock(moment), axisStart: (f.start.timeIntervalSince1970 - faces[1].t) / 60,
                runs: runs, known: min(1, f.position(of: f.forecastEnd)),
                dot: copy.change.map { f.position(of: $0) }, raining: copy.isRainingNow,
                hours: marks.map { RainCopy.clock($0) }, hourAt: marks.map { f.position(of: $0) },
                now: localized("Now"), grid: RainForecast.scaleLines.map(RainCurve.display),
                words: Words(headline: copy.headline, detail: copy.detail,
                             lead: circular.lead, value: circular.value, unit: circular.unit))
}

func hourMarks(_ f: RainForecast) -> [Date] {
    var marks: [Date] = []
    guard var hour = Calendar.current.nextDate(after: f.start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) else { return [] }
    while hour <= f.end { marks.append(hour); hour = hour.addingTimeInterval(3600) }
    return marks
}

MainActor.assumeIsolated {
    for (index, face) in faces.enumerated() {
        let f = forecast(Date(timeIntervalSince1970: face.t))
        let name = String(format: "%02d.png", index)
        // The face, large enough for the camera to come close to the circle.
        let backdrop = NSImage(contentsOf: facesFolder.appendingPathComponent("\(language)/\(face.file)"))!
        save(FaceShot(backdrop: backdrop, forecast: f), "face/\(name)", scale: 12)
        save(FaceShot(backdrop: backdrop, forecast: f, showsCircle: false), "face-no-circle/\(name)", scale: 12)
        save(FaceShot(backdrop: backdrop, forecast: f, showsCircle: false, showsWide: false), "face-empty/\(name)", scale: 12)
        // The complications alone, for the glass tiles: the circle on its grey disc, the wide slot
        // as the face lays it out, and the Smart Stack card.
        // Each is drawn on black, as the face behind it is: the film puts it on a tile of black glass.
        save(CircularRainGauge(forecast: f, palette: .fullColour, plate: true).frame(width: 45, height: 45).background(Circle().fill(.black)),
             "circle/\(name)", scale: 24)
        save(WideSlot(forecast: f).scaleEffect(FaceShot.shrink).frame(width: 190 * FaceShot.shrink, height: 73.5 * FaceShot.shrink).background(.black),
             "wide/\(name)", scale: 10)
        save(StackCard(forecast: f).background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black)), "stack/\(name)", scale: 8)
    }
    // The other two watches: one screenshot each, named for the language and the clock it shows
    // (en-0754.png). Each is drawn with the forecast of its own minute, so its clock and its words agree.
    let firstClock = RainCopy.clock(Date(timeIntervalSince1970: faces[0].t)).filter(\.isNumber)
    let firstMinutes = Int(firstClock.prefix(2))! * 60 + Int(firstClock.suffix(2))!
    for layout in [OtherFace.Layout.series, .se] {
        let folder = facesFolder.appendingPathComponent(layout.name)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        guard let name = names.first(where: { $0.hasPrefix("\(language)-") }),
              let backdrop = NSImage(contentsOf: folder.appendingPathComponent(name)) else { fatalError("no \(layout.name) face for \(language)") }
        let clock = name.dropFirst(language.count + 1).prefix(4)
        let index = Int(clock.prefix(2))! * 60 + Int(clock.suffix(2))! - firstMinutes
        save(OtherFace(layout: layout, backdrop: backdrop, forecast: forecast(Date(timeIntervalSince1970: faces[index].t))),
             "face-\(layout.name)/shown.png", scale: 12)
        print(language, layout.name, clock, RainCopy(forecast(Date(timeIntervalSince1970: faces[index].t))).headline)
    }
    let lines = faces.indices.map(line)
    try! JSONEncoder().encode(lines).write(to: out.appendingPathComponent("line.json"))
    for l in lines { print(language, l.clock, l.words.headline, "|", l.words.detail ?? "-", "|", [l.words.lead, l.words.value, l.words.unit].compactMap { $0 }.joined(separator: " ")) }
}
