import Foundation

/// Turns a `DayScore` into plain English. Pure and template-based so it's predictable and testable.
enum Explanation {
    /// "82. Great sleep and movement, protein was a little low, and the late coffee cost you a few points."
    static func summary(for score: DayScore) -> String {
        var praise: [String] = []
        var notes: [String] = []

        if score.sleep.hasData {
            if score.sleep.ratio >= 0.85 {
                praise.append("sleep")
            } else if score.gaps.contains(where: { $0.gap == .sleepDuration && $0.points >= 5 }) {
                notes.append("sleep came up short")
            } else if score.gaps.contains(where: { $0.gap == .bedtimeDrift && $0.points >= 4 }) {
                notes.append("bedtime drifted from your usual")
            }
        }

        if score.movement.hasData {
            if score.movement.ratio >= 0.85 {
                praise.append(score.dayType == .light ? "an easy recovery day" : "movement")
            } else if score.dayType == .light {
                notes.append("even a light day needs a short walk")
            } else if score.gaps.contains(where: { $0.gap == .workout && $0.points >= 10 }) {
                notes.append("there was no real workout")
            } else {
                notes.append("movement was on the light side")
            }
        }

        for (gap, _) in score.gaps {
            switch gap {
            case .missedHabit(let kind): notes.append(kind.missedPhrase)
            case .penalty(let kind): notes.append(kind.penaltyPhrase)
            default: break
            }
        }

        var clauses: [String] = []
        if !praise.isEmpty {
            clauses.append("Great " + joined(praise))
        }
        clauses.append(contentsOf: notes.prefix(3))

        guard !clauses.isEmpty else { return "\(score.total). A quiet day. Log a check-in or two to build your score." }
        if notes.isEmpty { return "\(score.total). Great \(joined(praise)), nothing to fix today." }

        var sentence = joined(clauses)
        sentence = sentence.prefix(1).uppercased() + sentence.dropFirst()
        return "\(score.total). \(sentence)."
    }

    /// One tip for tomorrow, aimed at the biggest fixable gap.
    static func tip(for score: DayScore, sleepTarget: String = "your usual bedtime") -> String {
        guard let biggest = score.gaps.first else {
            return "Keep the same rhythm tomorrow. Consistency is what moves your weekly trend."
        }
        switch biggest.gap {
        case .sleepDuration: return "Aim to be in bed 30 minutes earlier tonight to get closer to 7+ hours."
        case .bedtimeDrift: return "Try to be in bed by \(sleepTarget) tonight; a steady bedtime is worth up to 15 points."
        case .steps: return score.dayType == .light
            ? "A 20-minute walk counts as a full movement score on a light day."
            : "Take a 15-minute walk after lunch tomorrow to close your step gap."
        case .workout: return "Schedule a 30-minute session tomorrow; it's the biggest movement win available."
        case .missedHabit(let kind), .penalty(let kind): return kind.tip
        }
    }

    /// Morning note about last night: "7h 40m, bedtime was consistent, nice start."
    static func morningNote(for score: DayScore) -> String {
        guard score.sleep.hasData else { return "No sleep data from last night yet. Your score will use movement and habits." }
        let drift = score.gaps.first(where: { $0.gap == .bedtimeDrift })?.points ?? 0
        let short = score.gaps.first(where: { $0.gap == .sleepDuration })?.points ?? 0
        var parts = [score.sleep.detail]
        parts.append(drift < 4 ? "bedtime was consistent" : "bedtime was later than usual")
        if short >= 5 {
            parts.append("go easy on yourself today")
        } else {
            parts.append(drift < 4 ? "nice start" : "solid rest though")
        }
        return parts.joined(separator: ", ") + "."
    }

    /// Joins with commas and a final "and": ["a", "b", "c"] -> "a, b, and c".
    static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }
}
