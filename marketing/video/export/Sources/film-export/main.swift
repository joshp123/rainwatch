// Written by AI on 2026.11.18 by model claude opus 5.5.
// Draws everything the launch film shows of the app, with the app's own code (RainGraph), for one
// language: run it with `-AppleLanguages '(nl)'` for Dutch. See marketing/video/README.md.
//   film-export <public folder> <language>
// Reads public/gen/map.json (data.py) and public/face/<language>/*.png; writes public/gen/<language>/.
import AppKit
import RainGraph
import SwiftUI

let public_ = URL(fileURLWithPath: CommandLine.arguments[1])
let language = CommandLine.arguments[2]
let out = public_.appendingPathComponent("gen/\(language)")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// ---- The forecast: KNMI's run for the place, its run time moved to the clock on the face ----

struct Map: Decodable {
    struct Place: Decodable { let name: String }
    let firstFrameMinutes: Int
    let stepMinutes: Int
    let series: [Double?]
    let place: Place
}
let map = try JSONDecoder().decode(Map.self, from: Data(contentsOf: public_.appendingPathComponent("gen/map.json")))

/// The face screenshots, one a minute (capture.sh in git history), and the clock each shows.
struct Face: Decodable { let t: Double; let file: String }
let faces = try JSONDecoder().decode([Face].self, from: Data(contentsOf: public_.appendingPathComponent("face/\(language)/faces.json")))

/// The run's radar time on the face's clock: on a five-minute mark, nine minutes before the first
/// face, as a watch has it a few minutes after KNMI measures it.
let run = Date(timeIntervalSince1970: ((faces[0].t - 9 * 60) / 300).rounded(.down) * 300)
let samples = map.series.enumerated().compactMap { index, rate -> RainSample? in
    let minutes = map.firstFrameMinutes + index * map.stepMinutes
    return minutes >= 0 ? RainSample(date: run.addingTimeInterval(Double(minutes) * 60), rate: rate) : nil
}
func forecast(_ moment: Date) -> RainForecast { RainForecast.at(moment, from: samples)! }

// ---- Rendering ----

/// The watch spaces small text more widely than the Mac draws SF Compact Rounded: matched against
/// the simulator's own screenshots of the face (README, "How true it is").
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
    static let circle = CGPoint(x: 105.5, y: 216.5)
    static let slot = CGPoint(x: 22.5, y: 116)
    static let shrink: CGFloat = 0.884

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: backdrop).resizable().interpolation(.high).frame(width: 211, height: 257)
            // Cover what the screenshot showed in the slots.
            Circle().fill(Color(white: 25 / 255)).frame(width: 46, height: 46).position(Self.circle)
            Rectangle().fill(.black).frame(width: 172, height: 67).position(x: Self.slot.x + 84, y: Self.slot.y + 32.5)
            CircularRainGauge(forecast: forecast, palette: .fullColour)
                .frame(width: 45, height: 45).position(Self.circle)
            RectangularRainView(forecast: forecast, palette: .fullColour)
                .tracking(watchTracking)
                .frame(width: 190, height: 73.5)
                .scaleEffect(Self.shrink, anchor: .topLeading)
                .frame(width: 190 * Self.shrink, height: 73.5 * Self.shrink, alignment: .topLeading)
                .offset(x: Self.slot.x, y: Self.slot.y)
        }
        .frame(width: 211, height: 257, alignment: .topLeading)
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

// ---- The line as numbers, for the film to draw and bend ----

struct Words: Encodable {
    let headline: String
    let detail: String?
    let detailIsAboutRain: Bool
    let lead: String?
    let value: String
    let unit: String?
}
struct Line: Encodable {
    let minute: Int
    let clock: String
    /// Wet stretches as [time 0...1, height 0...1] points, from the app's own curve (RainArea).
    let runs: [[[Double]]]
    let known: Double
    let dot: Double?
    let hours: [[String]]
    let hourAt: [Double]
    let now: String
    /// The dotted lines behind the graph: light, moderate and heavy rain (RainForecast.scaleLines).
    let grid: [Double]
    let words: Words
}

func line(_ minute: Int) -> Line {
    let moment = Date(timeIntervalSince1970: faces[0].t + Double(minute) * 60)
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
    return Line(minute: minute, clock: RainCopy.clock(moment), runs: runs, known: min(1, f.position(of: f.forecastEnd)),
                dot: copy.change.map { f.position(of: $0) }, hours: marks.map { [RainCopy.clock($0)] }, hourAt: marks.map { f.position(of: $0) },
                now: localized("Now"), grid: RainForecast.scaleLines.map(RainCurve.display),
                words: Words(headline: copy.headline, detail: copy.detail, detailIsAboutRain: copy.detailIsAboutRain,
                             lead: circular.lead, value: circular.value, unit: circular.unit))
}

func hourMarks(_ f: RainForecast) -> [Date] {
    var marks: [Date] = []
    guard var hour = Calendar.current.nextDate(after: f.start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) else { return [] }
    while hour <= f.end { marks.append(hour); hour = hour.addingTimeInterval(3600) }
    return marks
}

MainActor.assumeIsolated {
    // The face, one picture a minute.
    for (index, face) in faces.enumerated() {
        let backdrop = NSImage(contentsOf: public_.appendingPathComponent("face/\(language)/\(face.file)"))!
        save(FaceShot(backdrop: backdrop, forecast: forecast(Date(timeIntervalSince1970: face.t))),
             String(format: "face/%02d.png", index), scale: 4)
    }
    // The complications large, alone, for every minute of the face.
    for index in faces.indices {
        let f = forecast(Date(timeIntervalSince1970: faces[index].t))
        save(CircularRainGauge(forecast: f, palette: .fullColour, plate: true).frame(width: 45, height: 45),
             String(format: "circle/%02d.png", index), scale: 16)
        save(StackCard(forecast: f), String(format: "stack/%02d.png", index), scale: 8)
        // The wide slot as the face lays it out, on its own.
        save(RectangularRainView(forecast: f, palette: .fullColour).tracking(watchTracking).frame(width: 190, height: 73.5),
             String(format: "wide/%02d.png", index), scale: 8)
    }
    // The other real forecasts from the same run (Scenario), for the circle's other states.
    var states: [String: [String]] = [:]
    for scenario in Scenario.allCases {
        save(CircularRainGauge(forecast: scenario.forecast, palette: .fullColour, plate: true).frame(width: 45, height: 45),
             "circle/\(scenario).png", scale: 16)
        let words = RainCopy(scenario.forecast).circular
        states["\(scenario)"] = [words.lead, words.value, words.unit].compactMap { $0 }
    }
    try! JSONEncoder().encode(states).write(to: out.appendingPathComponent("states.json"))
    let lines = faces.indices.map(line)
    try! JSONEncoder().encode(lines).write(to: out.appendingPathComponent("line.json"))
    print("\(language): \(faces.count) faces; first says \"\(lines[0].words.headline)\", last \"\(lines.last!.words.headline)\"")
}
