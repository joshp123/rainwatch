import CoreLocation
import RainGraph
import SwiftUI
import WidgetKit

@main
struct RainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// The app exists to hold location permission and to show the forecast when opened. Every time it
/// fetches, it saves the place and asks WidgetKit to reload the complications.
struct ContentView: View {
    enum Load {
        case loading
        case ready(RainForecast, fetched: Date)
        case failed(String)
    }

    @State private var load = Load.loading
    @State private var session: CLServiceSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch load {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case let .ready(forecast, fetched):
                    CircularRainGauge(forecast: forecast, palette: .fullColour)
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity)
                    RectangularRainView(forecast: forecast, palette: .fullColour)
                        .frame(height: 82)
                    Text("Buienradar, \(fetched.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case let .failed(message):
                    Text(message)
                        .font(.body)
                }
            }
            .padding(.horizontal, 4)
        }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        session = CLServiceSession(authorization: .whenInUse)
        do {
            let place = try await Place.current()
            let samples = try await Buienradar.samples(latitude: place.latitude, longitude: place.longitude)
            guard let forecast = RainForecast.at(.now, from: samples) else {
                load = .failed("Buienradar sent no forecast.")
                return
            }
            load = .ready(forecast, fetched: .now)
            WidgetCenter.shared.reloadAllTimelines()
        } catch Place.Failure.noLocation {
            load = .failed("Rain needs your location. Allow it in Settings, Privacy & Security, Location Services, Rain.")
        } catch Buienradar.Failure.notCovered {
            load = .failed("Buienradar has no forecast for where you are.")
        } catch {
            load = .failed("Buienradar could not be reached. \(error.localizedDescription)")
        }
    }
}
