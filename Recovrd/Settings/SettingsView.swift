import SwiftUI
import StoreKit

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(DayStore.self) private var dayStore
    @Environment(\.modelContext) private var context
    @State private var showManage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Subscription") {
                    LabeledContent("Recovrd Premium", value: subscriptions.isSubscribed ? "Active" : "Inactive")
                    if let renews = subscriptions.expirationDate {
                        LabeledContent("Renews", value: renews.formatted(date: .abbreviated, time: .omitted))
                    }
                    Button("Manage subscription") { showManage = true }
                    Button("Restore purchases") { Task { await subscriptions.restore() } }
                }

                Section {
                    ForEach(CheckInKind.allCases) { kind in
                        Toggle(isOn: checkInBinding(kind)) {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        .disabled(isLocked(kind))
                    }
                } header: {
                    Text("Check-ins")
                } footer: {
                    Text("Up to 4, with at least one positive habit. Coffee after 4pm and alcohol cost 5 points when logged.")
                }

                Section("Rhythm") {
                    DatePicker("Target bedtime", selection: timeBinding(\.bedtimeMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("Wake up", selection: timeBinding(\.wakeMinutes), displayedComponents: .hourAndMinute)
                    Stepper("Training days: \(profile.trainingDaysPerWeek)", value: $profile.trainingDaysPerWeek, in: 0...7)
                }

                Section("Reminders") {
                    Toggle("Morning & evening reminders", isOn: $profile.notificationsEnabled)
                    if profile.notificationsEnabled {
                        DatePicker("Morning note", selection: timeBinding(\.morningMinutes), displayedComponents: .hourAndMinute)
                        DatePicker("Evening score", selection: timeBinding(\.eveningMinutes), displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button("Connect Apple Health") {
                        Task {
                            await dayStore.health.requestAuthorization()
                            await dayStore.sync(profile: profile)
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("To change what Recovrd can read, open the Health app → Sharing → Apps → Recovrd.")
                }

                Section("About") {
                    Link("Privacy Policy", destination: LegalLinks.privacy)
                    Link("Terms of Use", destination: LegalLinks.terms)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Seed sample Health data") {
                        Task {
                            await dayStore.health.requestAuthorization()
                            await dayStore.health.seedSampleData()
                            await dayStore.sync(profile: profile)
                        }
                    }
                    Button("Restart onboarding", role: .destructive) {
                        profile.onboardingComplete = false
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .manageSubscriptionsSheet(isPresented: $showManage)
            .onChange(of: profile.notificationsEnabled) { _, on in updateReminders(on) }
            .onChange(of: profile.morningMinutes) { _, _ in updateReminders(profile.notificationsEnabled) }
            .onChange(of: profile.eveningMinutes) { _, _ in updateReminders(profile.notificationsEnabled) }
            .onChange(of: profile.checkInsRaw) { _, _ in
                try? context.save()
                Task { await dayStore.sync(days: 1, profile: profile) }
            }
        }
    }

    private func updateReminders(_ on: Bool) {
        if on {
            Task {
                profile.notificationsEnabled = await Notifications.requestAndSchedule(
                    morningMinutes: profile.morningMinutes, eveningMinutes: profile.eveningMinutes)
            }
        } else {
            Notifications.cancelAll()
        }
    }

    /// Full at 4, and the last positive habit can't be removed (no positives = free habit points).
    private func isLocked(_ kind: CheckInKind) -> Bool {
        let on = profile.checkIns.contains(kind)
        if !on { return profile.checkIns.count >= 4 }
        return !kind.isNegative && profile.checkIns.filter { !$0.isNegative }.count <= 1
    }

    private func checkInBinding(_ kind: CheckInKind) -> Binding<Bool> {
        Binding {
            profile.checkIns.contains(kind)
        } set: { on in
            if on { profile.checkIns.append(kind) } else { profile.checkIns.removeAll { $0 == kind } }
        }
    }

    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<UserProfile, Int>) -> Binding<Date> {
        Binding {
            let minutes = profile[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            profile[keyPath: keyPath] = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
    }
}
