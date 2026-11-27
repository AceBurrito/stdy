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
    
    // MARK: - Schedule Weekly Check-In (Sundays 9am)
    func scheduleWeeklyCheckInReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Coaching Available"
        content.body = "Review your progress and get personalized guidance for the week ahead."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_CHECKIN"
        
        // Every Sunday at 9am
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_checkin", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly check-in: \(error)")
            } else {
                print("✅ Weekly check-in scheduled for Sundays 9am")
            }
        }
    }
    
    // MARK: - Schedule Evening Habit Reminder (6pm)
    func scheduleEveningReminder(incompleteCount: Int) {
        // Remove existing evening reminder first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_reminder"])
        
        guard incompleteCount > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak"
        content.body = incompleteCount == 1 
            ? "You have 1 habit left to complete today." 
            : "You have \(incompleteCount) habits left to complete today."
        content.sound = .default
        content.categoryIdentifier = "EVENING_REMINDER"
        
        // Today at 6pm
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        // Only schedule if 6pm hasn't passed
        if let scheduledDate = Calendar.current.date(from: dateComponents), scheduledDate > Date() {
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "evening_reminder", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule evening reminder: \(error)")
                } else {
                    print("✅ Evening reminder scheduled for 6pm (\(incompleteCount) habits)")
                }
            }
        }
    }
    
    // MARK: - Schedule Streak at Risk Reminder (8pm)
    func scheduleStreakAtRiskReminder(incompleteCount: Int, currentStreak: Int) {
        // Remove existing streak reminder first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])
        
        guard incompleteCount > 0, currentStreak > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak at Risk"
        content.body = "Your \(currentStreak)-day streak ends at midnight. You've got this."
        content.sound = .default
        content.categoryIdentifier = "STREAK_AT_RISK"
        
        // Today at 8pm
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        // Only schedule if 8pm hasn't passed
        if let scheduledDate = Calendar.current.date(from: dateComponents), scheduledDate > Date() {
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "streak_at_risk", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule streak at risk: \(error)")
                } else {
                    print("✅ Streak at risk reminder scheduled for 8pm")
                }
            }
        }
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

    // MARK: - Schedule Morning Brief Reminder (Sprint 5 — Engagement Overhaul)

    /// Schedules or cancels a daily morning brief notification at 7:00 AM.
    func scheduleMorningBriefReminder(enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["morning_brief"]
        )

        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your morning brief is ready"
        content.body = "See what your data says today."
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEF"

        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_brief", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule morning brief: \(error)")
            } else {
                print("✅ Morning brief reminder scheduled for 7am")
            }
        }
    }
    
    // MARK: - Cancel All Habit Reminders (when all complete)
    func cancelDailyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["evening_reminder", "streak_at_risk"]
        )
        print("✅ Daily reminders cancelled (habits complete)")
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