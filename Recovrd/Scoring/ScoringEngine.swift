import Foundation

enum Pillar: String, CaseIterable, Identifiable {
    case sleep, movement, habits
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .movement: "Movement"
        case .habits: "Habits"
        }
    }

    var symbol: String {
        switch self {
        case .sleep: "moon.stars.fill"
        case .movement: "figure.walk"
        case .habits: "checkmark.seal.fill"
        }
    }

    var maxPoints: Double {
        switch self {
        case .sleep: ScoringEngine.sleepMax
        case .movement: ScoringEngine.movementMax
        case .habits: ScoringEngine.habitsMax
        }
    }
}

/// One way the day lost points, used to pick the explanation and tomorrow's tip.
enum ScoreGap: Equatable {
    case sleepDuration
    case bedtimeDrift
    case steps
    case workout
    case missedHabit(CheckInKind)
    case penalty(CheckInKind)
}

struct PillarScore: Equatable {
    var pillar: Pillar
    var points: Double
    /// `false` when HealthKit had nothing for this pillar; it is left out of the total.
    var hasData: Bool
    var detail: String

    var ratio: Double { points / pillar.maxPoints }
}

struct DayScore: Equatable {
    var total: Int
    var dayType: DayType
    var sleep: PillarScore
    var movement: PillarScore
    var habits: PillarScore
    /// Points lost per gap, largest first.
    var gaps: [(gap: ScoreGap, points: Double)]
    /// Best total still reachable today if the user moves and checks in.
    var potential: Int

    var pillars: [PillarScore] { [sleep, movement, habits] }

    static func == (lhs: DayScore, rhs: DayScore) -> Bool {
        lhs.total == rhs.total && lhs.dayType == rhs.dayType && lhs.pillars == rhs.pillars
            && lhs.potential == rhs.potential && lhs.gaps.map(\.gap) == rhs.gaps.map(\.gap)
    }
}

struct ScoringProfile: Equatable {
    var enabledCheckIns: [CheckInKind] = CheckInKind.defaultSelection
    var baseStepGoal: Int = 8000
}

enum ScoringEngine {
    static let sleepMax = 40.0
    static let sleepDurationMax = 25.0
    static let sleepConsistencyMax = 15.0
    static let movementMax = 35.0
    static let stepsMax = 20.0
    static let workoutMax = 15.0
    static let habitsMax = 25.0
    static let penaltyPoints = 5.0
    static let fullWorkoutMinutes = 30.0
    static let lightDaySteps = 5000...9000

    /// `history` holds previous days, oldest first, ending with yesterday.
    static func score(day: DayInputs, history: [DayInputs], profile: ScoringProfile) -> DayScore {
        let dayType = DayContext.dayType(history: history)
        var gaps: [(ScoreGap, Double)] = []

        // Sleep
        var sleepPoints = 0.0
        var sleepDetail = "No sleep data"
        if let hours = day.sleepHours {
            let duration = sleepDurationPoints(hours: hours)
            gaps.append((.sleepDuration, sleepDurationMax - duration))
            var consistency = sleepConsistencyMax
            if let bedtime = day.bedtimeMinutes,
               let median = DayContext.median(history.suffix(7).compactMap(\.bedtimeMinutes)) {
                consistency = consistencyPoints(offsetMinutes: abs(bedtime - median))
            }
            gaps.append((.bedtimeDrift, sleepConsistencyMax - consistency))
            sleepPoints = duration + consistency
            sleepDetail = formatHours(hours)
        }
        let sleep = PillarScore(pillar: .sleep, points: sleepPoints, hasData: day.sleepHours != nil, detail: sleepDetail)

        // Movement
        let stepGoal = adaptiveStepGoal(history: history, base: profile.baseStepGoal)
        let steps = Double(day.steps ?? 0)
        let movementPoints: Double
        switch dayType {
        case .light:
            if day.workoutMinutes > 0 || steps >= Double(lightDaySteps.lowerBound) {
                movementPoints = movementMax
            } else {
                movementPoints = movementMax * steps / Double(lightDaySteps.lowerBound)
            }
            gaps.append((.steps, movementMax - movementPoints))
        case .normal:
            let stepPoints = stepsMax * min(1, steps / Double(stepGoal))
            let workoutPoints = workoutMax * min(1, day.workoutMinutes / fullWorkoutMinutes)
            gaps.append((.steps, stepsMax - stepPoints))
            gaps.append((.workout, workoutMax - workoutPoints))
            movementPoints = stepPoints + workoutPoints
        }
        let movementDetail = day.steps.map { "\($0.formatted()) steps" } ?? (day.workoutMinutes > 0 ? "\(Int(day.workoutMinutes)) min workout" : "No movement data")
        let movement = PillarScore(pillar: .movement, points: movementPoints, hasData: day.hasMovementData, detail: movementDetail)

        // Habits
        let positives = profile.enabledCheckIns.filter { !$0.isNegative }
        let negatives = profile.enabledCheckIns.filter(\.isNegative)
        var habitPoints: Double
        if positives.isEmpty {
            habitPoints = habitsMax
        } else {
            let each = habitsMax / Double(positives.count)
            habitPoints = 0
            for habit in positives {
                if day.checkIns.contains(habit) {
                    habitPoints += each
                } else {
                    gaps.append((.missedHabit(habit), each))
                }
            }
        }
        var penalties = 0.0
        for habit in negatives where day.checkIns.contains(habit) {
            penalties += penaltyPoints
            habitPoints -= penaltyPoints
            gaps.append((.penalty(habit), penaltyPoints))
        }
        habitPoints = max(0, habitPoints)
        let done = positives.filter { day.checkIns.contains($0) }.count
        let habits = PillarScore(pillar: .habits, points: habitPoints, hasData: true,
                                 detail: positives.isEmpty ? "No habits tracked" : "\(done) of \(positives.count) done")

        let pillars = [sleep, movement, habits]
        let total = scaledTotal(pillars)
        let potentialPillars = [
            sleep,
            PillarScore(pillar: .movement, points: movementMax, hasData: movement.hasData, detail: ""),
            PillarScore(pillar: .habits, points: max(0, habitsMax - penalties), hasData: true, detail: ""),
        ]

        return DayScore(
            total: total,
            dayType: dayType,
            sleep: sleep,
            movement: movement,
            habits: habits,
            gaps: gaps.filter { $0.1 > 0.5 }.sorted { $0.1 > $1.1 },
            potential: max(total, scaledTotal(potentialPillars))
        )
    }

    /// Pillars with no data are dropped and the rest rescaled to 100,
    /// so a manual-mode user isn't capped at 25.
    static func scaledTotal(_ pillars: [PillarScore]) -> Int {
        let counted = pillars.filter(\.hasData)
        let maxPoints = counted.reduce(0) { $0 + $1.pillar.maxPoints }
        guard maxPoints > 0 else { return 0 }
        let earned = counted.reduce(0) { $0 + $1.points }
        return min(100, max(0, Int((earned / maxPoints * 100).rounded())))
    }

    static func sleepDurationPoints(hours: Double) -> Double {
        switch hours {
        case ..<4: 0
        case 4..<7: sleepDurationMax * (hours - 4) / 3
        case 7...9: sleepDurationMax
        case 9..<10: sleepDurationMax
        default: max(sleepDurationMax - 5, sleepDurationMax - (hours - 10) * 5)
        }
    }

    static func consistencyPoints(offsetMinutes: Double) -> Double {
        if offsetMinutes <= 30 { return sleepConsistencyMax }
        if offsetMinutes >= 120 { return 0 }
        return sleepConsistencyMax * (120 - offsetMinutes) / 90
    }

    /// After 3 days of step data the goal follows the user's own average, within sane bounds.
    static func adaptiveStepGoal(history: [DayInputs], base: Int) -> Int {
        let recent = history.suffix(7).compactMap(\.steps)
        guard recent.count >= 3 else { return base }
        let average = Double(recent.reduce(0, +)) / Double(recent.count)
        let rounded = Int((average * 1.05 / 500).rounded()) * 500
        return min(12000, max(5000, rounded))
    }

    static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }
}
