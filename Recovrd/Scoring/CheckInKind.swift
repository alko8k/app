import Foundation

/// A one-tap habit the user logs during the day.
enum CheckInKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case water
    case protein
    case stretch
    case lateCoffee
    case alcohol
    case screensOff

    var id: String { rawValue }

    /// Negative check-ins cost points instead of earning them.
    var isNegative: Bool {
        self == .lateCoffee || self == .alcohol
    }

    var title: String {
        switch self {
        case .water: "Water"
        case .protein: "Protein meal"
        case .stretch: "Stretch"
        case .lateCoffee: "Coffee after 4pm"
        case .alcohol: "Alcohol"
        case .screensOff: "Screens off early"
        }
    }

    var subtitle: String {
        switch self {
        case .water: "Hit your water for the day"
        case .protein: "Had a protein-heavy meal"
        case .stretch: "10 minutes of mobility"
        case .lateCoffee: "Caffeine late in the day"
        case .alcohol: "Any drinks today"
        case .screensOff: "No screens 30 min before bed"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .protein: "fork.knife"
        case .stretch: "figure.flexibility"
        case .lateCoffee: "cup.and.saucer.fill"
        case .alcohol: "wineglass.fill"
        case .screensOff: "iphone.slash"
        }
    }

    /// Phrase used in the evening explanation when a positive habit was missed.
    var missedPhrase: String {
        switch self {
        case .water: "water was a little low"
        case .protein: "protein was a little low"
        case .stretch: "you skipped stretching"
        case .screensOff: "screens stayed on late"
        case .lateCoffee, .alcohol: ""
        }
    }

    /// Phrase used when a negative habit was logged.
    var penaltyPhrase: String {
        switch self {
        case .lateCoffee: "the late coffee cost you a few points"
        case .alcohol: "the drinks cost you a few points"
        default: ""
        }
    }

    var tip: String {
        switch self {
        case .water: "Keep a bottle on your desk tomorrow and finish it by lunch."
        case .protein: "Build tomorrow's lunch around a palm-sized portion of protein."
        case .stretch: "Ten minutes of stretching before bed tomorrow is an easy win."
        case .screensOff: "Put your phone across the room 30 minutes before bed tomorrow."
        case .lateCoffee: "Have your last coffee before 2pm tomorrow and see how you sleep."
        case .alcohol: "Try an alcohol-free evening tomorrow; your sleep score will show it."
        }
    }

    static let defaultSelection: [CheckInKind] = [.water, .protein, .stretch, .lateCoffee]
}
