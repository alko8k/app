import SwiftUI

/// Staged loader, then a real preview of yesterday's score: the onboarding's "aha" moment.
struct BuildingScoreStep: View {
    let profile: UserProfile
    var onNext: () -> Void

    @Environment(DayStore.self) private var dayStore
    @State private var stage = 0
    @State private var preview: DayScore?
    @State private var isExample = false

    private let stages = [
        "Reading last night's sleep",
        "Checking yesterday's movement",
        "Learning your rhythm",
        "Scoring your day",
    ]

    var body: some View {
        Group {
            if let preview {
                result(preview)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                loader
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: preview)
        .task { await build() }
    }

    private var loader: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle().stroke(Theme.track, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: Double(stage) / Double(stages.count))
                    .stroke(Theme.ring, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: stage)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.pulse)
            }
            .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, text in
                    HStack(spacing: 12) {
                        ZStack {
                            if index < stage {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                                    .transition(.scale.combined(with: .opacity))
                            } else if index == stage {
                                ProgressView().controlSize(.small).tint(Theme.textSecondary)
                            } else {
                                Image(systemName: "circle").foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .frame(width: 22)
                        Text(text + (index == stage ? "…" : ""))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(index <= stage ? Theme.textPrimary : Theme.textTertiary)
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func result(_ score: DayScore) -> some View {
        OnboardingScaffold(
            eyebrow: isExample ? "Example day" : "Yesterday, scored",
            title: isExample ? "Here's what a day looks like." : "Here's how you did yesterday.",
            subtitle: isExample
                ? "We couldn't find Apple Health data yet. This is a sample; your real score starts today."
                : "Pulled straight from Apple Health. Check-ins start counting from today.",
            cta: "Continue",
            action: onNext
        ) {
            VStack(spacing: 20) {
                ScoreRingView(score: score.total, size: 190, lineWidth: 16)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(Explanation.summary(for: score))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(score.pillars.filter(\.hasData), id: \.pillar) { pillar in
                            PillarRow(score: pillar)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.accent)
                    Text(Explanation.tip(for: score, sleepTarget: profile.bedtimeLabel))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func build() async {
        async let sync: Void = dayStore.sync(days: 8, profile: profile)
        for i in 1...stages.count {
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation { stage = i }
            Haptics.select()
        }
        await sync

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let record = dayStore.record(for: yesterday)
        var score: DayScore
        if record.sleepHours == nil && record.steps == nil && record.workoutMinutes == 0 {
            isExample = true
            score = ScoringEngine.score(day: Self.exampleDay, history: [], profile: profile.scoringProfile)
        } else {
            score = dayStore.score(for: yesterday, profile: profile)
            // No check-ins existed yesterday, so leave habits out rather than showing a zero.
            score.habits.hasData = false
            score.gaps.removeAll {
                if case .missedHabit = $0.gap { return true }
                return false
            }
            score.total = ScoringEngine.scaledTotal(score.pillars)
        }
        Haptics.success()
        preview = score
    }

    static let exampleDay = DayInputs(
        date: .now, sleepHours: 7 + 40.0 / 60, bedtimeMinutes: 660, steps: 8214, workoutMinutes: 32,
        checkIns: [.water, .stretch, .lateCoffee]
    )
}
