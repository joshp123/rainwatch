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
        let shared = UserDefaults(suiteName: Place.appGroup)
        shared?.set(UserDefaults.standard.string(forKey: "scenario"), forKey: "debugScenario")
        shared?.set(Date.now, forKey: "debugScenarioSet")
        // `-freshInstall YES` starts as a new install would, for the path Apple's reviewer takes.
        if UserDefaults.standard.bool(forKey: "freshInstall") {
            Place.forget()
            Snapshot.forget()
        }
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
        /// Before the first location question: says which answer keeps the face up to date.
        case intro
        case loading(String)
        case ready(RainForecast, fetched: Date, place: CLLocationCoordinate2D)
        case failed(Failure)
    }

    /// What went wrong, in Apple's empty-state layout, with the way out.
    enum Failure: String {
        case noLocation, offline, notCovered, noForecast
    }

    /// Opens on the forecast the face was just showing, if it is still fresh, and refreshes over it.
    @State private var load = ContentView.firstScreen
    /// The last refresh failed while an older forecast is on screen.
    @State private var couldNotUpdate = false
    @State private var placeName: String?
    @State private var session: CLServiceSession?
    @State private var picking = false
    /// Set once Continue is tapped on the intro, so the system's question comes when it's expected.
    @State private var askedForLocation = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            switch load {
            case .intro:
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rain where you are")
                            .font(.title3.weight(.semibold))
                        Text("\(Bundle.main.displayName) needs your location. On the next screen, choose Allow While Using App, so your watch face stays up to date.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Button("Continue") {
                            load = .loading("Finding where you are")
                            askedForLocation = true
                            Task { await refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RainPalette.buienradarBlue)
                        .padding(.top, 4)
                        Button("Choose a Place") { picking = true }
                    }
                    .scenePadding(.horizontal)
                }
            case let .loading(stage):
                ProgressView(stage)
            case let .failed(failure):
                failed(failure)
            case let .ready(forecast, fetched, place):
                ScrollView {
                    ForecastDetailView(forecast: forecast, fetched: fetched)
                        .scenePadding(.horizontal)
                    if couldNotUpdate {
                        Button("Try Again") { Task { await refresh() } }
                            .padding(.top, 6)
                    }
                    Button { picking = true } label: {
                        Label(Place.chosen == nil ? "Choose a Place" : "Change Place", systemImage: "mappin.and.ellipse")
                    }
                    .padding(.top, 10)
                }
                .navigationTitle(placeName ?? Bundle.main.displayName)
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
        .sheet(isPresented: $picking) {
            PlacePicker { place in
                Place.choose(place)
                picking = false
                placeName = place?.name
                load = .loading(place == nil ? "Finding where you are" : "Asking Buienradar")
                couldNotUpdate = false
                Task { await refresh() }
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
            ContentUnavailableView {
                Label("Location Needed", systemImage: "location.slash")
            } description: {
                Text("Allow location for \(Bundle.main.displayName) in Settings, or choose a place.")
            } actions: {
                Button("Choose a Place") { picking = true }
            }
        case .offline:
            ContentUnavailableView {
                Label("No Connection", systemImage: "wifi.slash")
            } description: {
                Text("Buienradar can't be reached.")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
            }
        case .notCovered:
            ContentUnavailableView {
                Label("No Forecast Here", systemImage: "mappin.slash")
            } description: {
                Text("Buienradar covers the Netherlands and nearby countries.")
            } actions: {
                Button("Choose a Place") { picking = true }
            }
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

    /// The intro before location has ever been asked; else the saved forecast; else a spinner.
    private static var firstScreen: Load {
        if Place.chosen == nil, CLLocationManager().authorizationStatus == .notDetermined { return .intro }
        return saved ?? .loading("Finding where you are")
    }

    private static var saved: Load? {
        if Place.chosen == nil, [.denied, .restricted].contains(CLLocationManager().authorizationStatus) {
            return .failed(.noLocation)
        }
        guard let snapshot = Snapshot.saved, Date.now < snapshot.staleAt,
              let forecast = RainForecast.at(.now, from: snapshot.samples) else { return nil }
        return .ready(forecast, fetched: snapshot.fetched, place: CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude))
    }

    /// With a forecast on screen, a failed refresh keeps it and offers to try again; without one,
    /// it shows what went wrong.
    private func fail(_ failure: Failure) {
        if case .ready = load {
            couldNotUpdate = true
        } else {
            load = .failed(failure)
        }
    }

    private static func town(at place: CLLocationCoordinate2D) async -> String? {
        try? await MKReverseGeocodingRequest(location: CLLocation(latitude: place.latitude, longitude: place.longitude))?
            .mapItems.first?.addressRepresentations?.cityName
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
        let chosen = Place.chosen
        // Someone who refused location gets the choice of a place, not their last known position.
        let status = CLLocationManager().authorizationStatus
        if chosen == nil, status == .denied || status == .restricted {
            load = .failed(.noLocation)
            return
        }
        if chosen == nil, status == .notDetermined, !askedForLocation {
            load = .intro
            return
        }
        if let chosen {
            placeName = chosen.name
            session = nil
        } else {
            // Opened on the saved forecast: name its town at once rather than after the fetch.
            if placeName == nil, case let .ready(_, _, saved) = load {
                Task { if placeName == nil { placeName = await Self.town(at: saved) } }
            }
            session = CLServiceSession(authorization: .whenInUse)
        }
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = chosen == nil && CLLocationManager().authorizationStatus == .notDetermined
            let place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
            if case .loading = load { load = .loading("Asking Buienradar") }
            let snapshot = try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude)
            guard let forecast = RainForecast.at(.now, from: snapshot.samples) else {
                fail(.noForecast)
                return
            }
            load = .ready(forecast, fetched: snapshot.fetched, place: place)
            couldNotUpdate = false
            // Free of the widget budget while the app is in front.
            WidgetCenter.shared.reloadAllTimelines()
            if chosen == nil { placeName = await Self.town(at: place) ?? placeName }
        } catch Place.Failure.noLocation {
            fail(.noLocation)
        } catch Buienradar.Failure.notCovered {
            fail(.notCovered)
        } catch {
            fail(.offline)
        }
    }
}
