import CoreLocation
import MapKit
import RainGraph
import SwiftUI
import WidgetKit

@main
struct RainApp: App {
    #if DEBUG
    init() {
        // `-scenario showerComing` also puts that saved forecast on the watch face, to check the
        // complications on the real face. It runs at launch, so it works with the screen off.
        UserDefaults(suiteName: Place.appGroup)?.set(UserDefaults.standard.string(forKey: "scenario"), forKey: "debugScenario")
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

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
        case failed(Failure)
    }

    /// What went wrong, in Apple's empty-state layout, with the way out.
    enum Failure: String {
        case noLocation, offline, notCovered, noForecast
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
            case let .failed(failure):
                failed(failure)
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

    @ViewBuilder private func failed(_ failure: Failure) -> some View {
        switch failure {
        case .noLocation:
            ContentUnavailableView("Location Needed", systemImage: "location.slash",
                                   description: Text("Allow Rain in Settings, Privacy & Security, Location Services."))
        case .offline:
            ContentUnavailableView {
                Label("No Connection", systemImage: "wifi.slash")
            } description: {
                Text("Buienradar can't be reached.")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
            }
        case .notCovered:
            ContentUnavailableView("No Forecast Here", systemImage: "mappin.slash",
                                   description: Text("Buienradar covers the Netherlands and nearby countries."))
        case .noForecast:
            ContentUnavailableView {
                Label("No Forecast", systemImage: "cloud.rain")
            } description: {
                Text("Buienradar sent an empty forecast.")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
            }
        }
    }

    private func refresh() async {
        #if DEBUG
        // Screenshots of every state: `-scenario showerComing` shows a saved forecast instead of
        // fetching one, and `-failure offline` shows a failure.
        if let name = UserDefaults.standard.string(forKey: "failure"), let failure = Failure(rawValue: name) {
            load = .failed(failure)
            return
        }
        if let name = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = Scenario.allCases.first(where: { "\($0)" == name }) {
            load = .ready(scenario.forecast(at: .now), fetched: .now, place: CLLocationCoordinate2D(latitude: 51.92, longitude: 4.48))
            placeName = scenario.place
            return
        }
        #endif
        session = CLServiceSession(authorization: .whenInUse)
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = CLLocationManager().authorizationStatus == .notDetermined
            let place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
            if case .loading = load { load = .loading("Asking Buienradar") }
            let snapshot = try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude)
            guard let forecast = RainForecast.at(.now, from: snapshot.samples) else {
                load = .failed(.noForecast)
                return
            }
            load = .ready(forecast, fetched: snapshot.fetched, place: place)
            // Free of the widget budget while the app is in front.
            WidgetCenter.shared.reloadAllTimelines()
            placeName = try? await MKReverseGeocodingRequest(location: CLLocation(latitude: place.latitude, longitude: place.longitude))?
                .mapItems.first?.addressRepresentations?.cityName
        } catch Place.Failure.noLocation {
            load = .failed(.noLocation)
        } catch Buienradar.Failure.notCovered {
            load = .failed(.notCovered)
        } catch {
            load = .failed(.offline)
        }
    }
}
