import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Request Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                }
                print(granted ? "✅ Notifications authorized" : "❌ Notifications denied")
                completion(granted)
            }
        }
    }
    
    // MARK: - Check Permission Status
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Remove Legacy Atlas Reminders
    /// Atlas scheduled repeating reminders for the weekly check-in, habits, streaks
    /// and the morning brief. Those systems are gone, so clear any that are still
    /// pending on devices upgrading from Atlas. Safe to call on every launch.
    func removeLegacyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly_checkin", "evening_reminder", "streak_at_risk", "morning_brief"]
        )
    }
    
    // MARK: - Schedule Zone 2 Coaching Reminder
    func scheduleZone2CoachingReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Zone 2 Coaching Available"
        content.body = "We noticed you've been running hot. Let's dial in your cardio zones."
        content.sound = .default
        content.categoryIdentifier = "ZONE2_COACHING"
        
        // Schedule for tomorrow at 10am
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        }
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "zone2_coaching", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule Zone 2 coaching: \(error)")
            } else {
                print("✅ Zone 2 coaching reminder scheduled")
            }
        }
    }

    // MARK: - Cancel All Notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("✅ All notifications cancelled")
    }
    
    // MARK: - Debug: Print Pending Notifications
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Pending notifications: \(requests.count)")
            for request in requests {
                print("   - \(request.identifier): \(request.content.title)")
            }
        }
    }
}