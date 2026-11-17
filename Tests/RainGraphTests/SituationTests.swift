import Foundation
import Testing
@testable import RainGraph

/// What the wearer sees when things go wrong, by the paths that lead there. Each test is a rule in
/// STATES.md.
struct SituationTests {
    /// A KNMI run at `run`: dry for forty minutes after its data starts, then light rain.
    static func knmi(run: Date, latitude: Double = 51.92, longitude: Double = 4.48) -> Snapshot {
        let samples = (0..<23).map { step in
            RainSample(date: run.addingTimeInterval(600 + Double(step) * 300), rate: step < 8 ? 0 : 0.4)
        }
        return Snapshot(samples: samples, source: .knmi, issued: run, fetched: run.addingTimeInterval(600),
                        latitude: latitude, longitude: longitude)
    }

    static let run = Date(timeIntervalSince1970: 1_800_000_000)

    /// Opened at 10 minutes, then again at 25 with no connection: the saved forecast stays, and its
    /// countdown is the one for now, not the one from the first look.
    @Test func aFailedUpdateCountsDownFromNow() throws {
        let saved = Self.knmi(run: Self.run)
        let now = Self.run.addingTimeInterval(25 * 60)
        guard case let .forecast(forecast, _, updateFailed) = Situation.after(.unreachable, latitude: 51.92, longitude: 4.48, saved: saved, now: now) else {
            Issue.record("The saved forecast should stay")
            return
        }
        #expect(updateFailed)
        #expect(forecast.now == now)
        #expect(RainCopy(forecast).headline == "Dry for 25 min")
    }

    /// No connection for over an hour: no countdown from a forecast that old, only its time.
    @Test func anHourOldForecastIsNotCountedDownFrom() {
        let saved = Self.knmi(run: Self.run)
        let situation = Situation.after(.unreachable, latitude: 51.92, longitude: 4.48, saved: saved, now: Self.run.addingTimeInterval(61 * 60))
        guard case .problem(.forecastTooOld(since: Self.run)) = situation else {
            Issue.record("Expected the forecast to be too old, got \(situation)")
            return
        }
    }

    /// Travelled 30 km and the fetch fails: never the forecast for the place left behind.
    @Test func aSavedForecastForAnotherPlaceIsNotShown() {
        let saved = Self.knmi(run: Self.run)
        let situation = Situation.after(.unreachable, latitude: 52.09, longitude: 5.12, saved: saved, now: Self.run.addingTimeInterval(15 * 60))
        guard case .problem(.forecastUnavailable) = situation else {
            Issue.record("Expected no forecast, got \(situation)")
            return
        }
    }

    /// A walk round the block is the same place: the saved forecast still stands in.
    @Test func aSavedForecastForNearbyStillStandsIn() {
        let saved = Self.knmi(run: Self.run)
        let situation = Situation.after(.unreachable, latitude: 51.928, longitude: 4.48, saved: saved, now: Self.run.addingTimeInterval(15 * 60))
        guard case .forecast = situation else {
            Issue.record("Expected the saved forecast, got \(situation)")
            return
        }
    }

    /// Apple has no forecast for the place: said so, never shown as dry.
    @Test func noForecastIsNotDry() {
        guard case .problem(.noForecastHere) = Situation.after(.refused, latitude: 40.42, longitude: -3.7, saved: nil, now: Self.run) else {
            Issue.record("Expected no forecast here")
            return
        }
    }

    /// The face after Allow Once: it keeps the place for an hour from the fix, then has no place,
    /// even though the forecast itself would have lasted longer.
    @Test func theFaceGivesUpAPlaceAnHourAfterItsFix() throws {
        let fix = Self.run.addingTimeInterval(-30 * 60)
        let now = Self.run.addingTimeInterval(10 * 60)
        let schedule = Situation.schedule(Self.knmi(run: Self.run), now: now, placeExpires: fix.addingTimeInterval(3600))
        let last = try #require(schedule.last)
        #expect(last.date == fix.addingTimeInterval(3600))
        guard case .problem(.locationNotFound) = last.situation else {
            Issue.record("Expected no place, got \(last.situation)")
            return
        }
        #expect(schedule.dropLast().allSatisfy { $0.date < last.date })
    }

    /// The face with a picked place: a forecast every minute until it is an hour old, then its time.
    @Test func theFaceWithdrawsTheCountdownAtAnHour() throws {
        let now = Self.run.addingTimeInterval(10 * 60)
        let schedule = Situation.schedule(Self.knmi(run: Self.run), now: now, placeExpires: nil)
        let last = try #require(schedule.last)
        #expect(last.date == Self.run.addingTimeInterval(3600))
        guard case .problem(.forecastTooOld(since: Self.run)) = last.situation else {
            Issue.record("Expected the forecast to be too old, got \(last.situation)")
            return
        }
        #expect(schedule.count == 51)
    }

    /// The face's first line is the app's title, so the two name a problem alike.
    @Test func theFaceAndTheAppNameAProblemAlike() {
        #expect(Problem.locationNotFound.faceHeadline == "Location not found")
        #expect(Problem.forecastTooOld(since: Self.run).faceHeadline == "No recent forecast")
        #expect(Problem.locationOff.faceHint == "Tap to choose a place")
        #expect(Problem.forecastUnavailable.circleWord == "DATA")
        #expect(Problem.locationOff.circleWord == "PLACE")
    }
}
