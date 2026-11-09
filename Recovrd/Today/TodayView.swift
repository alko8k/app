import SwiftUI

struct TodayView: View {
    let profile: UserProfile
    @Environment(DayStore.self) private var dayStore

    var body: some View {
        let _ = dayStore.revision
        let score = dayStore.score(for: .now, profile: profile, cache: false)
        let checked = dayStore.existingRecord(for: .now)?.checkIns ?? []
        let evening = isEvening

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header(score)

                    if !evening {
                        MorningCard(score: score)
                    }

                    VStack(spacing: 10) {
                        ScoreRingView(score: score.total, potential: evening ? nil : score.potential, size: 210, lineWidth: 18,
                                      caption: evening ? "final score" : "so far")
                        Text(evening
                             ? "Today's final score"
                             : (score.potential > score.total ? "Up to \(score.potential) still possible today" : "Maxed out. Nice work."))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 10)

                    if evening {
                        EveningCard(score: score, profile: profile)
                    }

                    CheckInBar(enabled: profile.checkIns, checked: checked) { kind in
                        dayStore.toggle(kind, profile: profile)
                        Analytics.track(.checkInTapped) // no kind: check-ins are health-adjacent
                    }

                    BreakdownView(score: score)

                    if !dayStore.health.hasRequested {
                        Card {
                            Label("Connect Apple Health in Settings to score sleep and movement automatically.", systemImage: "heart.text.square")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .refreshable { await dayStore.sync(days: 2, profile: profile) }
        }
    }

    private var isEvening: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-evening") { return true }
        #endif
        let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0) >= profile.eveningMinutes
    }

    private func header(_ score: DayScore) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.textTertiary)
                Text("Today")
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Label(score.dayType.label, systemImage: score.dayType == .light ? "leaf.fill" : "bolt.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke))
        }
        .padding(.top, 8)
    }
}

struct MorningCard: View {
    let score: DayScore

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Last night", systemImage: "moon.stars.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(Explanation.morningNote(for: score))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(score.dayType.suggestion)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EveningCard: View {
    let score: DayScore
    let profile: UserProfile

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(Explanation.summary(for: score))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Theme.stroke)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("For tomorrow")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Text(Explanation.tip(for: score, sleepTarget: profile.bedtimeLabel))
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct CheckInBar: View {
    let enabled: [CheckInKind]
    let checked: Set<CheckInKind>
    var onToggle: (CheckInKind) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHECK-INS")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(enabled) { kind in
                    let on = checked.contains(kind)
                    let tint = kind.isNegative ? Theme.warning : Theme.accent
                    Button {
                        on ? Haptics.soft() : (kind.isNegative ? Haptics.tap() : Haptics.success())
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { onToggle(kind) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: on ? "checkmark" : kind.symbol)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(on ? Theme.onInk : tint)
                                .frame(width: 32, height: 32)
                                .background(on ? tint : tint.opacity(0.14), in: Circle())
                                .contentTransition(.symbolEffect(.replace))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.title)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if kind.isNegative {
                                    Text(on ? "−5 pts" : "Tap if you did")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(on ? Theme.warning : Theme.textTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(minHeight: 60)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? tint.opacity(0.5) : Theme.stroke))
                        .scaleEffect(on ? 1 : 0.985)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}
