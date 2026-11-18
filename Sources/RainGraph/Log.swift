import Foundation
import OSLog

/// What the app and the widget are doing, as it happens: every key event, every stage with how
/// long it took, and every change of what is on screen (the states in STATES.md).
///
/// Every build sends it to the system log and to signposts, under the subsystem `nl.jjp.rain`, so
/// Console and Instruments show where a slow launch spends its time. Debug builds also keep the
/// last events in a file in the app group, to copy off a real watch (AGENTS.md).
///
/// Nothing private goes in a message: no coordinates and no place names, only what happened, how
/// long it took and how old things were.
public enum Log {
    private static let logger = Logger(subsystem: "nl.jjp.rain", category: "events")
    private static let signposter = OSSignposter(subsystem: "nl.jjp.rain", category: "stages")
    /// "app" or "widget": both write to the same log.
    private static let process = Bundle.main.bundlePath.hasSuffix(".appex") ? "widget" : "app"

    public static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        #if DEBUG
        keep(message)
        #endif
    }

    /// Runs one stage inside a signpost interval and logs how long it took, or that it failed.
    public static func stage<T>(_ name: StaticString, isolation: isolated (any Actor)? = #isolation,
                                _ work: () async throws -> T) async rethrows -> T {
        let interval = signposter.beginInterval(name)
        let start = ContinuousClock.now
        defer { signposter.endInterval(name, interval) }
        do {
            let result = try await work()
            event("\(name): \(seconds(since: start))")
            return result
        } catch {
            event("\(name): failed after \(seconds(since: start)): \(String(describing: error).prefix(120))")
            throw error
        }
    }

    public static func seconds(since start: ContinuousClock.Instant) -> String {
        let elapsed = ContinuousClock.now - start
        return String(format: "%.2f s", Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
    }

    /// Minutes since `date`, for ages.
    public static func age(of date: Date, now: Date = .now) -> String {
        "\(Int((now.timeIntervalSince(date) / 60).rounded())) min old"
    }

    #if DEBUG
    /// The file, in Library: the only part of the container a Mac may copy from a real watch.
    public static var file: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Place.appGroup)?
            .appendingPathComponent("Library/events.log")
    }

    private static let lock = NSLock()
    private static let limit = 200_000

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private static func keep(_ message: String) {
        guard let file else { return }
        lock.lock()
        defer { lock.unlock() }
        let line = Data("\(stamp.string(from: .now)) \(process) \(message)\n".utf8)
        // Rolling: past the limit, the older half goes.
        if let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int, size > limit,
           let all = try? Data(contentsOf: file) {
            let rest = all.suffix(limit / 2).drop { $0 != UInt8(ascii: "\n") }.dropFirst()
            try? Data(rest).write(to: file, options: .atomic)
        }
        // O_APPEND: the app and the widget write the same file, and each line must land whole.
        let descriptor = open(file.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else { return }
        line.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
        close(descriptor)
    }
    #endif
}
