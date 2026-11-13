import SwiftUI

/// The app's first page: what the complications say, with room to read it. Buienradar's own graph
/// at full height on its linear scale, so it looks like the website, with its Light, Moderate and
/// Heavy lines named. The place is the page title; when the forecast was fetched sits at the foot.
public struct ForecastDetailView: View {
    let forecast: RainForecast
    let fetched: Date
    let palette: RainPalette

    public init(forecast: RainForecast, fetched: Date, palette: RainPalette = .fullColour) {
        self.forecast = forecast
        self.fetched = fetched
        self.palette = palette
    }

    public var body: some View {
        let copy = RainCopy(forecast)
        VStack(alignment: .leading, spacing: 0) {
            Text(copy.headline)
                .font(RainFont.rounded(19, .semibold))
                .foregroundStyle(palette.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let detail = copy.detail {
                Text(detail)
                    .font(RainFont.rounded(15, .medium))
                    .foregroundStyle(palette.rain)
                    .padding(.top, 1)
            }
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    RainChart(forecast: forecast, palette: palette, scale: .linear)
                    TimeAxis(forecast: forecast, palette: palette)
                }
                ScaleLabels(palette: palette)
                    .padding(.bottom, 16)
            }
            .padding(.top, 10)
            Text("Updated \(RainCopy.clock(fetched))")
                .font(RainFont.rounded(12, .medium))
                .foregroundStyle(palette.secondary)
                .padding(.top, 6)
        }
    }
}

/// Buienradar's own graph names only its outer lines, "Licht" and "Zwaar".
struct ScaleLabels: View {
    let palette: RainPalette

    var body: some View {
        GeometryReader { proxy in
            ForEach([(25.0, "Light"), (75.0, "Heavy")], id: \.0) { line, name in
                Text(name)
                    .font(RainFont.rounded(9.5, .medium))
                    .foregroundStyle(palette.secondary)
                    .fixedSize()
                    .position(x: proxy.size.width / 2, y: proxy.size.height * (1 - line / 100))
            }
        }
        .frame(width: 30)
    }
}
