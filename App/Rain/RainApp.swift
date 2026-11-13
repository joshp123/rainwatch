import CoreLocation
import MapKit
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

/// The forecast, with the radar map one tap away. The app also holds
/// location permission; every time it fetches, it saves the place and reloads the complications.
struct ContentView: View {
    enum Load {
        case loading(String)
        case ready(RainForecast, fetched: Date, place: CLLocationCoordinate2D)
        case failed(String)
    }

    @State private var load = Load.loading("Finding where you are")
    @State private var placeName: String?
    @State private var session: CLServiceSession?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            switch load {
            case let .loading(stage):
                ProgressView(stage)
            case let .failed(message):
                Text(message)
                    .navigationTitle("Rain")
            case let .ready(forecast, fetched, place):
                ScrollView {
                    ForecastDetailView(forecast: forecast, fetched: fetched)
                        .scenePadding(.horizontal)
                }
                .navigationTitle(placeName ?? "Rain")
                // Apple's Weather colours its pages by the weather; blue here means rain is due.
                .containerBackground((forecast.hasRain ? RainPalette.buienradarBlue.opacity(0.45) : Color.black).gradient,
                                     for: .navigation)
                .toolbar {
                    // The radar gets its own screen so the Digital Crown can move it through time.
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            RadarPage(place: place, forecast: forecast)
                        } label: {
                            Label("Radar", systemImage: "map")
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                Task { await refresh() }
            case .background:
                // Apple's advice: one last reload as the app leaves, while it is still free.
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }

    private func refresh() async {
        session = CLServiceSession(authorization: .whenInUse)
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = CLLocationManager().authorizationStatus == .notDetermined
            let place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
            if case .loading = load { load = .loading("Asking Buienradar") }
            let snapshot = try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude)
            guard let forecast = RainForecast.at(.now, from: snapshot.samples) else {
                load = .failed("Buienradar sent no forecast.")
                return
            }
            load = .ready(forecast, fetched: snapshot.fetched, place: place)
            // Free of the widget budget while the app is in front.
            WidgetCenter.shared.reloadAllTimelines()
            placeName = try? await MKReverseGeocodingRequest(location: CLLocation(latitude: place.latitude, longitude: place.longitude))?
                .mapItems.first?.addressRepresentations?.cityName
        } catch Place.Failure.noLocation {
            load = .failed("Rain needs your location. Allow it in Settings, Privacy & Security, Location Services, Rain.")
        } catch Buienradar.Failure.notCovered {
            load = .failed("Buienradar has no forecast for where you are.")
        } catch {
            load = .failed("Buienradar could not be reached. \(error.localizedDescription)")
        }
    }
}
