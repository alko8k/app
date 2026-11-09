import Foundation

/// Everything the engine needs to score one day. Missing HealthKit data is `nil`.
struct DayInputs: Equatable {
    var date: Date
    var sleepHours: Double?
    /// Bedtime as minutes after noon of the previous day (23:00 = 660, 01:00 = 780),
    /// so bedtimes either side of midnight compare cleanly.
    var bedtimeMinutes: Double?
    var steps: Int?
    var workoutMinutes: Double = 0
    var activeEnergy: Double?
    var checkIns: Set<CheckInKind> = []

    var hasMovementData: Bool { steps != nil || workoutMinutes > 0 }
}

enum DayType: String, Equatable {
    /// Yesterday was hard, so today rewards easy movement.
    case light
    case normal

    var suggestion: String {
        switch self {
        case .light: "You trained hard yesterday, so today is a lighter movement day."
        case .normal: "You're recovered. A good day to train or get your steps in."
        }
    }

    var label: String {
        switch self {
        case .light: "Light day"
        case .normal: "Training day"
        }
    }
}

enum DayContext {
    static let hardWorkoutMinutes: Double = 45
    static let hardEnergyMultiplier: Double = 1.5

    /// `history` is ordered oldest to newest and ends with yesterday.
    static func dayType(history: [DayInputs]) -> DayType {
        guard let yesterday = history.last else { return .normal }
        if yesterday.workoutMinutes >= hardWorkoutMinutes { return .light }

        if let energy = yesterday.activeEnergy {
            let prior = history.dropLast().suffix(7).compactMap(\.activeEnergy)
            if prior.count >= 3 {
                let average = prior.reduce(0, +) / Double(prior.count)
                if average > 0, energy >= average * hardEnergyMultiplier { return .light }
            }
        }
        return .normal
    }

    static func wasHardDay(_ day: DayInputs, history: [DayInputs]) -> Bool {
        dayType(history: history + [day]) == .light
    }

    static func bedtimeMinutes(from date: Date, calendar: Calendar = .current) -> Double {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        // Shift so noon = 0; times after midnight land past 720.
        return minutes >= 720 ? minutes - 720 : minutes + 720
    }

    /// Total time covered by possibly overlapping intervals. Watch + a second sleep app
    /// both write "asleep" samples for the same night; summing them would double count.
    static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let open = current, interval.start <= open.end {
                current = DateInterval(start: open.start, end: max(open.end, interval.end))
            } else {
                if let open = current { total += open.duration }
                current = interval
            }
        }
        return total + (current?.duration ?? 0)
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
