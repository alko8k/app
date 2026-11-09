import SwiftUI

/// Legal pages linked from the paywall and Settings. Apple requires both to be reachable in-app.
enum LegalLinks {
    /// Apple's standard EULA; swap for custom terms if we ever write our own.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Must be live before submission (text is in PRIVACY.md).
    static let privacy = URL(string: "https://recovrd.app/privacy")!
}

struct PaywallView: View {
    let profile: UserProfile
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var remindersDenied = false

    private var headline: String {
        (profile.goals.first ?? .consistency).paywallHeadline
    }

    private let benefits: [(String, String)] = [
        ("circle.circle", "Your daily score, built automatically from Apple Health"),
        ("text.bubble.fill", "A plain-English breakdown every evening"),
        ("lightbulb.fill", "One focused tip for tomorrow, not ten"),
        ("chart.line.uptrend.xyaxis", "Weekly trends and what's moving your sleep"),
    ]

    var body: some View {
        @Bindable var subscriptions = subscriptions
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        HStack {
                            Spacer()
                            ScoreRingView(score: 82, size: 112, lineWidth: 11, caption: nil)
                            Spacer()
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(headline)
                                .font(.display(34, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Your plan is ready: \(profile.checkIns.count) check-ins, a \(profile.bedtimeLabel) bedtime target, and scoring tuned for \(profile.trainingDaysPerWeek) training days a week.")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(benefits, id: \.1) { symbol, text in
                                HStack(spacing: 12) {
                                    Image(systemName: symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 30, height: 30)
                                        .background(Theme.accent.opacity(0.1), in: Circle())
                                    Text(text)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }

                        if subscriptions.trialText != nil {
                            TrialTimeline(price: subscriptions.priceText, canRemind: !remindersDenied)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
                .scrollIndicators(.hidden)

                footer
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { subscriptions.errorMessage != nil }, set: { if !$0 { subscriptions.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptions.errorMessage ?? "")
        }
        .onAppear {
            Analytics.track(.paywallViewed)
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .task { remindersDenied = await Notifications.isDenied() }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                Task {
                    await subscriptions.purchase()
                    if subscriptions.isSubscribed { Haptics.success() }
                }
            } label: {
                if subscriptions.isPurchasing {
                    ProgressView().tint(Theme.onInk)
                } else {
                    Text(subscriptions.trialText.map { "Start \($0)" } ?? "Subscribe for \(subscriptions.priceText)/month")
                }
            }
            .buttonStyle(.primary)
            .disabled(subscriptions.isPurchasing)

            Text(subscriptions.trialText != nil
                 ? "Free for 7 days, then \(subscriptions.priceText)/month. Cancel anytime."
                 : "\(subscriptions.priceText)/month. Cancel anytime.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 18) {
                Button("Restore") { Task { await subscriptions.restore() } }
                Button("Terms") { openURL(LegalLinks.terms) }
                Button("Privacy") { openURL(LegalLinks.privacy) }
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textTertiary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.background.opacity(0.92).ignoresSafeArea(edges: .bottom))
    }
}

/// Today → reminder on day 5 → billing on day 7. Removes the fear of forgetting to cancel.
struct TrialTimeline: View {
    let price: String
    /// If notifications are off we can't promise a reminder, so say how to cancel instead.
    var canRemind = true

    private var items: [(String, String, String, Color)] {
        [
            ("lock.open.fill", "Today", "Full access. Your first score builds tonight.", Theme.ink),
            canRemind
                ? ("bell.fill", "Day 5", "We'll remind you before the trial ends.", Theme.ink)
                : ("gearshape.fill", "Day 5", "Cancel anytime in Settings before day 7.", Theme.ink),
            ("star.fill", "Day 7", "You're billed \(price)/month. Cancel before to pay nothing.", Theme.ink),
        ]
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Image(systemName: item.0)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.onInk)
                                .frame(width: 30, height: 30)
                                .background(item.3, in: Circle())
                            if index < items.count - 1 {
                                Rectangle().fill(Theme.track)
                                    .frame(width: 3, height: 30)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.1).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                            Text(item.2).font(.system(size: 14, design: .rounded)).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}
