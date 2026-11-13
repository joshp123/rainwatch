import Charts
import SwiftUI

/// The app's first page: what the complications say, with room to read it, and Buienradar's own
/// graph for the two hours drawn the way Apple draws charts on the watch. App text uses the
/// system's text styles, so it matches Apple's apps and follows the wearer's text size.
public struct ForecastDetailView: View {
    let forecast: RainForecast
    let fetched: Date

    public init(forecast: RainForecast, fetched: Date) {
        self.forecast = forecast
        self.fetched = fetched
    }

    public var body: some View {
        let copy = RainCopy(forecast)
        VStack(alignment: .leading, spacing: 2) {
            Text(copy.headline)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            if let detail = copy.detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(RainPalette.buienradarBlue)
            }
            ForecastChart(forecast: forecast)
                .frame(height: 100)
                .padding(.top, 8)
            Text("Updated \(RainCopy.clock(fetched))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Buienradar's graph in Swift Charts: height on its own 0–100 scale, with its Light and Heavy
/// lines labelled inside the plot so the chart keeps the full width; "Now" and whole hours below.
/// The labels sit at the far end, two hours out, where rain matters least if they cover it.
public struct ForecastChart: View {
    let forecast: RainForecast

    public init(forecast: RainForecast) {
        self.forecast = forecast
    }

    public var body: some View {
        let points = RainCurve.points(forecast, scale: .linear)
        Chart {
            ForEach(points.indices, id: \.self) { index in
                let point = points[index]
                AreaMark(x: .value("Time", date(point.t)), y: .value("Rain", point.v * 100))
                    .foregroundStyle(RainPalette.buienradarBlue.gradient)
            }
            if let change = RainCopy(forecast).change {
                PointMark(x: .value("Change", change), y: .value("Rain", 0))
                    .symbol { ChangeDot(palette: .fullColour, diameter: 9) }
            }
        }
        .chartXScale(domain: forecast.start...forecast.end)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [forecast.start] + labelledHours) { value in
                AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 1))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date == forecast.start ? "Now" : RainCopy.clock(date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .inset, position: .trailing, values: [25, 75]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                AxisValueLabel {
                    Text(value.as(Double.self) == 25 ? "Light" : "Heavy")
                }
            }
        }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                Rectangle().fill(.secondary).frame(height: 1)
            }
        }
        .accessibilityLabel(RainCopy(forecast).spoken)
    }

    private func date(_ t: Double) -> Date {
        forecast.start.addingTimeInterval(t * RainForecast.window)
    }

    /// Hours far enough from "Now" not to read as one label with it.
    private var labelledHours: [Date] {
        forecast.hourMarks.filter { $0.timeIntervalSince(forecast.start) >= 25 * 60 }
    }
}
