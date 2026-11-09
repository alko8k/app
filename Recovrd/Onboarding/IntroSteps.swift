import SwiftUI

struct HeroStep: View {
    var onStart: () -> Void
    @State private var phase = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ZStack {
                ScoreRingView(score: phase >= 1 ? 82 : 0, size: 230, lineWidth: 20, caption: "today")
                floatingChip("moon.stars.fill", "7h 40m", Theme.textPrimary)
                    .offset(x: -118, y: -98)
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 10)
                floatingChip("figure.walk", "8,214", Theme.textPrimary)
                    .offset(x: 120, y: -40)
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 10)
                floatingChip("fork.knife", "Protein", Theme.textPrimary)
                    .offset(x: -96, y: 112)
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 10)
            }
            .frame(height: 320)

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                Text("Your day,\nscored.")
                    .font(.display(46, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                Text("A recovery coach that scores the things you control: sleep, movement and a few daily habits. Then it tells you exactly why.")
                    .font(.system(size: 17, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
            }
            .opacity(phase >= 3 ? 1 : 0)
            .offset(y: phase >= 3 ? 0 : 16)
            .padding(.horizontal, 24)

            Spacer(minLength: 28)

            Button("Get started", action: onStart)
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(phase >= 3 ? 1 : 0)
        }
        .task {
            phase = 1
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { phase = 2 }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.6)) { phase = 3 }
        }
    }

    private func floatingChip(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).foregroundStyle(Theme.textPrimary)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke))
    }
}

struct HowItWorksStep: View {
    var onNext: () -> Void
    @State private var visible = 0

    private let pillars: [(Pillar, Int, String)] = [
        (.sleep, 40, "How long you slept and how steady your bedtime was."),
        (.movement, 35, "Steps and workouts. A rest day after a hard one counts as a win."),
        (.habits, 25, "A few one-tap check-ins, like water, protein and a cutoff for coffee."),
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "How it works",
            title: "One score. Three things you control.",
            subtitle: "We score what you control, not your heart rate.",
            action: onNext
        ) {
            VStack(spacing: 12) {
                ForEach(Array(pillars.enumerated()), id: \.offset) { index, item in
                    pillarRow(item.0, points: item.1, text: item.2)
                        .opacity(visible > index ? 1 : 0)
                        .offset(x: visible > index ? 0 : 40)
                }

                HStack(spacing: 10) {
                    Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
                    Text("Every evening you get a plain-English breakdown and **one** tip for tomorrow.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 8)
                .opacity(visible > 3 ? 1 : 0)
            }
        }
        .task {
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 350 : 220))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { visible = i }
                if i <= 3 { Haptics.select() }
            }
        }
    }

    private func pillarRow(_ pillar: Pillar, points: Int, text: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: pillar.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.color(for: pillar))
                    .frame(width: 44, height: 44)
                    .background(Theme.color(for: pillar).opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pillar.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(points) pts")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.color(for: pillar))
                    }
                    Text(text)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
