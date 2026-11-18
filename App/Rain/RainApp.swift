import CoreLocation
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
        // `-hideText YES` draws no words of RainWatch's own, on the face too: the design file lays
        // its editable words over these pictures.
        shared?.set(UserDefaults.standard.bool(forKey: "hideText"), forKey: "debugHideText")
        // `-freshInstall YES` starts as a new install would, for the path Apple's reviewer takes.
        if UserDefaults.standard.bool(forKey: "freshInstall") {
            Place.forget()
            Snapshot.forget()
        }
        // `-pickedPlace Utrecht` shows the scenario as the forecast for a place picked by name.
        if let name = UserDefaults.standard.string(forKey: "pickedPlace") {
            Place.choose(Place.Chosen(name: name, latitude: 0, longitude: 0))
        }
        WidgetCenter.shared.reloadAllTimelines()
        Log.event("launched: debug build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"), \(Self.sinceProcessStart) after the process started")
    }
    #else
    init() {
        Log.event("launched: build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"), \(Self.sinceProcessStart) after the process started")
    }
    #endif

    #if DEBUG
    static let hidesText = UserDefaults.standard.bool(forKey: "hideText")
    #else
    static let hidesText = false
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .hidesTextForDesign(Self.hidesText)
        }
    }

    /// Seconds since the process started, so the log shows what a launch cost before the app's own
    /// code ran.
    static var sinceProcessStart: String {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0 else { return "an unknown time" }
        let started = Double(info.kp_proc.p_starttime.tv_sec) + Double(info.kp_proc.p_starttime.tv_usec) / 1e6
        return String(format: "%.2f s", Date.now.timeIntervalSince1970 - started)
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
    @State private var session: CLServiceSession?
    @State private var picking = false
    /// The radar page is open. Debug builds can start on it (`-radar YES`), for screenshots.
    @State private var showsRadar = ContentView.startsOnRadar
    /// Set once Continue is tapped on the intro, so the system's question comes when it's expected.
    @State private var askedForLocation = false
    /// Counts refreshes, so one that a newer one has overtaken cannot write its result: opening the
    /// app, Try Again and picking a place each start one, and they can overlap.
    @State private var refreshes = 0
    @State private var refreshing = false
    @State private var lastRefresh: ContinuousClock.Instant?
    @Environment(\.scenePhase) private var scenePhase

    /// Every change of what is on screen goes through here, so the log holds each transition of
    /// STATES.md as it really happened.
    private func move(to next: Load, because reason: String) {
        Log.event("screen: \(Self.name(load)) -> \(Self.name(next)) (\(reason))")
        load = next
        logWhenDrawn()
    }

    /// The main thread is busy until the new screen is laid out and drawn, so the next thing it
    /// runs marks the moment the screen is up.
    private func logWhenDrawn() {
        let changed = ContinuousClock.now
        Task { Log.event("drawn \(Log.seconds(since: changed)) after the change") }
    }

    private static func name(_ load: Load) -> String {
        switch load {
        case .intro: "first launch"
        case .loading: "loading"
        case let .ready(_, issued, source, _): "forecast (\(source.rawValue), data \(Log.age(of: issued)))"
        case let .failed(problem): "problem \(problem)"
        }
    }

    private func reloadWidgets(because reason: String) {
        Log.event("asked the widgets to reload (\(reason))")
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some View {
        NavigationStack {
            switch load {
            case .intro:
                // Apple's rule for a screen before a permission question: one button, which opens
                // the question. Choosing a place is offered after a refusal instead.
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("To see the rain where you are, choose Allow While Using App."))
                    Spacer(minLength: 0)
                    Button(localized("Continue")) { askForLocation() }
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
                        Button(localized("Try Again")) {
                            couldNotUpdate = false
                            Task { await refresh("Try Again") }
                        }
                        .padding(.top, 10)
                    }
                    // With a location there is nothing to choose. A picked place can be changed.
                    if Place.chosen != nil {
                        Button { picking = true } label: {
                            Label(localized("Change Place"), systemImage: "mappin.and.ellipse")
                        }
                        .padding(.top, 10)
                    }
                    NavigationLink { AboutPage() } label: {
                        Label(localized("About"), systemImage: "info.circle")
                    }
                    .padding(.top, 10)
                }
                // The arrow is Apple's mark for "where you are"; a picked place has none. A town's
                // name from Apple Maps would need its map beside it (Attachment 6, 2.4), so where you
                // are is "My Location", and a picked place is called what the wearer typed.
                .navigationTitle {
                    // A long name shrinks before it is cut short.
                    Group {
                        if let chosen = Place.chosen {
                            Text(chosen.name)
                        } else {
                            Label(localized("My Location"), systemImage: "location.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                // Apple's Weather colours its pages by the weather; blue here means rain is due.
                .containerBackground((forecast.hasRain ? RainPalette.buienradarBlue.opacity(0.45) : Color.black).gradient,
                                     for: .navigation)
                .toolbar {
                    // The radar gets its own screen so the Digital Crown can move it through time.
                    // It draws KNMI's radar, so it is there only where KNMI's forecast is used.
                    if source == .knmi {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showsRadar = true } label: {
                                Label(localized("Radar"), systemImage: "map")
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showsRadar) {
                    RadarPage(place: place, forecast: forecast)
                }
            }
        }
        .sheet(isPresented: $picking) {
            PlacePicker { place in
                Place.choose(place)
                picking = false
                move(to: .loading, because: place == nil ? "Use My Location" : "a place was picked")
                couldNotUpdate = false
                Task { await refresh("place changed") }
            }
        }
        .onAppear {
            Log.event("first screen: \(Self.name(load)), \(RainApp.sinceProcessStart) after the process started")
            logWhenDrawn()
        }
        // The first refresh starts with the app, whatever the scene is doing: waiting for the scene
        // to turn active left the spinner up for as long as it did not (seen on Josh's watch).
        .task { await refresh("launch") }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Log.event("scene: active")
                // One that is running, or that ended moments ago at launch, will do.
                if !refreshing, lastRefresh.map({ $0.duration(to: .now) > .seconds(10) }) ?? true {
                    Task { await refresh("app came to the front") }
                }
            case .background:
                Log.event("scene: background")
                // Apple's advice: one last reload as the app leaves, while it is still free.
                reloadWidgets(because: "app left the screen")
            default:
                break
            }
        }
    }

    /// A problem in Apple's empty-state layout, in the words the face uses for it too (`Problem`).
    private func failed(_ problem: Problem) -> some View {
        ContentUnavailableView {
            // The symbol goes where its room is needed: with two buttons the second runs off the
            // screen, and a sentence of steps pushes the button out of view.
            if problem.actions.count > 1 || (problem.detail?.count ?? 0) > 40 {
                Text(problem.title).font(.title3.bold())
            } else {
                Label(problem.title, systemImage: problem.symbol)
            }
        } description: {
            if let detail = problem.detail { Text(detail) }
        } actions: {
            ForEach(problem.actions.indices, id: \.self) { index in
                // Without a line of description the title sits on the first button.
                button(problem.actions[index])
                    .padding(.top, index == 0 && problem.detail == nil ? 8 : 0)
            }
        }
    }

    @ViewBuilder private func button(_ action: Problem.Action) -> some View {
        switch action {
        case .tryAgain: Button(localized("Try Again")) { Task { await refresh("Try Again") } }
        case .choosePlace: Button(localized("Choose a Place")) { picking = true }
        // Blue, as on the first launch: the button that opens the system's question.
        case .allowLocation:
            Button(localized("Continue")) { askForLocation() }
                .buttonStyle(.borderedProminent)
                .tint(RainPalette.buienradarBlue)
        }
    }

    private static var startsOnRadar: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "radar")
        #else
        false
        #endif
    }

    /// The intro before location has ever been asked; else the saved forecast; else a spinner.
    private static var firstScreen: Load {
        if Place.chosen == nil, CLLocationManager().authorizationStatus == .notDetermined { return askScreen }
        return saved ?? .loading
    }

    /// The screen before the system's location question: the intro the first time, and once Allow
    /// Once has run out, the reason it is asked again.
    private static var askScreen: Load {
        Place.wasAllowed ? .failed(.locationExpired) : .intro
    }

    /// Opens the system's location question: Continue on the intro, and on Location Expired.
    private func askForLocation() {
        move(to: .loading, because: "Continue")
        askedForLocation = true
        Task { await refresh("Continue") }
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
            move(to: .ready(forecast, issued: snapshot.issued, source: snapshot.source, place: place),
                 because: updateFailed ? "the update failed, the saved forecast stands in" : "forecast fetched")
            couldNotUpdate = updateFailed
        case let .problem(problem):
            move(to: .failed(problem), because: "no forecast to show")
            couldNotUpdate = false
        }
    }

    private func refresh(_ trigger: String) async {
        #if DEBUG
        // Screenshots of every state: `-scenario showerComing` shows a saved forecast instead of
        // fetching one, and `-failure offline` shows a failure.
        if let name = UserDefaults.standard.string(forKey: "failure"), let problem = Problem.named(name, launched: RainApp.launched) {
            move(to: problem == .locationNotAsked ? .intro : .failed(problem), because: "-failure option")
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
            move(to: .ready(forecast, issued: run, source: .knmi,
                            place: CLLocationCoordinate2D(latitude: scenario.coordinate.latitude, longitude: scenario.coordinate.longitude)),
                 because: "-scenario option")
            couldNotUpdate = UserDefaults.standard.bool(forKey: "couldNotUpdate")
            return
        }
        if let name = UserDefaults.standard.string(forKey: "scenario"),
           let scenario = AppleScenario.allCases.first(where: { "\($0)" == name }),
           let forecast = scenario.forecast(at: .now) {
            // `-age 40` makes Apple's test forecast that many minutes old.
            let age = Double(max(5, UserDefaults.standard.integer(forKey: "age"))) * 60
            move(to: .ready(forecast, issued: .now.addingTimeInterval(-age), source: scenario.resolution == .hourly ? .appleHourly : .appleMinute,
                            place: CLLocationCoordinate2D(latitude: scenario.coordinate.latitude, longitude: scenario.coordinate.longitude)),
                 because: "-scenario option")
            return
        }
        #endif
        refreshes += 1
        let mine = refreshes
        let started = ContinuousClock.now
        Log.event("refresh \(mine): started (\(trigger))")
        refreshing = true
        defer {
            if mine == refreshes {
                refreshing = false
                lastRefresh = .now
            }
            Log.event("refresh \(mine): \(mine == refreshes ? "done" : "overtaken by refresh \(refreshes)") after \(Log.seconds(since: started))")
        }
        let chosen = Place.chosen
        // Someone who refused location gets the choice of a place, not their last known position.
        let status = CLLocationManager().authorizationStatus
        if chosen == nil, status == .denied || status == .restricted {
            // The face must stop showing the last place too.
            Place.note(status)
            reloadWidgets(because: "location is off")
            move(to: .failed(.locationOff), because: "location is refused or off")
            return
        }
        if chosen == nil, status == .notDetermined, !askedForLocation {
            move(to: Self.askScreen, because: Place.wasAllowed ? "location was allowed, and must be asked again" : "location was never answered")
            return
        }
        session = chosen == nil ? CLServiceSession(authorization: .whenInUse) : nil
        // A place known within the hour is at hand without waiting, so its forecast goes on screen
        // at once. A new fix follows, and if it is somewhere else the forecast is fetched again.
        if chosen == nil, CLLocationManager().authorizationStatus != .notDetermined, let recent = Place.recent {
            Log.event("place: recent fix, \(Log.age(of: recent.at)), used while a new one is found")
            guard await fetchAndShow(recent.coordinate, refresh: mine) else { return }
            guard let fresh = try? await Place.current(), fresh.isLive, mine == refreshes else { return }
            let moved = CLLocation(latitude: fresh.coordinate.latitude, longitude: fresh.coordinate.longitude)
                .distance(from: CLLocation(latitude: recent.coordinate.latitude, longitude: recent.coordinate.longitude)) > 1500
            Log.event("place: the new fix is \(moved ? "over" : "within") 1.5 km of the recent one")
            if moved { _ = await fetchAndShow(fresh.coordinate, refresh: mine) }
            return
        }
        let place: CLLocationCoordinate2D
        do {
            // The first time, Core Location waits for an answer to its permission question.
            let asking = chosen == nil && CLLocationManager().authorizationStatus == .notDetermined
            place = try await Place.current(timeout: .seconds(asking ? 120 : 8)).coordinate
        } catch {
            // No place, so no forecast: the one on screen is for where the wearer was.
            guard mine == refreshes else { return }
            // The question went unanswered: back to the screen that asks it.
            if error as? Place.Failure == .notAsked {
                askedForLocation = false
                move(to: Self.askScreen, because: "location still not answered")
                return
            }
            move(to: .failed(Problem(error as? Place.Failure ?? .notFound)), because: "no place")
            couldNotUpdate = false
            return
        }
        _ = await fetchAndShow(place, refresh: mine)
    }

    /// Fetches the forecast for a place and shows what `Situation.after` decides. False when a
    /// newer refresh has taken over the screen.
    private func fetchAndShow(_ place: CLLocationCoordinate2D, refresh mine: Int) async -> Bool {
        let fetch: Situation.Fetch
        do {
            fetch = .fetched(try await Snapshot.fetch(latitude: place.latitude, longitude: place.longitude))
        } catch Snapshot.Failure.offline {
            fetch = .unreachable
        } catch {
            fetch = .refused
        }
        // A refresh started later owns the screen: its place and its forecast are the newer ones.
        guard mine == refreshes else { return false }
        show(.after(fetch, latitude: place.latitude, longitude: place.longitude, saved: Snapshot.saved, now: .now), place: place)
        guard case let .fetched(snapshot) = fetch else { return true }
        // Free of the widget budget while the app is in front. A reused forecast is one the widgets
        // already have.
        if snapshot.requests > 0 { reloadWidgets(because: "new forecast") }
        return true
    }
}

/// Who made the forecast on screen. KNMI's licence (CC BY 4.0) asks for its name; Apple's terms ask
/// for its Weather mark and a link to its legal page wherever its data is shown. On the watch that
/// link opens the About page, which shows Apple's legal text.
struct Credit: View {
    let source: Snapshot.Source
    /// When the forecast was made: one line says whose it is and how recent.
    let issued: Date
    var showsTime = true
    @State private var apple = AppleWeatherCredit.saved

    var body: some View {
        if source.isApple {
            // The whole line is the link, so it is big enough to tap.
            NavigationLink { AboutPage(showsApple: true) } label: {
                HStack(spacing: 6) {
                    AppleWeatherMark(credit: apple)
                    if showsTime {
                        Text(RainCopy.clock(issued))
                            .foregroundStyle(.secondary)
                    }
                    // Blue means rain, so the link is underlined instead. It follows the time
                    // rather than the trailing edge, where the Ultra's rounded corner cuts it off.
                    Text(localized("Legal"))
                        .foregroundStyle(.secondary)
                        .underline()
                    Spacer(minLength: 0)
                }
                .font(.footnote)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .task { if apple == nil { apple = await AppleWeatherCredit.load() } }
        } else {
            Text(showsTime ? localized("KNMI forecast made \(RainCopy.clock(issued))") : localized("Source: KNMI"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
