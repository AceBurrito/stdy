// TodaySupport.swift
// Steady — shared logic behind the Today tab and the widget: which planned day
// is today, whether it's done, and the latest body composition snapshot.

import Foundation
import SwiftData

// MARK: - Today's Training

enum TodayTraining {
    /// 0 = Sunday ... 6 = Saturday, matching PlannedWorkoutDay.dayOfWeek
    static func todayDayOfWeek(_ date: Date = Date()) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    /// The active program's workout for today, or nil when nothing is scheduled.
    static func plannedDay(in program: TrainingProgram?, on date: Date = Date()) -> PlannedWorkoutDay? {
        let dow = todayDayOfWeek(date)
        return program?.workoutDays.first { $0.dayOfWeek == dow }
    }

    /// Done when the planned day was completed today, or when any session of
    /// the matching kind was logged today (so ad-hoc workouts count too).
    static func isCompleted(
        plannedDay: PlannedWorkoutDay?,
        workoutSessions: [WorkoutSession],
        cardioSessions: [CardioSession],
        on date: Date = Date()
    ) -> Bool {
        guard let day = plannedDay, day.dayType != "rest" else { return false }
        let calendar = Calendar.current
        if day.isPrimaryCompleted, let done = day.isPrimaryCompletedDate, calendar.isDate(done, inSameDayAs: date) {
            return true
        }
        switch day.dayType {
        case "strength":
            return workoutSessions.contains { calendar.isDate($0.date, inSameDayAs: date) }
        case "cardio":
            return cardioSessions.contains { calendar.isDate($0.date, inSameDayAs: date) }
        default:
            return false
        }
    }

    /// Same as above, fetching today's sessions from the context.
    static func isCompleted(plannedDay: PlannedWorkoutDay?, modelContext: ModelContext, on date: Date = Date()) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return false }
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []
        let cardio = (try? modelContext.fetch(FetchDescriptor<CardioSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))) ?? []
        return isCompleted(plannedDay: plannedDay, workoutSessions: workouts, cardioSessions: cardio, on: date)
    }
}

// MARK: - Body Snapshot

/// Latest weight and body fat from manual entries, falling back to the profile.
/// Weight in lbs; body fat as a fraction (0.18 = 18%).
struct BodySnapshot {
    let weight: Double?
    let bodyFatPercent: Double?
    /// Weight change over roughly the last 7 days (lbs), nil without enough entries.
    let weeklyChange: Double?

    /// weight × (1 − body fat)
    var leanMass: Double? {
        guard let weight, let bodyFatPercent else { return nil }
        return weight * (1 - bodyFatPercent)
    }

    static func from(entries: [BodyCompEntry], profile: UserProfile?) -> BodySnapshot {
        let sorted = entries.sorted { $0.date > $1.date }
        let latest = sorted.first
        let weight = latest?.weight ?? profile?.weight
        let bodyFat = sorted.first(where: { $0.bodyFat != nil })?.bodyFat ?? profile?.bodyFatPercent

        var change: Double? = nil
        if let latest, let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: latest.date) {
            // Closest entry at least 7 days older than the latest one
            if let reference = sorted.first(where: { $0.date <= weekAgo }) {
                change = latest.weight - reference.weight
            }
        }
        return BodySnapshot(weight: weight, bodyFatPercent: bodyFat, weeklyChange: change)
    }

    static func latest(modelContext: ModelContext) -> BodySnapshot {
        let entries = (try? modelContext.fetch(FetchDescriptor<BodyCompEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first
        return from(entries: entries, profile: profile)
    }

    func weeklyChangeText(unitFormatter: UnitFormatter) -> String? {
        guard let weeklyChange else { return nil }
        let value = unitFormatter.fromLbs(abs(weeklyChange))
        if value < 0.05 { return "No change / 7d" }
        let sign = weeklyChange > 0 ? "+" : "−"
        return String(format: "%@%.1f %@ / 7d", sign, value, unitFormatter.weightUnit)
    }
}
