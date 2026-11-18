import RainGraph
import SwiftUI

/// The privacy policy and the terms of the data, reachable from every screen. Each address is also
/// written out: the watch's web view does not open every page.
struct AboutPage: View {
    /// Opened from Apple's legal link: starts at Apple's part.
    var showsApple = false
    @State private var apple = AppleWeatherCredit.saved
    @State private var appleLoaded = AppleWeatherCredit.saved != nil

    static let privacyPolicy = URL(string: "https://jjpcodes.com/rainwatch/privacy")!

    /// KNMI's licence (CC BY 4.0, section 3(a)) asks for its name, the licence, a link to the data
    /// and a note that it was changed. The forecast is `radar_forecast` 2.0 and the past half hour
    /// `nl_rdr_data_rtcor_5m` 1.0 (`server/job.py`).
    static let knmiLinks = [
        URL(string: "https://dataplatform.knmi.nl/dataset/radar-forecast-2-0")!,
        URL(string: "https://doi.org/10.21944/5c23-p429")!,
        URL(string: "https://creativecommons.org/licenses/by/4.0/")!,
    ]

    var body: some View {
        ScrollViewReader { proxy in
            list
                // Below the title bar, so Apple's mark is in view.
                .onAppear { if showsApple { proxy.scrollTo("apple", anchor: UnitPoint(x: 0.5, y: 0.3)) } }
        }
        .navigationTitle(localized("About"))
        .task {
            if apple == nil { apple = await AppleWeatherCredit.load() }
            appleLoaded = true
        }
    }

    private var list: some View {
        List {
            Section {
                link(Self.privacyPolicy, label: localized("Privacy Policy"))
            }
            Section {
                Text(localized("Rain data from KNMI under CC BY 4.0, changed by \(Bundle.main.displayName)."))
                    .font(.footnote)
                    .plainRow()
                ForEach(Self.knmiLinks, id: \.self) { link($0) }
            }
            // Apple's documentation: where its legal page can't be shown in a Safari view, as on the
            // watch, the app shows `legalAttributionText`. Its data is changed into wet or dry steps,
            // which its terms ask to be said beside its mark.
            Section {
                Text(localized("Changed by \(Bundle.main.displayName) into rain or dry, in five-minute or hourly steps."))
                    .font(.footnote)
                    .plainRow()
                if let apple {
                    Text(apple.legalText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .plainRow()
                    link(apple.legalPage)
                } else if appleLoaded {
                    link(AppleWeatherCredit.fallbackLegalPage)
                } else {
                    ProgressView()
                }
            } header: {
                AppleWeatherMark(credit: apple)
                    .id("apple")
            }
        }
    }

    /// A link that also shows where it goes, without "https://".
    private func link(_ url: URL, label: String? = nil) -> some View {
        let address = url.absoluteString.replacingOccurrences(of: "https://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return Link(destination: url) {
            VStack(alignment: .leading, spacing: 2) {
                if let label { Text(label) }
                Text(address)
                    .font(label == nil ? .footnote : .caption2)
                    .foregroundStyle(label == nil ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    /// Words, not a control: no platter behind them, so they don't look tappable.
    func plainRow() -> some View {
        listRowBackground(Color.clear)
    }
}

/// Apple's Weather mark: its own image once loaded, its trademark in text until then.
struct AppleWeatherMark: View {
    let credit: AppleWeatherCredit?
    var height: CGFloat = 12

    var body: some View {
        if let credit, let mark = UIImage(contentsOfFile: credit.markFile.path) {
            Image(uiImage: mark)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityLabel("Apple Weather")
        } else {
            Text("\u{F8FF}Weather")
        }
    }
}
