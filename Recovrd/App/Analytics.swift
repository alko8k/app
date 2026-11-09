import Foundation
import PostHog

/// Product analytics via PostHog.
///
/// Apple's HealthKit rules (guideline 5.1.3) forbid sharing health data with analytics,
/// so events are a fixed enum and properties are limited to step names and booleans.
/// Never add sleep, steps, scores or which check-in was tapped here.
enum Analytics {
    enum Event {
        case onboardingStepViewed(OnboardingStep)
        case healthConnected
        case healthSkipped
        case notificationsEnabled
        case notificationsSkipped
        case paywallViewed
        case trialStarted
        case restoreTapped
        case checkInTapped
        case trendsViewed

        var name: String {
            switch self {
            case .onboardingStepViewed: "onboarding_step_viewed"
            case .healthConnected: "health_connected"
            case .healthSkipped: "health_skipped"
            case .notificationsEnabled: "notifications_enabled"
            case .notificationsSkipped: "notifications_skipped"
            case .paywallViewed: "paywall_viewed"
            case .trialStarted: "trial_started"
            case .restoreTapped: "restore_tapped"
            case .checkInTapped: "checkin_tapped"
            case .trendsViewed: "trends_viewed"
            }
        }

        var properties: [String: Any]? {
            switch self {
            case .onboardingStepViewed(let step): ["step": step.analyticsName, "index": step.rawValue]
            default: nil
            }
        }
    }

    private static var isEnabled = false

    /// Call once at launch. Does nothing without a key, so dev builds stay quiet.
    static func configure() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String, !key.isEmpty else { return }
        let config = PostHogConfig(projectToken: key, host: "https://us.i.posthog.com")
        config.captureScreenViews = false      // screen names are fine, but we send our own
        config.captureApplicationLifecycleEvents = true
        config.sessionReplay = false           // screens show health data
        config.personProfiles = .never
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func track(_ event: Event) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }
}

extension OnboardingStep {
    var analyticsName: String {
        switch self {
        case .hero: "hero"
        case .howItWorks: "how_it_works"
        case .goals: "goals"
        case .rhythm: "rhythm"
        case .checkIns: "check_ins"
        case .health: "health"
        case .building: "score_preview"
        case .notifications: "notifications"
        }
    }
}
