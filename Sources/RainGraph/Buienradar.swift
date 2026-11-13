import Foundation

/// Buienradar's graph feed: the data behind the rain graph on its website. Five-minute steps for
/// about three hours, each with Buienradar's own graph height. RainNL3Hour covers the Netherlands
/// in detail; RainEU3Hour covers Europe and is used wherever the Dutch product has no data.
public enum Buienradar {
    public enum Failure: Error {
        /// Neither product covers this place.
        case notCovered
    }

    public static func samples(latitude: Double, longitude: Double, session: URLSession = .shared) async throws -> [RainSample] {
        for product in ["RainNL3Hour", "RainEU3Hour"] {
            if let samples = try await fetch(product, latitude: latitude, longitude: longitude, session: session) {
                return samples
            }
        }
        throw Failure.notCovered
    }

    /// Nil when the product does not cover the place: Buienradar then answers with a JSON string
    /// ("Location not supported by graph type") instead of a graph.
    private static func fetch(_ product: String, latitude: Double, longitude: Double, session: URLSession) async throws -> [RainSample]? {
        var components = URLComponents(string: "https://graphdata.buienradar.nl/3.0/forecast/geo/\(product)")!
        components.queryItems = [
            // Buienradar redirects anything finer to two decimals, about a kilometre.
            URLQueryItem(name: "lat", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", longitude)),
        ]
        let (data, _) = try await session.data(from: components.url!)
        guard let graph = try? JSONDecoder().decode(Graph.self, from: data) else { return nil }
        let samples = graph.forecasts.compactMap { point in
            utc.date(from: point.utcDateTime).map { RainSample(date: $0, height: point.percentageValue) }
        }
        return samples.isEmpty ? nil : samples
    }

    private struct Graph: Decodable {
        struct Point: Decodable {
            let utcDateTime: String
            let percentageValue: Double
        }

        let forecasts: [Point]
    }

    private static let utc: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
