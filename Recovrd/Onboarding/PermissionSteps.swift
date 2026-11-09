import SwiftUI

struct HealthPermissionStep: View {
    var onNext: () -> Void
    @Environment(HealthService.self) private var health
    @State private var isRequesting = false
    @State private var orbit = false

    private let reads: [(String, String, Color, String)] = [
        ("moon.stars.fill", "Sleep", Theme.textPrimary, "Duration and bedtime"),
        ("figure.walk", "Steps", Theme.textPrimary, "Counted all day, live"),
        ("flame.fill", "Workouts & energy", Theme.textPrimary, "So rest days get rewarded"),
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Apple Health",
            title: "Let your score build itself.",
            subtitle: "Recovrd reads a few things from Apple Health so you never have to log sleep or steps.",
            cta: isRequesting ? "Connecting…" : "Connect Apple Health",
            ctaEnabled: !isRequesting,
            secondary: ("Not now", {
                Analytics.track(.healthSkipped)
                onNext()
            }),
            action: connect
        ) {
            VStack(spacing: 22) {
                ZStack {
                    Circle().stroke(Theme.stroke, lineWidth: 1).frame(width: 190, height: 190)
                    Circle().stroke(Theme.stroke, lineWidth: 1).frame(width: 120, height: 120)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 84, height: 84)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.stroke))
                    ForEach(Array(reads.enumerated()), id: \.offset) { index, item in
                        let angle = Double(index) * 120 + (orbit ? 360 : 0)
                        Image(systemName: item.0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.2)
                            .frame(width: 40, height: 40)
                            .background(Theme.surface, in: Circle())
                            .overlay(Circle().stroke(Theme.stroke))
                            .rotationEffect(.degrees(-angle)) // keep the glyph upright while orbiting
                            .offset(y: -95)
                            .rotationEffect(.degrees(angle))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)

                VStack(spacing: 10) {
                    ForEach(Array(reads.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.0).foregroundStyle(item.2).frame(width: 24)
                            Text(item.1).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(item.3).font(.system(size: 14, design: .rounded)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Label("Read-only. Your health data never leaves your iPhone.", systemImage: "lock.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { orbit = true }
        }
    }

    private func connect() {
        isRequesting = true
        Task {
            await health.requestAuthorization()
            Analytics.track(.healthConnected)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedHealth") { await health.seedSampleData() }
            #endif
            isRequesting = false
            onNext()
        }
    }
}

struct NotificationsStep: View {
    @Bindable var profile: UserProfile
    var onFinish: () -> Void
    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Stay on track",
            title: "Two nudges a day. That's it.",
            subtitle: "A morning note about your sleep, and your final score in the evening.",
            cta: "Turn on reminders",
            ctaEnabled: !isRequesting,
            secondary: ("Maybe later", {
                Analytics.track(.notificationsSkipped)
                onFinish()
            }),
            action: enable
        ) {
            VStack(spacing: 12) {
                notificationPreview(time: UserProfile.timeLabel(profile.morningMinutes),
                                    title: "7h 40m, bedtime was consistent, nice start.",
                                    body: "You trained hard yesterday, so today is a lighter movement day.")
                notificationPreview(time: UserProfile.timeLabel(profile.eveningMinutes),
                                    title: "Your day scored 82",
                                    body: "Great sleep and movement, protein was a little low. One tip for tomorrow inside.")
                    .padding(.horizontal, 10)
                    .opacity(0.8)
            }
            .padding(.top, 12)
        }
        .onAppear {
            // Defaults follow the rhythm step: 30 min after waking, 2h before bed.
            profile.morningMinutes = (profile.wakeMinutes + 30) % (24 * 60)
            profile.eveningMinutes = (profile.bedtimeMinutes - 120 + 24 * 60) % (24 * 60)
        }
    }

    private func enable() {
        isRequesting = true
        Task {
            profile.notificationsEnabled = await Notifications.requestAndSchedule(
                morningMinutes: profile.morningMinutes, eveningMinutes: profile.eveningMinutes)
            Analytics.track(profile.notificationsEnabled ? .notificationsEnabled : .notificationsSkipped)
            isRequesting = false
            onFinish()
        }
    }

    private func notificationPreview(time: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surfaceRaised)
                Circle().trim(from: 0, to: 0.82).stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(8)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("RECOVRD").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(time).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                }
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(body).font(.system(size: 14)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.stroke))
    }
}
