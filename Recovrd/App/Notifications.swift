import Foundation
import UserNotifications

enum Notifications {
    static func requestAndSchedule(morningMinutes: Int, eveningMinutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { schedule(morningMinutes: morningMinutes, eveningMinutes: eveningMinutes) }
        return granted
    }

    static func schedule(morningMinutes: Int, eveningMinutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning", "evening"])
        add(id: "morning", minutes: morningMinutes,
            title: "Last night's sleep is in",
            body: "See how you slept and what kind of day to have.")
        add(id: "evening", minutes: eveningMinutes,
            title: "Your day, scored",
            body: "Your final score and one tip for tomorrow are ready.")
    }

    /// The paywall promises a reminder on day 5 of the trial; this keeps that promise.
    /// Asks for permission first if the user skipped reminders during onboarding.
    static func scheduleTrialReminder(from start: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in 2 days"
        content.body = "Keep your streak going, or cancel anytime in Settings before day 7."
        content.sound = .default
        let fireDate = start.addingTimeInterval(5 * 24 * 3600)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "trialReminder", content: content, trigger: trigger))
    }

    /// `true` only when the user has explicitly turned notifications off for Recovrd.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func add(id: String, minutes: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
