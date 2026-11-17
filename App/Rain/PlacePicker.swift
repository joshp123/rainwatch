import MapKit
import RainGraph
import SwiftUI

/// Finds a town by name, for people who don't share their location and for anyone who wants the
/// rain somewhere else. Picking one, or going back to the wearer's location, calls `pick`.
struct PlacePicker: View {
    let pick: (Place.Chosen?) -> Void

    @State private var query = ""
    @State private var results: [Place.Chosen]?
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                // A plain field, always in view with its prompt. Apple's search field (`searchable`)
                // stays hidden above an empty list on the watch, so nothing said what to type.
                TextField("Town or postcode", text: $query)
                    .textContentType(.addressCity)
                    .onSubmit { Task { await search() } }
                if searching {
                    ProgressView()
                } else if let results, results.isEmpty {
                    Text("No places found")
                        .foregroundStyle(.secondary)
                }
                ForEach(results ?? [], id: \.self) { place in
                    Button { pick(place) } label: {
                        VStack(alignment: .leading) {
                            Text(place.name)
                            if !place.detail.isEmpty {
                                Text(place.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if Place.chosen != nil {
                    Button { pick(nil) } label: {
                        Label("Use My Location", systemImage: "location.fill")
                    }
                }
            }
            .navigationTitle("Place")
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
            return Place.Chosen(name: name, detail: detail,
                                latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
        }
        // The watch can return a town twice, once without its country; one row each is enough.
        results = found.reduce(into: []) { unique, place in
            let twin = found.contains { $0.name == place.name && !$0.detail.isEmpty }
            if place.detail.isEmpty, twin { return }
            if !unique.contains(where: { $0.name == place.name && $0.detail == place.detail }) { unique.append(place) }
        }
    }
}
