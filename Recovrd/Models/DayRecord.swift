import Foundation
import SwiftData

/// One calendar day: HealthKit numbers cached locally plus the user's check-ins.
@Model
final class DayRecord {
    @Attribute(.unique) var day: Date
    var sleepHours: Double?
    var bedtimeMinutes: Double?
    var steps: Int?
    var workoutMinutes: Double = 0
    var activeEnergy: Double?
    var checkInsRaw: [String] = []
    /// Last computed score, cached for the trends view.
    var score: Int?

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
    }

    var checkIns: Set<CheckInKind> {
        get { Set(checkInsRaw.compactMap(CheckInKind.init(rawValue:))) }
        set { checkInsRaw = newValue.map(\.rawValue).sorted() }
    }

    var inputs: DayInputs {
        DayInputs(date: day, sleepHours: sleepHours, bedtimeMinutes: bedtimeMinutes, steps: steps,
                  workoutMinutes: workoutMinutes, activeEnergy: activeEnergy, checkIns: checkIns)
    }

    func apply(_ health: HealthDay) {
        sleepHours = health.sleepHours
        bedtimeMinutes = health.bedtime.map { DayContext.bedtimeMinutes(from: $0) }
        steps = health.steps
        workoutMinutes = health.workoutMinutes
        activeEnergy = health.activeEnergy
    }
}
