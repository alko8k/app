import SwiftUI

/// Compact pillar line: icon, name, detail, points and a progress bar.
struct PillarRow: View {
    let score: PillarScore
    var expanded = false

    @State private var fill: Double = 0

    var body: some View {
        let color = Theme.color(for: score.pillar)
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: score.pillar.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(score.pillar.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(score.hasData ? score.detail : "No data")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(score.points.rounded()))/\(Int(score.pillar.maxPoints))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(score.hasData ? color : Theme.textTertiary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(color).frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.3)) { fill = score.hasData ? score.ratio : 0 } }
        .onChange(of: score.points) { _, _ in withAnimation(.spring(response: 0.6)) { fill = score.hasData ? score.ratio : 0 } }
    }
}

/// Expandable per-pillar breakdown on the Today screen.
struct BreakdownView: View {
    let score: DayScore
    @State private var expanded: Pillar?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Text("Breakdown")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.textTertiary)
                ForEach(score.pillars, id: \.pillar) { pillar in
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            Haptics.select()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                expanded = expanded == pillar.pillar ? nil : pillar.pillar
                            }
                        } label: {
                            PillarRow(score: pillar)
                        }
                        .buttonStyle(.plain)
                        if expanded == pillar.pillar {
                            Text(detail(for: pillar.pillar))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.leading, 32)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    private func detail(for pillar: Pillar) -> String {
        let lost = { (gap: ScoreGap) in Int((score.gaps.first { $0.gap == gap }?.points ?? 0).rounded()) }
        switch pillar {
        case .sleep:
            guard score.sleep.hasData else { return "No sleep found in Apple Health for last night. This pillar is left out of today's score." }
            return "Duration lost \(lost(.sleepDuration)) of 25 pts. Bedtime consistency lost \(lost(.bedtimeDrift)) of 15 pts (within 30 min of your usual is full marks)."
        case .movement:
            if score.dayType == .light {
                return "Light day after a hard one: 5,000+ steps or any easy activity earns all 35 pts. No workout needed."
            }
            return "Steps lost \(lost(.steps)) of 20 pts. Workout lost \(lost(.workout)) of 15 pts (30 active minutes is full marks)."
        case .habits:
            let penalties = score.gaps.compactMap { if case .penalty(let k) = $0.gap { k.title } else { nil } }
            let missed = score.gaps.compactMap { if case .missedHabit(let k) = $0.gap { k.title } else { nil } }
            var parts: [String] = []
            if !missed.isEmpty { parts.append("Still open: \(missed.joined(separator: ", ")).") }
            if !penalties.isEmpty { parts.append("Cost 5 pts each: \(penalties.joined(separator: ", ")).") }
            return parts.isEmpty ? "Every check-in done. Nice." : parts.joined(separator: " ")
        }
    }
}
