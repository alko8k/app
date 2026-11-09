import SwiftUI

struct GoalsStep: View {
    @Bindable var profile: UserProfile
    var onNext: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Your goal",
            title: "What do you want more of?",
            subtitle: "Pick as many as you like. We'll tune your tips to match.",
            ctaEnabled: !profile.goals.isEmpty,
            action: onNext
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RecoveryGoal.allCases) { goal in
                    let selected = profile.goals.contains(goal)
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selected { profile.goals.removeAll { $0 == goal } } else { profile.goals.append(goal) }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: goal.symbol)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(selected ? Theme.onInk : Theme.accent)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected ? Theme.onInk : Theme.textTertiary)
                            }
                            Text(goal.title)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Theme.onInk : Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                        }
                        .padding(16)
                        .background(selected ? Theme.ink : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(selected ? .clear : Theme.stroke))
                        .scaleEffect(selected ? 1.0 : 0.98)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct RhythmStep: View {
    @Bindable var profile: UserProfile
    var onNext: () -> Void

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Your rhythm",
            title: "When does your day usually start and end?",
            subtitle: "A steady bedtime is worth up to 15 points a day.",
            action: onNext
        ) {
            VStack(spacing: 14) {
                Card {
                    VStack(spacing: 16) {
                        timeRow("Bedtime", symbol: "moon.fill", color: Theme.textPrimary, minutes: $profile.bedtimeMinutes)
                        Divider().overlay(Theme.stroke)
                        timeRow("Wake up", symbol: "sun.max.fill", color: Theme.textPrimary, minutes: $profile.wakeMinutes)
                        HStack {
                            Text("That's \(ScoringEngine.formatHours(hoursInBed)) in bed")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(hoursInBed >= 7 ? Theme.accent : Theme.warning)
                                .contentTransition(.numericText())
                            Spacer()
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Training days per week", systemImage: "figure.run")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(spacing: 6) {
                            ForEach(0...7, id: \.self) { n in
                                let selected = profile.trainingDaysPerWeek == n
                                Button("\(n)") {
                                    Haptics.select()
                                    withAnimation(.spring(response: 0.3)) { profile.trainingDaysPerWeek = n }
                                }
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Theme.onInk : Theme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(selected ? Theme.ink : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Coffee after 4pm", systemImage: "cup.and.saucer.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(spacing: 8) {
                            ForEach(CaffeineHabit.allCases) { habit in
                                let selected = profile.caffeine == habit
                                Button(habit.title) {
                                    Haptics.select()
                                    withAnimation(.spring(response: 0.3)) { profile.caffeine = habit }
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Theme.onInk : Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? Theme.ink : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var hoursInBed: Double {
        var minutes = profile.wakeMinutes - profile.bedtimeMinutes
        if minutes <= 0 { minutes += 24 * 60 }
        return Double(minutes) / 60
    }

    private func timeRow(_ title: String, symbol: String, color: Color, minutes: Binding<Int>) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            DatePicker("", selection: dateBinding(minutes), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .tint(color)
    }

    private func dateBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            withAnimation { minutes.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0) }
        }
    }
}

struct CheckInPickerStep: View {
    @Bindable var profile: UserProfile
    var onNext: () -> Void

    private let range = 3...4

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Your check-ins",
            title: "Pick 3 or 4 daily check-ins.",
            subtitle: "Each one takes a single tap. Red ones cost points when you log them.",
            cta: range.contains(profile.checkIns.count) ? "Continue" : "Pick \(max(0, range.lowerBound - profile.checkIns.count)) more",
            ctaEnabled: range.contains(profile.checkIns.count),
            action: onNext
        ) {
            VStack(spacing: 10) {
                ForEach(CheckInKind.allCases) { kind in
                    let selected = profile.checkIns.contains(kind)
                    let full = profile.checkIns.count >= range.upperBound && !selected
                    Button {
                        guard !full else { return Haptics.tap() }
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selected { profile.checkIns.removeAll { $0 == kind } } else { profile.checkIns.append(kind) }
                        }
                    } label: {
                        row(kind, selected: selected)
                            .opacity(full ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func row(_ kind: CheckInKind, selected: Bool) -> some View {
        let color = kind.isNegative ? Theme.warning : Theme.accent
        return HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(kind.isNegative ? "\(kind.subtitle) · −5 pts" : kind.subtitle)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? Theme.ink : Theme.stroke, lineWidth: selected ? 1.5 : 1))
    }
}
