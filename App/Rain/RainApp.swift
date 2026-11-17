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
        // `-server http://127.0.0.1:8765` reads the forecast from a local copy of the server's
        // files; the widget reads it from the app group.
        shared?.set(UserDefaults.standard.string(forKey: "server"), forKey: "debugServer")
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
        case ready(RainForecast, issued: Date, source: Snapshot.Source, place: CLLocationCoordinate2D)
        case failed(Failure)
    }

    /// What went wrong, in Apple's empty-state layout, with the way out.
    enum Failure: Equatable {
        case noLocation
        case offline(Snapshot.Source)
        /// Apple refused the call or had no forecast: never shown as dry.
        case noForecast
        /// KNMI's newest forecast is over an hour old: the server or KNMI has stopped.
        case stale(since: Date)

        #if DEBUG
        init?(debugName: String) {
            switch debugName {
            case "noLocation": self = .noLocation
            case "offline": self = .offline(.knmi)
            case "noForecast": self = .noForecast
            case "stale": self = .stale(since: Date(timeIntervalSince1970: ((Date.now.timeIntervalSince1970 - 75 * 60) / 300).rounded(.down) * 300))
            default: return nil
            }
        }
        #endif
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
                    // Both ways in fit on the first screen: Apple's reviewer may refuse location.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rain where you are")
                            .font(.title3.weight(.semibold))
                        Text("Next, choose Allow While Using App to keep your watch face up to date.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Continue") {
                            load = .loading("Finding where you are")
                            askedForLocation = true
                            Task { await refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RainPalette.buienradarBlue)
                        Button("Choose a Place") { picking = true }
                    }
                    .scenePadding(.horizontal)
                }
            case let .loading(stage):
                ProgressView(stage)
            case let .failed(failure):
                failed(failure)
            case let .ready(forecast, issued, source, place):
                ScrollView {
                    // First on the page, so it is seen without scrolling: the forecast below is old.
                    if couldNotUpdate {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Couldn’t update. This forecast is from \(RainCopy.clock(issued)).", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Try Again") {
                                couldNotUpdate = false
                                Task { await refresh() }
                            }
                        }
                        .scenePadding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    ForecastDetailView(forecast: forecast, issued: issued)
                        .scenePadding(.horizontal)
                    Credit(source: source)
                        .scenePadding(.horizontal)
                        .padding(.top, 2)
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
                    // It draws KNMI's radar, so it is there only where KNMI's forecast is used.
                    if source == .knmi {
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
        }
        .sheet(isPresented: $picking) {
            PlacePicker { place in
                Place.choose(place)
                picking = false
                placeName = place?.name
                load = .loading(place == nil ? "Finding where you are" : "Getting the forecast")
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
        case let .offline(source):
            ContentUnavailableView {
                Label("No Connection", systemImage: "wifi.slash")
            } description: {
                Text(source == .knmi ? "KNMI’s forecast can’t be reached." : "Apple Weather can’t be reached.")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
                Button("Choose a Place") { picking = true }
            }
        case let .stale(since):
            ContentUnavailableView {
                Label("No Recent Forecast", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text("KNMI’s newest forecast is from \(RainCopy.clock(since)).")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
            }
        case .noForecast:
            ContentUnavailableView {
                Label("No Forecast", systemImage: "cloud.rain")
            } description: {
                Text("Apple Weather has no forecast for this place right now.")
            } actions: {
                Button("Try Again") { Task { await refresh() } }
                Button("Choose a Place") { picking = true }
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
        guard let snapshot = Snapshot.saved, let forecast = snapshot.forecast(at: .now) else { return nil }
        return .ready(forecast, issued: snapshot.issued, source: snapshot.source,
                      place: CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude))
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

    /// The town's name, asked for with the position rounded to about 1 km, as the location question
    /// promises.
    private static func town(at place: CLLocationCoordinate2D) async -> String? {
        let rounded = CLLocation(latitude: (place.latitude * 100).rounded() / 100, longitude: (place.longitude * 100).rounded() / 100)
        return try? await MKReverseGeocodingRequest(location: rounded)?
            .mapItems.first?.addressRepresentations?.cityName
    }

    private func refresh() async {
        #if DEBUG
        // Screenshots of every state: `-scenario showerComing` shows a saved forecast instead of
        // fetching one, and `-failure offline` shows a failure.
        if let name = UserDefaults.standard.string(forKey: "failure"), let failure = Failure(debugName: name) {
            load = .failed(failure)
            return
        }
        if let name = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = Scenario.allCases.first(where: { "\($0)" == name }) {
            // As a watch sees a KNMI run: the run on a five-minute mark at least ten minutes ago,
            // its data from ten minutes after it, and what is left of that from now.
            let run = Date(timeIntervalSince1970: ((Date.now.timeIntervalSince1970 - Scenario.age) / 300).rounded(.down) * 300)
            guard let forecast = RainForecast.at(.now, from: scenario.forecast(at: run.addingTimeInterval(Scenario.age)).samples) else { return }
            load = .ready(forecast, issued: run, source: .knmi,
                          place: CLLocationCoordinate2D(latitude: scenario.coordinate.latitude, longitude: scenario.coordinate.longitude))
            placeName = scenario.place
            return
        }
        if let name = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = AppleScenario.allCases.first(where: { "\($0)" == name }),
           let forecast = scenario.forecast(at: .now) {
            load = .ready(forecast, issued: .now.addingTimeInterval(-5 * 60), source: scenario.resolution == .hourly ? .appleHourly : .appleMinute,
                          place: CLLocationCoordinate2D(latitude: scenario.coordinate.latitude, longitude: scenario.coordinate.longitude))
            placeName = scenario.place
            return
        }
        #endif
        let chosen = Place.chosen
        // Someone who refused location gets the choice of a place, not their last known position.
        let status = CLLocationManager().authorizationStatus
        if chosen == nil, status == .denied || status == .restricted {
            // The face must stop showing the last place too.
            Place.noteRefused(true)
            WidgetCenter.shared.reloadAllTimelines()
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
            if placeName == nil, case let .ready(_, _, _, saved) = load {
                Task { if placeName == nil { placeName = await Self.town(at: saved) } }
            }
            session = CLServiceSession(authorization: .whenInUse)
        }
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = chosen == nil && CLLocationManager().authorizationStatus == .notDetermined
            let place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
            if case .loading = load { load = .loading("Getting the forecast") }
            let snapshot = try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude)
            guard let forecast = snapshot.forecast(at: .now) else {
                fail(snapshot.source == .knmi ? .stale(since: snapshot.issued) : .noForecast)
                return
            }
            load = .ready(forecast, issued: snapshot.issued, source: snapshot.source, place: place)
            couldNotUpdate = false
            // Free of the widget budget while the app is in front.
            WidgetCenter.shared.reloadAllTimelines()
            if chosen == nil { placeName = await Self.town(at: place) ?? placeName }
        } catch Place.Failure.noLocation {
            fail(.noLocation)
        } catch let Snapshot.Failure.offline(source) {
            fail(.offline(source))
        } catch {
            fail(.noForecast)
        }
    }
}

/// Who made the forecast on screen. KNMI's licence (CC BY 4.0) asks for its name; Apple's terms ask
/// for its Weather mark and a link to its legal page wherever its data is shown.
struct Credit: View {
    let source: Snapshot.Source
    @State private var apple = AppleWeatherCredit.saved

    var body: some View {
        if source.isApple {
            HStack(spacing: 6) {
                if let apple, let mark = UIImage(contentsOfFile: apple.markFile.path) {
                    Image(uiImage: mark)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                        .accessibilityLabel("Apple Weather")
                } else {
                    Text("\u{F8FF}Weather")
                }
                Link("Legal", destination: apple?.legalPage ?? AppleWeatherCredit.fallbackLegalPage)
                    .foregroundStyle(RainPalette.buienradarBlue)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task { if apple == nil { apple = await AppleWeatherCredit.load() } }
        } else {
            Text("Source: KNMI")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
