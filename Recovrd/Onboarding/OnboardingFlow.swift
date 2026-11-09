import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case hero, howItWorks, goals, rhythm, checkIns, health, building, notifications

    /// Steps that show the progress bar and back button.
    var showsChrome: Bool { self != .hero && self != .building }
}

struct OnboardingFlow: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    @State private var step: OnboardingStep = .hero
    @State private var forward = true

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                if step.showsChrome {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                stepView
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
        }
        .onChange(of: step, initial: true) { _, current in
            Analytics.track(.onboardingStepViewed(current))
        }
        .onAppear {
            #if DEBUG
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-onboardingStep"),
               let raw = Int(ProcessInfo.processInfo.arguments[safe: index + 1] ?? ""),
               let start = OnboardingStep(rawValue: raw) {
                step = start
            }
            #endif
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                go(to: OnboardingStep(rawValue: step.rawValue - 1) ?? .hero)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.stroke))
            }
            .accessibilityLabel("Back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 44)
    }

    private var progress: Double {
        Double(step.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .hero: HeroStep { advance() }
        case .howItWorks: HowItWorksStep { advance() }
        case .goals: GoalsStep(profile: profile) { advance() }
        case .rhythm: RhythmStep(profile: profile) { advance() }
        case .checkIns: CheckInPickerStep(profile: profile) { advance() }
        case .health: HealthPermissionStep { advance() }
        case .building: BuildingScoreStep(profile: profile) { advance() }
        case .notifications: NotificationsStep(profile: profile) { finish() }
        }
    }

    private func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return finish() }
        go(to: next)
    }

    private func go(to target: OnboardingStep) {
        Haptics.soft()
        forward = target.rawValue > step.rawValue
        // Going back from the post-loader step skips the loader.
        let destination = (!forward && target == .building) ? .health : target
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { step = destination }
    }

    private func finish() {
        Haptics.success()
        profile.onboardingComplete = true
        try? context.save()
    }
}

/// Shared layout for question steps: title, subtitle, content, pinned CTA.
struct OnboardingScaffold<Content: View>: View {
    var eyebrow: String? = nil
    var title: String
    var subtitle: String? = nil
    var cta: String = "Continue"
    var ctaEnabled = true
    var secondary: (label: String, action: () -> Void)? = nil
    var action: () -> Void
    @ViewBuilder var content: Content

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let eyebrow {
                            Text(eyebrow.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(Theme.accent)
                        }
                        Text(title)
                            .font(.display(32, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                    content
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 4) {
                Button(cta) {
                    Haptics.tap()
                    action()
                }
                .buttonStyle(.primary(enabled: ctaEnabled))
                .disabled(!ctaEnabled)
                if let secondary {
                    Button(secondary.label, action: secondary.action)
                        .buttonStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { appeared = true }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
