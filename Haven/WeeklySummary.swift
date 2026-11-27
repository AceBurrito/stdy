// WeeklySummary.swift
// Steady — one local notification a week, Sunday 6 PM, summing up training.
//
// Local notifications carry fixed text, so the summary is rebuilt every time the
// app opens. When the last open was on Sunday before 6 PM, the notification
// carries the week's numbers; otherwise it's a short nudge to look at the week,
// so it never reports a half week as if it were the whole thing.

import Foundation
import SwiftData
import UserNotifications

enum WeeklySummary {
    static let identifier = "steady_weekly_summary"
    static let enabledKey = "weeklySummaryEnabled"
    static let hour = 18

    /// Defaults to on; the user can turn it off under More.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Rebuilds and reschedules the next summary. Call on launch and foreground.
    @MainActor
    static func refresh(modelContext: ModelContext, unitFormatter: UnitFormatter) {
        let center = UNUserNotificationCenter.current()
        guard isEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let body = summaryBody(modelContext: modelContext, unitFormatter: unitFormatter)
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your training week"
            content.body = body
            content.sound = .default

            var components = DateComponents()
            components.weekday = 1          // Sunday
            components.hour = WeeklySummary.hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            center.removePendingNotificationRequests(withIdentifiers: [WeeklySummary.identifier])
            try? await center.add(UNNotificationRequest(identifier: WeeklySummary.identifier, content: content, trigger: trigger))
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Content

    @MainActor
    static func summaryBody(modelContext: ModelContext, unitFormatter: UnitFormatter, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let isSundayBeforeSend = calendar.component(.weekday, from: now) == 1 && calendar.component(.hour, from: now) < hour
        guard isSundayBeforeSend else {
            return "See how the week went: sets per muscle, lift trends and your body trend."
        }

        let weekStart = MuscleVolume.weekStart(for: now)
        let lookback = calendar.date(byAdding: .day, value: -70, to: now) ?? now
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= lookback }
        ))) ?? []
        let custom = (try? modelContext.fetch(FetchDescriptor<CustomExercise>())) ?? []
        let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first
        let entries = (try? modelContext.fetch(FetchDescriptor<BodyCompEntry>())) ?? []
        let resolver = MuscleGroupResolver(customExercises: custom)

        var parts: [String] = []

        let thisWeek = sessions.filter { $0.date >= weekStart }
        let sets = thisWeek.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.filter { $0.reps > 0 }.count } }
        if thisWeek.isEmpty {
            parts.append("No strength sessions logged this week.")
        } else {
            parts.append("\(thisWeek.count) session\(thisWeek.count == 1 ? "" : "s"), \(sets) working sets.")
        }

        let rows = MuscleVolume.rows(sessions: sessions, window: .thisWeek, experience: profile?.experienceLevel, resolver: resolver)
        let under = rows.filter { $0.sets < Double($0.minimum) }.map { $0.group.shortName.lowercased() }
        if !thisWeek.isEmpty {
            if under.isEmpty {
                parts.append("Every muscle group hit its minimum.")
            } else if under.count <= 3 {
                parts.append("Under minimum: \(under.joined(separator: ", ")).")
            } else {
                parts.append("\(under.count) muscle groups under minimum.")
            }
        }

        let newBests = LiftAnalytics.histories(sessions: sessions, resolver: resolver)
            .filter { lift in lift.points.contains { $0.isPR && $0.date >= weekStart } }
        if let first = newBests.first {
            parts.append(newBests.count == 1 ? "New best on \(first.name)." : "\(newBests.count) new bests, including \(first.name).")
        }

        let state = BodyState.from(entries: entries, profile: profile)
        if let rate = state.weeklyWeightRate {
            let value = unitFormatter.fromLbs(abs(rate))
            parts.append(value < 0.05
                ? "Weight holding steady."
                : String(format: "Weight %@%.1f %@/week.", rate > 0 ? "+" : "−", value, unitFormatter.weightUnit))
        }

        return parts.joined(separator: " ")
    }
}
