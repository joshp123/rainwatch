import Charts
import SwiftUI

/// The app's first page: what the complications say, with room to read it, and the rain graph for
/// the two hours drawn the way Apple draws charts on the watch. App text uses the system's text
/// styles, so it matches Apple's apps and follows the wearer's text size.
public struct ForecastDetailView: View {
    let forecast: RainForecast
    /// When the data was made: its age, which the page states.
    let issued: Date

    public init(forecast: RainForecast, issued: Date) {
        self.forecast = forecast
        self.issued = issued
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
                .frame(height: forecast.hasRain ? 100 : 40)
                .padding(.top, 8)
            Text("Forecast from \(RainCopy.clock(issued))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The rain graph in Swift Charts: a line with a fading fill over its wet stretches only, on
/// the complications' square-root height, with the Light and Heavy lines labelled inside the plot
/// so the chart keeps the full width; "Now" and whole hours below.
/// The labels sit at the far end, two hours out, where rain matters least if they cover it.
public struct ForecastChart: View {
    let forecast: RainForecast

    public init(forecast: RainForecast) {
        self.forecast = forecast
    }

    public var body: some View {
        // The same square-root height as the complications, so one shower has one shape; the
        // Light and Heavy lines then sit at half and seven-eighths of the height.
        let runs = RainCurve.wetRuns(forecast, scale: .squareRoot)
        Chart {
            ForEach(runs.indices, id: \.self) { run in
                ForEach(runs[run].indices, id: \.self) { index in
                    let point = runs[run][index]
                    AreaMark(x: .value("Time", date(point.t)), y: .value("Rain", point.v * 100), series: .value("Spell", run))
                        .foregroundStyle(LinearGradient(colors: [RainPalette.buienradarBlue.opacity(0.8), RainPalette.buienradarBlue.opacity(0.25)],
                                                        startPoint: .top, endPoint: .bottom))
                }
                // The line follows the rain only: at the window's edges the area closes with a
                // vertical side, which as a line would read as rain starting from nothing.
                let edge = Array(runs[run].dropFirst().dropLast())
                ForEach(edge.indices, id: \.self) { index in
                    LineMark(x: .value("Time", date(edge[index].t)), y: .value("Rain", edge[index].v * 100), series: .value("Spell", run))
                        .foregroundStyle(RainPalette.buienradarBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            if let change = RainCopy(forecast).change {
                PointMark(x: .value("Change", change), y: .value("Rain", 0))
                    .symbol { ChangeDot(palette: .fullColour, diameter: 11) }
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
            // With no rain there is nothing to measure, so no scale: Josh's rule for the circle, "if
            // there's no rain we should just have no line".
            AxisMarks(preset: .inset, position: .trailing, values: forecast.hasRain ? Self.scaleLines : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                // Above its rule, so the label never breaks the dashed line.
                AxisValueLabel(anchor: .bottomTrailing) {
                    Text(value.as(Double.self) == Self.scaleLines[0] ? "Light" : "Heavy")
                }
            }
        }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                // Grey, not the accent: blue means rain. Dotted past where the forecast stops.
                GeometryReader { proxy in
                    let known = proxy.size.width * min(1, forecast.position(of: forecast.forecastEnd))
                    Rectangle().fill(Color.white.opacity(0.35)).frame(width: known, height: 1)
                    if known < proxy.size.width - 8 {
                        Path { path in
                            path.move(to: CGPoint(x: known + 3, y: 0.5))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
                        }
                        .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 4]))
                    }
                }
                .frame(height: 1)
            }
        }
        .accessibilityLabel(RainCopy(forecast).spoken)
    }

    /// The Light and Heavy lines (25 and 75 on Buienradar's graph scale) on the square-root height.
    static let scaleLines = [RainCurve.display(25) * 100, RainCurve.display(75) * 100]

    private func date(_ t: Double) -> Date {
        forecast.start.addingTimeInterval(t * forecast.span)
    }

    /// Hours far enough from "Now" not to read as one label with it.
    private var labelledHours: [Date] {
        forecast.hourMarks.filter { $0.timeIntervalSince(forecast.start) >= 25 * 60 }
    }
}
