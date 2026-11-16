import Foundation

/// KNMI's rain forecast, as BuienWatch's server publishes it (`server/job.py`): a pack holding every
/// 32 km square of KNMI's 1 km grid, and `latest`, which names the run and the length of each square
/// in the pack. The watch works out its own cell, reads `latest`, and downloads only its square, so
/// only the square leaves the watch, never the position. `server/watch_client.py` does the same in
/// Python.
public enum KNMI {
    /// Where the server publishes. Debug builds can point at a local copy (`-server` launch option).
    public static var server: URL {
        #if DEBUG
        if let debug = UserDefaults(suiteName: Place.appGroup)?.string(forKey: "debugServer"), let url = URL(string: debug) {
            return url
        }
        #endif
        return URL(string: "https://rain.jjpcodes.com")!
    }

    public static let rows = 765, columns = 700

    /// A cell of KNMI's 1 km grid. Row 0 is the north edge.
    public struct Cell: Hashable, Codable, Sendable {
        public let row: Int
        public let column: Int
    }

    /// The grid cell holding a place, or nil outside KNMI's grid.
    public static func cell(latitude: Double, longitude: Double) -> Cell? {
        let (x, y) = gridPoint(latitude: latitude, longitude: longitude)
        let row = Int(y.rounded(.down)), column = Int(x.rounded(.down))
        guard (0..<rows).contains(row), (0..<columns).contains(column) else { return nil }
        return Cell(row: row, column: column)
    }

    /// Where a place falls on the grid, in cells: column `x` and row `y`, with cell centres at
    /// half-cell positions. KNMI's grid is polar stereographic, true at 60° N, on the WGS84 ellipsoid,
    /// with row 0 at 3,650 km south of the pole: the closed form needs no projection library.
    public static func gridPoint(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        let a = 6378.137, b = 6356.752
        let e = (1 - (b / a) * (b / a)).squareRoot()
        func t(_ phi: Double) -> Double {
            tan(.pi / 4 - phi / 2) / pow((1 - e * sin(phi)) / (1 + e * sin(phi)), e / 2)
        }
        let north = 60 * Double.pi / 180
        let rho = a * cos(north) / (1 - pow(e * sin(north), 2)).squareRoot() * t(latitude * .pi / 180) / t(north)
        let lambda = longitude * .pi / 180
        return (rho * sin(lambda), rho * cos(lambda) - 3650)
    }

    /// The contents list for the newest run.
    public struct Latest: Decodable, Sendable {
        public let run: Date
        public let blend: Bool
        public let firstFrameMinutes: Int
        public let frames: Int
        public let stepMinutes: Int
        public let squareKm: Int
        public let rows: Int
        public let columns: Int
        public let pack: String
        /// Bytes of each square in the pack: 0 every cell dry with data, -1 no radar coverage.
        public let squares: [Int]

        enum CodingKeys: String, CodingKey {
            case run, blend, frames, pack, squares, rows, columns
            case firstFrameMinutes = "first_frame_minutes", stepMinutes = "step_minutes", squareKm = "square_km"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let stamp = try container.decode(String.self, forKey: .run)
            guard let run = KNMI.runFormat.date(from: stamp) else {
                throw DecodingError.dataCorruptedError(forKey: .run, in: container, debugDescription: "run \(stamp)")
            }
            self.run = run
            blend = try container.decode(Bool.self, forKey: .blend)
            firstFrameMinutes = try container.decode(Int.self, forKey: .firstFrameMinutes)
            frames = try container.decode(Int.self, forKey: .frames)
            stepMinutes = try container.decode(Int.self, forKey: .stepMinutes)
            squareKm = try container.decode(Int.self, forKey: .squareKm)
            rows = try container.decode(Int.self, forKey: .rows)
            columns = try container.decode(Int.self, forKey: .columns)
            pack = try container.decode(String.self, forKey: .pack)
            squares = try container.decode([Int].self, forKey: .squares)
        }

        public func date(ofFrame frame: Int) -> Date {
            run.addingTimeInterval(Double(firstFrameMinutes + frame * stepMinutes) * 60)
        }

        func square(holding cell: Cell) -> Int {
            (cell.row / squareKm) * columns + cell.column / squareKm
        }

        /// Where a run of squares lies in the pack: squares sit back to back, row by row.
        func byteRange(of indices: ClosedRange<Int>) -> (offset: Int, length: Int) {
            let offset = squares[..<indices.lowerBound].reduce(0) { $0 + max($1, 0) }
            let length = squares[indices].reduce(0) { $0 + max($1, 0) }
            return (offset, length)
        }

        /// Cells in a square: squares along the south and east edges of the grid are smaller.
        func size(ofSquare index: Int) -> (rows: Int, columns: Int) {
            let (row, column) = index.quotientAndRemainder(dividingBy: columns)
            return (min(squareKm, KNMI.rows - row * squareKm), min(squareKm, KNMI.columns - column * squareKm))
        }
    }

    public static func latest(session: URLSession = .shared) async throws -> Latest {
        var request = URLRequest(url: server.appendingPathComponent("latest"))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        try check(response)
        return try JSONDecoder().decode(Latest.self, from: data)
    }

    /// One place's values for every frame of the run: mm/h, 0 dry, nil no data. Nil when its square
    /// has no radar coverage. In rain this is one range request; a dry square needs none.
    public static func samples(at cell: Cell, in latest: Latest, session: URLSession = .shared) async throws -> [RainSample]? {
        let index = latest.square(holding: cell)
        let length = latest.squares[index]
        if length < 0 { return nil }
        let values: [UInt8]
        if length == 0 {
            values = Array(repeating: 0, count: latest.frames)
        } else {
            let square = try await squares(index...index, in: latest, session: session)[index] ?? []
            let width = latest.size(ofSquare: index).columns
            let at = ((cell.row % latest.squareKm) * width + cell.column % latest.squareKm) * latest.frames
            guard square.count >= at + latest.frames else { throw Failure.badPack }
            values = Array(square[at..<(at + latest.frames)])
        }
        return values.enumerated().map { frame, value in
            RainSample(date: latest.date(ofFrame: frame), rate: rate(value))
        }
    }

    /// One byte per value: 0 dry, 255 no data, 1–250 rain from 0.1 mm/h, 50 steps per factor of ten.
    public static func rate(_ value: UInt8) -> Double? {
        switch value {
        case 0: 0
        case 255: nil
        default: 0.1 * pow(10, Double(value - 1) / 50)
        }
    }

    /// The unpacked squares with rain among `indices`, which must lie in one row of squares, so that
    /// they are one byte range of the pack and one request. Each square is its cells row by row, each
    /// cell all its frames.
    public static func squares(_ indices: ClosedRange<Int>, in latest: Latest, session: URLSession = .shared) async throws -> [Int: [UInt8]] {
        let (offset, length) = latest.byteRange(of: indices)
        guard length > 0 else { return [:] }
        var request = URLRequest(url: server.appendingPathComponent(latest.pack))
        request.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        let (data, response) = try await session.data(for: request)
        try check(response)
        // A server that ignores the range sends the whole pack.
        let bytes = (response as? HTTPURLResponse)?.statusCode == 206 ? data : data.subdata(in: offset..<min(data.count, offset + length))
        guard bytes.count == length else { throw Failure.badPack }
        var result: [Int: [UInt8]] = [:]
        var at = 0
        for index in indices where latest.squares[index] > 0 {
            let compressed = bytes.subdata(in: at..<(at + latest.squares[index]))
            at += latest.squares[index]
            // Raw DEFLATE, which is what Foundation calls zlib.
            guard let square = try? (compressed as NSData).decompressed(using: .zlib) as Data else { throw Failure.badPack }
            let size = latest.size(ofSquare: index)
            guard square.count == size.rows * size.columns * latest.frames else { throw Failure.badPack }
            result[index] = [UInt8](square)
        }
        return result
    }

    public enum Failure: Error {
        case badPack
        case status(Int)
    }

    private static func check(_ response: URLResponse) throws {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return }
        guard (200..<300).contains(status) else { throw Failure.status(status) }
    }

    static let runFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return formatter
    }()
}
