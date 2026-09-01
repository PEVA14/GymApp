import Foundation
import UserNotifications

/// Lock-screen alerts for the rest timer.
///
/// The in-app countdown handles the case where you are looking at the phone.
/// This handles the case that actually matters in a gym: the phone is in your
/// pocket, screen off.
///
/// A single reused identifier means scheduling always *replaces* any pending
/// alert, so adjusting or restarting a rest can never leave a stale one queued.
enum RestNotifications {
    private static let identifier = "restTimerFinished"

    /// Asks the system for permission. Returns whether it was granted.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Schedules the alert for when rest ends, replacing any pending one.
    static func schedule(at date: Date) {
        let interval = date.timeIntervalSinceNow
        // A rest that has already elapsed needs no alert.
        guard interval > 0 else {
            cancel()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Rest finished"
        content.body = "Time for your next set."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
