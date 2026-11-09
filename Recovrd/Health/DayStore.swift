import Foundation
import SwiftData

/// Glue between HealthKit, SwiftData and the scoring engine.
@MainActor
@Observable
final class DayStore {
    let health: HealthService
    private let context: ModelContext
    private let calendar = Calendar.current

    /// Bumped whenever records change so views re-read scores.
    private(set) var revision = 0
    private(set) var isSyncing = false

    init(health: HealthService, context: ModelContext) {
        self.health = health
        self.context = context
        // Re-render at midnight so an app left open doesn't keep showing yesterday.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.revision += 1 }
        }
    }

    /// Fetch-only; safe to call from view bodies.
    func existingRecord(for date: Date) -> DayRecord? {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.day == day })
        return try? context.fetch(descriptor).first
    }

    /// Fetches or creates. Call from actions and sync, never while rendering.
    func record(for date: Date) -> DayRecord {
        if let existing = existingRecord(for: date) { return existing }
        let record = DayRecord(day: calendar.startOfDay(for: date))
        context.insert(record)
        return record
    }

    func records(last days: Int, endingOn end: Date = .now) -> [DayRecord] {
        let endDay = calendar.startOfDay(for: end)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay)!
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.day >= startDay && $0.day <= endDay },
            sortBy: [SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// History for scoring `date`: up to 14 prior days, oldest first.
    func history(before date: Date) -> [DayInputs] {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        return records(last: 14, endingOn: yesterday).map(\.inputs)
    }

    /// Pass `cache: false` from view bodies so rendering never writes to the store.
    func score(for date: Date, profile: UserProfile, cache: Bool = true) -> DayScore {
        let history = history(before: date)
        guard cache else {
            let inputs = existingRecord(for: date)?.inputs ?? DayInputs(date: calendar.startOfDay(for: date))
            return ScoringEngine.score(day: inputs, history: history, profile: profile.scoringProfile)
        }
        let record = record(for: date)
        let result = ScoringEngine.score(day: record.inputs, history: history, profile: profile.scoringProfile)
        if record.score != result.total {
            record.score = result.total
            try? context.save()
        }
        return result
    }

    /// Pulls HealthKit for the last `days` days and rescores them oldest first.
    func sync(days: Int = 14, profile: UserProfile) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let today = calendar.startOfDay(for: .now)
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let healthDay = await health.fetchDay(date)
            let record = record(for: date)
            if !healthDay.isEmpty { record.apply(healthDay) }
        }
        try? context.save()
        for offset in stride(from: days - 1, through: 0, by: -1) {
            _ = score(for: calendar.date(byAdding: .day, value: -offset, to: today)!, profile: profile)
        }
        revision += 1
    }

    func toggle(_ kind: CheckInKind, on date: Date = .now, profile: UserProfile) {
        let record = record(for: date)
        var set = record.checkIns
        if set.contains(kind) { set.remove(kind) } else { set.insert(kind) }
        record.checkIns = set
        try? context.save()
        _ = score(for: date, profile: profile)
        revision += 1
    }
}
