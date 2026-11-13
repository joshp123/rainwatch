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
        case loading
        case ready(RainForecast, fetched: Date, place: CLLocationCoordinate2D)
        case failed(String)
    }

    @State private var load = Load.loading
    @State private var placeName: String?
    @State private var session: CLServiceSession?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            switch load {
            case .loading:
                ProgressView()
            case let .failed(message):
                Text(message)
                    .navigationTitle("Rain")
            case let .ready(forecast, fetched, place):
                ForecastDetailView(forecast: forecast, fetched: fetched)
                    .padding(.horizontal, 2)
                    .navigationTitle(placeName ?? "Rain")
                    .toolbar {
                        // The radar gets its own screen so the Digital Crown can move it through time.
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink {
                                RadarPage(place: place)
                            } label: {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(.white)
                                    .accessibilityLabel("Radar")
                            }
                        }
                    }
            }
        }
        .tint(RainPalette.buienradarBlue)
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
            let place = try await Place.current().coordinate
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
