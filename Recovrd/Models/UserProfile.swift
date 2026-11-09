import Foundation
import SwiftData

enum RecoveryGoal: String, CaseIterable, Codable, Identifiable {
    case sleepBetter, moreEnergy, trainingRecovery, consistency
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleepBetter: "Sleep better"
        case .moreEnergy: "Have more energy"
        case .trainingRecovery: "Recover from training"
        case .consistency: "Build consistency"
        }
    }

    var symbol: String {
        switch self {
        case .sleepBetter: "moon.zzz.fill"
        case .moreEnergy: "bolt.fill"
        case .trainingRecovery: "figure.strengthtraining.traditional"
        case .consistency: "calendar"
        }
    }

    /// Paywall headline tuned to what the user said they want.
    var paywallHeadline: String {
        switch self {
        case .sleepBetter: "Wake up to better nights."
        case .moreEnergy: "Turn your days into energy."
        case .trainingRecovery: "Train hard. Recover smarter."
        case .consistency: "Make good days the default."
        }
    }
}

enum CaffeineHabit: String, CaseIterable, Codable, Identifiable {
    case rarely, sometimes, often
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rarely: "Rarely"
        case .sometimes: "A few times a week"
        case .often: "Most days"
        }
    }
}

@Model
final class UserProfile {
    var goalsRaw: [String] = []
    /// Minutes after midnight.
    var bedtimeMinutes: Int = 23 * 60
    var wakeMinutes: Int = 7 * 60
    var trainingDaysPerWeek: Int = 3
    var caffeineRaw: String = CaffeineHabit.sometimes.rawValue
    var checkInsRaw: [String] = CheckInKind.defaultSelection.map(\.rawValue)
    var notificationsEnabled: Bool = false
    var morningMinutes: Int = 7 * 60 + 30
    var eveningMinutes: Int = 21 * 60
    var onboardingComplete: Bool = false
    var createdAt: Date = Date.now

    init() {}

    var goals: [RecoveryGoal] {
        get { goalsRaw.compactMap(RecoveryGoal.init(rawValue:)) }
        set { goalsRaw = newValue.map(\.rawValue) }
    }

    var checkIns: [CheckInKind] {
        get { checkInsRaw.compactMap(CheckInKind.init(rawValue:)) }
        set { checkInsRaw = newValue.map(\.rawValue) }
    }

    var caffeine: CaffeineHabit {
        get { CaffeineHabit(rawValue: caffeineRaw) ?? .sometimes }
        set { caffeineRaw = newValue.rawValue }
    }

    var scoringProfile: ScoringProfile {
        ScoringProfile(enabledCheckIns: checkIns)
    }

    var bedtimeLabel: String { Self.timeLabel(bedtimeMinutes) }

    static func timeLabel(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
