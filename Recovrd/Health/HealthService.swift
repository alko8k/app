import Foundation
import HealthKit

/// HealthKit numbers for one calendar day. Sleep is the night that ended that morning.
struct HealthDay: Equatable {
    var sleepHours: Double?
    var bedtime: Date?
    var steps: Int?
    var workoutMinutes: Double = 0
    var activeEnergy: Double?

    var isEmpty: Bool { sleepHours == nil && steps == nil && workoutMinutes == 0 }
}

@MainActor
@Observable
final class HealthService {
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []

    let isAvailable = HKHealthStore.isHealthDataAvailable()
    /// HealthKit never reveals read permission, so this only means "the prompt was shown".
    private(set) var hasRequested = UserDefaults.standard.bool(forKey: "health.requested")

    private static let sleepType = HKCategoryType(.sleepAnalysis)
    private static let stepType = HKQuantityType(.stepCount)
    private static let energyType = HKQuantityType(.activeEnergyBurned)

    private static var readTypes: Set<HKObjectType> {
        [sleepType, stepType, energyType, HKObjectType.workoutType()]
    }

    private static let asleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
    ]

    func requestAuthorization() async {
        guard isAvailable else { return }
        var share: Set<HKSampleType> = []
        #if DEBUG
        share = [Self.sleepType, Self.stepType, Self.energyType, HKObjectType.workoutType()]
        #endif
        do {
            try await store.requestAuthorization(toShare: share, read: Self.readTypes)
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
        hasRequested = true
        UserDefaults.standard.set(true, forKey: "health.requested")
    }

    func fetchDay(_ date: Date) async -> HealthDay {
        guard isAvailable, hasRequested else { return HealthDay() }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        async let sleep = fetchSleep(morningOf: start)
        async let steps = sum(Self.stepType, unit: .count(), from: start, to: end)
        async let energy = sum(Self.energyType, unit: .kilocalorie(), from: start, to: end)
        async let workouts = workoutMinutes(from: start, to: end)

        let night = await sleep
        return HealthDay(
            sleepHours: night?.hours,
            bedtime: night?.bedtime,
            steps: await steps.map { Int($0) },
            workoutMinutes: await workouts,
            activeEnergy: await energy
        )
    }

    /// Re-runs `onChange` whenever new steps, workouts or sleep land in HealthKit.
    func startObserving(onChange: @escaping @MainActor () -> Void) {
        guard isAvailable, hasRequested, observers.isEmpty else { return }
        for type in [Self.stepType, HKObjectType.workoutType(), Self.sleepType] as [HKSampleType] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                Task { @MainActor in onChange() }
                completion()
            }
            store.execute(query)
            observers.append(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    // MARK: - Queries

    /// Window runs 6pm the evening before to noon, like Life Blocks.
    private func fetchSleep(morningOf start: Date) async -> (hours: Double, bedtime: Date)? {
        let windowStart = start.addingTimeInterval(-6 * 3600)
        let windowEnd = start.addingTimeInterval(12 * 3600)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: Self.sleepType,
                                         predicate: HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return nil }
        let asleep = samples.filter { Self.asleepValues.contains($0.value) }
        guard let first = asleep.first else { return nil }
        let seconds = DayContext.mergedDuration(asleep.map { DateInterval(start: $0.startDate, end: $0.endDate) })
        return (seconds / 3600, first.startDate)
    }

    private func sum(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum
        )
        let value = try? await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
        return value
    }

    private func workoutMinutes(from start: Date, to end: Date) async -> Double {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: []
        )
        let workouts = (try? await descriptor.result(for: store)) ?? []
        return workouts.reduce(0) { $0 + $1.duration / 60 }
    }

    // MARK: - Debug seeding

    #if DEBUG
    /// Writes 14 days of believable data so the simulator has something to score.
    func seedSampleData() async {
        guard isAvailable else { return }
        let calendar = Calendar.current
        var samples: [HKSample] = []
        let today = calendar.startOfDay(for: .now)

        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let isHardDay = offset % 4 == 1

            // Night ending this morning: bedtime around 23:00 with some drift.
            let bedtime = day.addingTimeInterval(-3600 + Double((offset * 17) % 70 - 35) * 60)
            let sleepLength = (7.0 + Double(offset % 3) * 0.4 - (offset == 3 ? 1.6 : 0)) * 3600
            samples.append(HKCategorySample(type: Self.sleepType, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                            start: bedtime, end: bedtime.addingTimeInterval(sleepLength)))

            guard offset > 0 else { continue } // today's movement comes in "live"
            let steps = Double(6500 + (offset * 1337) % 5000)
            samples.append(HKQuantitySample(type: Self.stepType, quantity: HKQuantity(unit: .count(), doubleValue: steps),
                                            start: day.addingTimeInterval(9 * 3600), end: day.addingTimeInterval(19 * 3600)))
            samples.append(HKQuantitySample(type: Self.energyType,
                                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: isHardDay ? 850 : 420),
                                            start: day.addingTimeInterval(9 * 3600), end: day.addingTimeInterval(19 * 3600)))
            if isHardDay || offset % 4 == 3 {
                let start = day.addingTimeInterval(18 * 3600)
                let minutes = isHardDay ? 60.0 : 30.0
                let config = HKWorkoutConfiguration()
                config.activityType = isHardDay ? .traditionalStrengthTraining : .running
                let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
                try? await builder.beginCollection(at: start)
                try? await builder.endCollection(at: start.addingTimeInterval(minutes * 60))
                _ = try? await builder.finishWorkout()
            }
        }
        // A few of today's steps so the live score has something.
        samples.append(HKQuantitySample(type: Self.stepType, quantity: HKQuantity(unit: .count(), doubleValue: 3200),
                                        start: today.addingTimeInterval(8 * 3600), end: max(today.addingTimeInterval(8 * 3600 + 60), .now)))
        do {
            try await store.save(samples)
        } catch {
            print("Seeding failed: \(error)")
        }
    }
    #endif
}
