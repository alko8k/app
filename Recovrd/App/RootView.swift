import SwiftUI
import SwiftData

/// Routes between onboarding, the paywall gate and the main app.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(DayStore.self) private var dayStore
    @Query private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let profile = profiles.first {
                if !profile.onboardingComplete {
                    OnboardingFlow(profile: profile)
                        .transition(.opacity)
                } else if !subscriptions.isSubscribed {
                    if subscriptions.hasLoaded {
                        PaywallView(profile: profile)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        ProgressView().tint(Theme.accent)
                    }
                } else {
                    MainTabView(profile: profile)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: profiles.first?.onboardingComplete)
        .animation(.easeInOut(duration: 0.45), value: subscriptions.isSubscribed)
        .task {
            if profiles.isEmpty {
                context.insert(UserProfile())
                try? context.save()
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-onboardingDone") {
                profiles.first?.onboardingComplete = true
            }
            #endif
            await subscriptions.load()
        }
    }
}

struct MainTabView: View {
    let profile: UserProfile
    @Environment(DayStore.self) private var dayStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = Self.initialTab

    var body: some View {
        TabView(selection: $tab) {
            TodayView(profile: profile)
                .tabItem { Label("Today", systemImage: "circle.circle") }
                .tag(0)
            TrendsView(profile: profile)
                .tabItem { Label("Trends", systemImage: "chart.bar.fill") }
                .tag(1)
            SettingsView(profile: profile)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .task {
            await dayStore.sync(profile: profile)
            dayStore.health.startObserving {
                Task { await dayStore.sync(days: 2, profile: profile) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await dayStore.sync(days: 2, profile: profile) } }
        }
    }

    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), let n = Int(args[safe: i + 1] ?? "") { return n }
        #endif
        return 0
    }
}
