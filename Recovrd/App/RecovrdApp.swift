import SwiftUI
import SwiftData

@main
struct RecovrdApp: App {
    private let container: ModelContainer
    @State private var health: HealthService
    @State private var dayStore: DayStore
    @State private var subscriptions: SubscriptionManager

    init() {
        // SDKs must be configured before SubscriptionManager subscribes to updates.
        SubscriptionManager.configure()
        Analytics.configure()
        _subscriptions = State(initialValue: SubscriptionManager())
        let container = Self.makeContainer()
        let health = HealthService()
        self.container = container
        _health = State(initialValue: health)
        _dayStore = State(initialValue: DayStore(health: health, context: container.mainContext))
        #if DEBUG
        Self.applyDebugArguments(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(health)
                .environment(dayStore)
                .environment(subscriptions)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }

    /// If the on-disk store can't open (e.g. a failed migration), run in memory instead of
    /// crashing at launch. The store file is left untouched so a fixed build can still read it.
    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: UserProfile.self, DayRecord.self)
        } catch {
            print("SwiftData store failed to open, falling back to memory: \(error)")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: UserProfile.self, DayRecord.self, configurations: config)
        }
    }

    #if DEBUG
    private static func applyDebugArguments(_ context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetOnboarding") {
            try? context.delete(model: UserProfile.self)
            try? context.delete(model: DayRecord.self)
            try? context.save()
        }
        if args.contains("-fakeRecords") { insertFakeRecords(context) }
    }

    /// Two weeks of DayRecords without touching HealthKit, for screenshots and trend checks.
    private static func insertFakeRecords(_ context: ModelContext) {
        try? context.delete(model: DayRecord.self)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 0..<21 {
            let record = DayRecord(day: calendar.date(byAdding: .day, value: -offset, to: today)!)
            let lateCoffee = offset % 5 == 2
            record.sleepHours = 6.6 + Double(offset % 3) * 0.5 - (offset % 5 == 1 ? 1.2 : 0) + (offset < 7 ? 0.4 : 0)
            record.bedtimeMinutes = 660 + Double((offset * 23) % 50) - (offset % 5 == 1 ? -70 : 0)
            record.steps = offset == 0 ? 6400 : 6000 + (offset * 1337) % 5500
            record.workoutMinutes = offset == 0 ? 0 : (offset % 4 == 1 ? 60 : (offset % 4 == 3 ? 30 : 0))
            record.activeEnergy = offset % 4 == 1 ? 850 : 420
            var checks: Set<CheckInKind> = offset == 0 ? [.water, .stretch, .lateCoffee] : [.water]
            if offset > 0, offset % 2 == 0 { checks.insert(.protein) }
            if offset > 0, offset % 3 != 0 { checks.insert(.stretch) }
            if lateCoffee { checks.insert(.lateCoffee) }
            record.checkIns = checks
            context.insert(record)
        }
        try? context.save()
    }
    #endif
}
