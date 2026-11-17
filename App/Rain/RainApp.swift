import CoreLocation
import MapKit
import RainGraph
import SwiftUI
import WidgetKit

@main
struct RainApp: App {
    #if DEBUG
    /// When this launch began: the app and the face date a test forecast from it, so they agree.
    static let launched = Date.now

    init() {
        // `-scenario showerComing` also puts that saved forecast on the watch face, to check the
        // complications on the real face. It runs at launch, so it works with the screen off.
        let shared = UserDefaults(suiteName: Place.appGroup)
        // `-failure stale` puts that state on the face as well.
        shared?.set(UserDefaults.standard.string(forKey: "scenario") ?? UserDefaults.standard.string(forKey: "failure"), forKey: "debugScenario")
        shared?.set(Self.launched, forKey: "debugScenarioSet")
        // `-server http://127.0.0.1:8765` reads the forecast from a local copy of the server's
        // files; the widget reads it from the app group.
        shared?.set(UserDefaults.standard.string(forKey: "server"), forKey: "debugServer")
        // `-age 32` makes the saved forecast that many minutes old, on the face too.
        shared?.set(UserDefaults.standard.integer(forKey: "age"), forKey: "debugAge")
        // `-slotStyle 2` draws the face's large slot in one of the styles under comparison.
        shared?.set(UserDefaults.standard.integer(forKey: "slotStyle"), forKey: "debugSlotStyle")
        // `-freshInstall YES` starts as a new install would, for the path Apple's reviewer takes.
        if UserDefaults.standard.bool(forKey: "freshInstall") {
            Place.forget()
            Snapshot.forget()
        }
        // `-pickedPlace Utrecht` shows the scenario as the forecast for a place picked by name.
        if let name = UserDefaults.standard.string(forKey: "pickedPlace") {
            Place.choose(Place.Chosen(name: name, detail: "", latitude: 0, longitude: 0))
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
        case loading
        case ready(RainForecast, issued: Date, source: Snapshot.Source, place: CLLocationCoordinate2D)
        case failed(Problem)
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
    /// Counts refreshes, so one that a newer one has overtaken cannot write its result: opening the
    /// app, Try Again and picking a place each start one, and they can overlap.
    @State private var refreshes = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            switch load {
            case .intro:
                // Apple's rule for a screen before a permission question: one button, which opens
                // the question. Choosing a place is offered after a refusal instead.
                VStack(alignment: .leading, spacing: 6) {
                    Text("To see live rain data where you are, choose Allow While Using App.")
                    Spacer(minLength: 0)
                    Button("Continue") {
                        load = .loading
                        askedForLocation = true
                        Task { await refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RainPalette.buienradarBlue)
                }
                .scenePadding(.horizontal)
            case .loading:
                ProgressView()
            case let .failed(failure):
                failed(failure)
            case let .ready(forecast, issued, source, place):
                ScrollView {
                    ForecastDetailView(forecast: forecast, issued: issued, couldNotUpdate: couldNotUpdate)
                        .scenePadding(.horizontal)
                    // Whose forecast it is and when it was made, in view under the graph.
                    // An old forecast already says its time on the second line.
                    Credit(source: source, issued: issued, showsTime: forecast.now.timeIntervalSince(issued) < Snapshot.oldAfter || couldNotUpdate)
                        .scenePadding(.horizontal)
                        .padding(.top, 4)
                    if couldNotUpdate {
                        Button("Try Again") {
                            couldNotUpdate = false
                            Task { await refresh() }
                        }
                        .padding(.top, 10)
                    }
                    // With a location there is nothing to choose. A picked place can be changed.
                    if Place.chosen != nil {
                        Button { picking = true } label: {
                            Label("Change Place", systemImage: "mappin.and.ellipse")
                        }
                        .padding(.top, 10)
                    }
                }
                // The arrow is Apple's mark for "where you are"; a picked place has none.
                .navigationTitle {
                    if Place.chosen == nil, let placeName {
                        Label(placeName, systemImage: "location.fill")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Text(placeName ?? Bundle.main.displayName)
                    }
                }
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
                load = .loading
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

    /// A problem in Apple's empty-state layout, in the words the face uses for it too (`Problem`).
    private func failed(_ problem: Problem) -> some View {
        ContentUnavailableView {
            // With two buttons the symbol goes: with it, the second button runs off the screen.
            if problem.actions.count > 1 {
                Text(problem.title).font(.title3.bold())
            } else {
                Label(problem.title, systemImage: problem.symbol)
            }
        } description: {
            if let detail = problem.detail { Text(detail) }
        } actions: {
            ForEach(problem.actions.indices, id: \.self) { index in
                let button = switch problem.actions[index] {
                case .tryAgain: Button("Try Again") { Task { await refresh() } }
                case .choosePlace: Button("Choose a Place") { picking = true }
                }
                // Without a line of description the title sits on the first button.
                button.padding(.top, index == 0 && problem.detail == nil ? 8 : 0)
            }
        }
    }

    /// The intro before location has ever been asked; else the saved forecast; else a spinner.
    private static var firstScreen: Load {
        if Place.chosen == nil, CLLocationManager().authorizationStatus == .notDetermined { return .intro }
        return saved ?? .loading
    }

    private static var saved: Load? {
        if Place.chosen == nil, [.denied, .restricted].contains(CLLocationManager().authorizationStatus) {
            return .failed(.locationOff)
        }
        guard let snapshot = Snapshot.saved, let forecast = snapshot.forecast(at: .now) else { return nil }
        return .ready(forecast, issued: snapshot.issued, source: snapshot.source,
                      place: CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude))
    }

    /// Shows a situation. Every refresh ends here, so the screen is always one of the states in
    /// STATES.md.
    private func show(_ situation: Situation, place: CLLocationCoordinate2D) {
        switch situation {
        case let .forecast(forecast, snapshot, updateFailed):
            load = .ready(forecast, issued: snapshot.issued, source: snapshot.source, place: place)
            couldNotUpdate = updateFailed
        case let .problem(problem):
            load = .failed(problem)
            couldNotUpdate = false
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
        if let name = UserDefaults.standard.string(forKey: "failure"), let problem = Problem.named(name, launched: RainApp.launched) {
            load = problem == .locationNotAsked ? .intro : .failed(problem)
            return
        }
        if let name = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = Scenario.allCases.first(where: { "\($0)" == name }) {
            // As a watch sees a KNMI run: the run on a five-minute mark at least ten minutes ago,
            // its data from ten minutes after it, and what is left of that from now.
            // `-age 32` shows the same run that many minutes old; `-couldNotUpdate YES` as it is
            // after a refresh that failed.
            let age = max(Scenario.age, Double(UserDefaults.standard.integer(forKey: "age")) * 60)
            let run = Date(timeIntervalSince1970: ((RainApp.launched.timeIntervalSince1970 - age) / 300).rounded(.down) * 300)
            guard let forecast = RainForecast.at(.now, from: scenario.forecast(at: run.addingTimeInterval(Scenario.age)).samples) else { return }
            load = .ready(forecast, issued: run, source: .knmi,
                          place: CLLocationCoordinate2D(latitude: scenario.coordinate.latitude, longitude: scenario.coordinate.longitude))
            placeName = Place.chosen?.name ?? scenario.place
            couldNotUpdate = UserDefaults.standard.bool(forKey: "couldNotUpdate")
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
        refreshes += 1
        let mine = refreshes
        let chosen = Place.chosen
        // Someone who refused location gets the choice of a place, not their last known position.
        let status = CLLocationManager().authorizationStatus
        if chosen == nil, status == .denied || status == .restricted {
            // The face must stop showing the last place too.
            Place.noteRefused(true)
            WidgetCenter.shared.reloadAllTimelines()
            load = .failed(.locationOff)
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
        let place: CLLocationCoordinate2D
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = chosen == nil && CLLocationManager().authorizationStatus == .notDetermined
            place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
        } catch {
            // No place, so no forecast: the one on screen is for where the wearer was.
            guard mine == refreshes else { return }
            load = .failed(Problem(error as? Place.Failure ?? .notFound))
            couldNotUpdate = false
            return
        }
        let fetch: Situation.Fetch
        do {
            fetch = .fetched(try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude))
        } catch Snapshot.Failure.offline {
            fetch = .unreachable
        } catch {
            fetch = .refused
        }
        // A refresh started later owns the screen: its place and its forecast are the newer ones.
        guard mine == refreshes else { return }
        show(.after(fetch, latitude: place.latitude, longitude: place.longitude, saved: Snapshot.saved, now: .now), place: place)
        guard case .fetched = fetch else { return }
        // Free of the widget budget while the app is in front.
        WidgetCenter.shared.reloadAllTimelines()
        if chosen == nil, let town = await Self.town(at: place), mine == refreshes { placeName = town }
    }
}

/// Who made the forecast on screen. KNMI's licence (CC BY 4.0) asks for its name; Apple's terms ask
/// for its Weather mark and a link to its legal page wherever its data is shown.
struct Credit: View {
    let source: Snapshot.Source
    /// When the forecast was made: one line says whose it is and how recent.
    let issued: Date
    var showsTime = true
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
                if showsTime {
                    Text(RainCopy.clock(issued))
                        .foregroundStyle(.secondary)
                }
                // Blue means rain, so the link is underlined instead.
                Link("Legal", destination: apple?.legalPage ?? AppleWeatherCredit.fallbackLegalPage)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task { if apple == nil { apple = await AppleWeatherCredit.load() } }
        } else {
            Text(showsTime ? "KNMI forecast from \(RainCopy.clock(issued))" : "Source: KNMI")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
