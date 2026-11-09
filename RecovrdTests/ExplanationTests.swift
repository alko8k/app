import XCTest
@testable import Recovrd

final class ExplanationTests: XCTestCase {
    private func score(sleep: Double = 8, bedtime: Double = 660, steps: Int = 9000, workout: Double = 30,
                       checkIns: Set<CheckInKind>) -> DayScore {
        let history = (0..<5).map { _ in
            DayInputs(date: .now, sleepHours: 8, bedtimeMinutes: 660, steps: 8000, workoutMinutes: 20)
        }
        let day = DayInputs(date: .now, sleepHours: sleep, bedtimeMinutes: bedtime, steps: steps,
                            workoutMinutes: workout, checkIns: checkIns)
        return ScoringEngine.score(day: day, history: history, profile: ScoringProfile())
    }

    func testConceptExampleSentence() {
        let s = score(checkIns: [.water, .stretch, .lateCoffee])
        XCTAssertEqual(Explanation.summary(for: s),
                       "\(s.total). Great sleep and movement, protein was a little low, and the late coffee cost you a few points.")
    }

    func testPerfectDay() {
        let s = score(checkIns: [.water, .protein, .stretch])
        XCTAssertEqual(Explanation.summary(for: s), "100. Great sleep and movement, nothing to fix today.")
        XCTAssertTrue(Explanation.tip(for: s).hasPrefix("Keep the same rhythm"))
    }

    func testTipTargetsBiggestGap() {
        let s = score(checkIns: [.water, .protein, .stretch, .lateCoffee])
        XCTAssertEqual(Explanation.tip(for: s), CheckInKind.lateCoffee.tip)

        let short = score(sleep: 5, checkIns: [.water, .protein, .stretch])
        XCTAssertTrue(Explanation.summary(for: short).contains("sleep came up short"))
        XCTAssertTrue(Explanation.tip(for: short).contains("30 minutes earlier"))
    }

    func testMorningNote() {
        let s = score(sleep: 7 + 40.0 / 60, checkIns: [])
        XCTAssertEqual(Explanation.morningNote(for: s), "7h 40m, bedtime was consistent, nice start.")
    }

    func testJoined() {
        XCTAssertEqual(Explanation.joined(["a"]), "a")
        XCTAssertEqual(Explanation.joined(["a", "b"]), "a and b")
        XCTAssertEqual(Explanation.joined(["a", "b", "c"]), "a, b, and c")
    }
}
