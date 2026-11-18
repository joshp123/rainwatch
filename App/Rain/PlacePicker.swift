import MapKit
import RainGraph
import SwiftUI

/// Finds a town by name, for people who don't share their location and for anyone who wants the
/// rain somewhere else. Picking one, or going back to the wearer's location, calls `pick`.
///
/// The results come from Apple Maps, whose terms (Attachment 6, 2.4) ask for an address result to be
/// shown with its map: each one shows where it is. A picked place keeps Apple's name for it.
struct PlacePicker: View {
    let pick: (Place.Chosen?) -> Void

    @State private var query = ""
    @State private var results: [Result]?
    @State private var searching = false

    struct Result: Hashable {
        let name: String
        /// Region and country, to tell apart places with the same name.
        let detail: String
        let latitude: Double
        let longitude: Double

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    var body: some View {
        NavigationStack {
            List {
                // A plain field, always in view with its prompt. Apple's search field (`searchable`)
                // stays hidden above an empty list on the watch, so nothing said what to type.
                TextField(localized("Town or postcode"), text: $query)
                    .textContentType(.addressCity)
                    .onSubmit { Task { await search() } }
                if searching {
                    ProgressView()
                } else if let results, results.isEmpty {
                    Text(localized("No places found"))
                        .foregroundStyle(.secondary)
                }
                ForEach(results ?? [], id: \.self) { place in
                    Section {
                        Button { pick(Place.Chosen(name: place.name, latitude: place.latitude, longitude: place.longitude)) } label: {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                if !place.detail.isEmpty {
                                    Text(place.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        // Outside the button, so Apple's logo and Legal link on the map still work.
                        Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)),
                            interactionModes: []) {
                            Marker(place.name, coordinate: place.coordinate)
                        }
                        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                if Place.chosen != nil {
                    Button { pick(nil) } label: {
                        Label(localized("Use My Location"), systemImage: "location.fill")
                    }
                }
            }
            .navigationTitle(localized("Place"))
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        searching = true
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        let items = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        let found = items.map { item in
            let name = item.name ?? text
            // "Springfield, MO, United States" and "3511 AB Utrecht, Netherlands" say which one; the
            // row's first line already has the name.
            let full = item.address?.fullAddress ?? item.addressRepresentations?.regionName ?? ""
            let detail = (full.hasPrefix(name) ? String(full.dropFirst(name.count)) : full)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
            return Result(name: name, detail: detail, latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
        }
        // The watch can return a town twice, once without its country; one row each is enough.
        results = found.reduce(into: []) { unique, place in
            let twin = found.contains { $0.name == place.name && !$0.detail.isEmpty }
            if place.detail.isEmpty, twin { return }
            if !unique.contains(where: { $0.name == place.name && $0.detail == place.detail }) { unique.append(place) }
        }
    }
}
