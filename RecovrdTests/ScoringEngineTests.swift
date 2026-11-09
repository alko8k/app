import XCTest
@testable import Recovrd

final class ScoringEngineTests: XCTestCase {
    private let profile = ScoringProfile()
    private let today = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(sleep: Double? = 8, bedtime: Double? = 660, steps: Int? = 9000, workout: Double = 30,
                     energy: Double? = nil, checkIns: Set<CheckInKind> = [.water, .protein, .stretch]) -> DayInputs {
        DayInputs(date: today, sleepHours: sleep, bedtimeMinutes: bedtime, steps: steps,
                  workoutMinutes: workout, activeEnergy: energy, checkIns: checkIns)
    }

    private func history(_ count: Int, workout: Double = 20) -> [DayInputs] {
        (0..<count).map { _ in day(steps: 8000, workout: workout) }
    }

    func testPerfectDayScores100() {
        let score = ScoringEngine.score(day: day(), history: history(5), profile: profile)
        XCTAssertEqual(score.total, 100)
        XCTAssertTrue(score.gaps.isEmpty)
    }

    func testScoreNeverExceeds100() {
        let score = ScoringEngine.score(day: day(steps: 40000, workout: 180), history: history(5), profile: profile)
        XCTAssertLessThanOrEqual(score.total, 100)
    }

    func testLightDayRewardsRestAfterHardWorkout() {
        var past = history(5)
        past.append(day(workout: 75))
        let rest = ScoringEngine.score(day: day(steps: 6000, workout: 0), history: past, profile: profile)
        XCTAssertEqual(rest.dayType, .light)
        XCTAssertEqual(rest.movement.points, ScoringEngine.movementMax)

        // Same rest day without the hard day before it loses the workout points.
        let normal = ScoringEngine.score(day: day(steps: 6000, workout: 0), history: history(5), profile: profile)
        XCTAssertEqual(normal.dayType, .normal)
        XCTAssertLessThan(normal.total, rest.total)
    }

    func testHighActiveEnergyMarksHardDay() {
        var past = (0..<5).map { _ in day(workout: 0, energy: 400) }
        past.append(day(workout: 20, energy: 900))
        XCTAssertEqual(DayContext.dayType(history: past), .light)
    }

    func testLateCoffeeCostsFivePoints() {
        let clean = ScoringEngine.score(day: day(), history: history(5), profile: profile)
        let coffee = ScoringEngine.score(day: day(checkIns: [.water, .protein, .stretch, .lateCoffee]), history: history(5), profile: profile)
        XCTAssertEqual(clean.total - coffee.total, 5)
        XCTAssertEqual(coffee.gaps.first?.gap, .penalty(.lateCoffee))
    }

    func testHabitsNeverGoNegative() {
        let p = ScoringProfile(enabledCheckIns: [.water, .lateCoffee, .alcohol])
        let score = ScoringEngine.score(day: day(checkIns: [.lateCoffee, .alcohol]), history: history(5), profile: p)
        XCTAssertEqual(score.habits.points, 0)
    }

    func testMissingSleepIsRescaledNotZeroed() {
        let score = ScoringEngine.score(day: day(sleep: nil, bedtime: nil), history: history(5), profile: profile)
        XCTAssertFalse(score.sleep.hasData)
        XCTAssertEqual(score.total, 100)
    }

    func testNoHealthDataUsesHabitsOnly() {
        let score = ScoringEngine.score(day: day(sleep: nil, bedtime: nil, steps: nil, workout: 0, checkIns: [.water]),
                                        history: [], profile: profile)
        XCTAssertEqual(score.total, 33) // 1 of 3 positive habits
    }

    func testEmptyDayScoresZeroWithFullPotential() {
        let score = ScoringEngine.score(day: day(sleep: nil, bedtime: nil, steps: 0, workout: 0, checkIns: []),
                                        history: [], profile: profile)
        XCTAssertEqual(score.total, 0)
        XCTAssertEqual(score.potential, 100)
    }

    func testSleepDurationCurve() {
        XCTAssertEqual(ScoringEngine.sleepDurationPoints(hours: 3), 0)
        XCTAssertEqual(ScoringEngine.sleepDurationPoints(hours: 5.5), 12.5, accuracy: 0.01)
        XCTAssertEqual(ScoringEngine.sleepDurationPoints(hours: 8), 25)
        XCTAssertLessThan(ScoringEngine.sleepDurationPoints(hours: 11), 25)
    }

    func testBedtimeDriftLosesConsistency() {
        let late = ScoringEngine.score(day: day(bedtime: 660 + 120), history: history(5), profile: profile)
        XCTAssertEqual(late.sleep.points, 25)
        XCTAssertEqual(late.gaps.first?.gap, .bedtimeDrift)
    }

    func testBedtimeMinutesWrapsMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let elevenPM = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23))!
        let oneAM = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1))!
        XCTAssertEqual(DayContext.bedtimeMinutes(from: elevenPM, calendar: cal), 660)
        XCTAssertEqual(DayContext.bedtimeMinutes(from: oneAM, calendar: cal), 780)
    }

    func testStepGoalAdaptsAfterThreeDays() {
        let past = (0..<3).map { _ in day(steps: 11000) }
        XCTAssertEqual(ScoringEngine.adaptiveStepGoal(history: past, base: 8000), 11500)
        XCTAssertEqual(ScoringEngine.adaptiveStepGoal(history: Array(past.prefix(2)), base: 8000), 8000)
    }
}

final class SleepMergeTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private func interval(_ startHour: Double, _ endHour: Double) -> DateInterval {
        DateInterval(start: base.addingTimeInterval(startHour * 3600), end: base.addingTimeInterval(endHour * 3600))
    }

    func testOverlappingSourcesAreNotDoubleCounted() {
        // Watch 23:00–07:00 plus a sleep app 23:10–06:50.
        let watch = interval(0, 8)
        let app = interval(10.0 / 60, 7 + 50.0 / 60)
        XCTAssertEqual(DayContext.mergedDuration([watch, app]) / 3600, 8, accuracy: 0.001)
    }

    func testGapsBetweenStagesAreKept() {
        // Core, then awake 15 min, then REM.
        let samples = [interval(3, 5), interval(0, 3), interval(5.25, 7)]
        XCTAssertEqual(DayContext.mergedDuration(samples) / 3600, 6.75, accuracy: 0.001)
    }

    func testEmpty() {
        XCTAssertEqual(DayContext.mergedDuration([]), 0)
    }
}
