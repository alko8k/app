import Foundation
import RevenueCat

/// Subscriptions via RevenueCat: purchases, entitlement checks and revenue analytics.
@MainActor
@Observable
final class SubscriptionManager {
    static let entitlementID = "premium"

    /// Public SDK key from Info.plist (set via the REVENUECAT_API_KEY build setting).
    static var apiKey: String? {
        let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
        return key?.isEmpty == false ? key : nil
    }

    /// Call once at launch, before any other use.
    static func configure() {
        guard let apiKey else {
            print("RevenueCat: no API key set; purchases are disabled.")
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    private(set) var monthly: Package?
    private(set) var isSubscribed = false
    private(set) var isEligibleForTrial = true
    private(set) var isPurchasing = false
    private(set) var hasLoaded = false
    private(set) var expirationDate: Date?
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var isConfigured: Bool { Purchases.isConfigured }
    private var skipPaywall: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipPaywall")
        #else
        false
        #endif
    }

    init() {
        if skipPaywall { isSubscribed = true }
        guard isConfigured else { return }
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    func load() async {
        defer { hasLoaded = true }
        guard isConfigured else {
            if !skipPaywall {
                errorMessage = "Purchases aren't set up in this build yet."
            }
            return
        }
        do {
            monthly = try await Purchases.shared.offerings().current?.monthly
            if let product = monthly?.storeProduct {
                let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
                isEligibleForTrial = status != .ineligible
            }
            apply(try await Purchases.shared.customerInfo())
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    func purchase() async {
        guard let monthly else {
            await load()
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: monthly)
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
            if result.customerInfo.entitlements[Self.entitlementID]?.periodType == .trial {
                Analytics.track(.trialStarted)
                await Notifications.scheduleTrialReminder()
            }
        } catch {
            errorMessage = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        Analytics.track(.restoreTapped)
        guard isConfigured else { return }
        do {
            apply(try await Purchases.shared.restorePurchases())
        } catch {
            errorMessage = "Couldn't restore purchases right now."
        }
        if !isSubscribed, errorMessage == nil {
            errorMessage = "No active subscription found for this Apple ID."
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.entitlementID]
        isSubscribed = entitlement?.isActive == true || skipPaywall
        expirationDate = entitlement?.expirationDate
    }

    // MARK: - Display

    var priceText: String { monthly?.storeProduct.localizedPriceString ?? "$9.99" }

    var trialText: String? {
        guard isEligibleForTrial else { return nil }
        guard let offer = monthly?.storeProduct.introductoryDiscount, offer.paymentMode == .freeTrial else {
            return monthly == nil ? "7-day free trial" : nil
        }
        let period = offer.subscriptionPeriod
        switch period.unit {
        case .day: return "\(period.value)-day free trial"
        case .week: return "\(period.value * 7)-day free trial"
        default: return "Free trial"
        }
    }
}
