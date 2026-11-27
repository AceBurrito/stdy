// WidgetDataWriter.swift
// Haven (Main App target ONLY)
//
// Writes widget data to the shared App Group UserDefaults container.
// The widget extension reads it in AtlasWidgetProvider. Widget data never
// goes through SwiftData directly. Every write ends with reloadAllTimelines().
//
// Keys (all prefixed "widget_"):
//   recoveryState      String  RecoveryState raw value, "" when unknown
//   workoutName        String
//   exerciseCount      Int
//   workoutType        String  "strength", "cardio", "rest"
//   isRestDay          Bool
//   workoutCompleted   Bool
//   weightText         String  e.g. "182.4 lbs", "" when unknown
//   bodyFatText        String  e.g. "18.2%", "" when unknown
//   weightTrendText    String  e.g. "−1.2 lbs / 7d", "" when unknown

import Foundation
import SwiftData
import WidgetKit

struct WidgetDataWriter {
    static let shared = WidgetDataWriter()

    private let defaults: UserDefaults?

    init() {
        let suite = UserDefaults(suiteName: "group.com.atlas.workouts")
        self.defaults = suite

        if suite == nil {
            print("❌ [Widget] Failed to create UserDefaults for group.com.atlas.workouts — App Group not accessible")
        }
    }

    // MARK: - Full Refresh

    func updateAll(
        recoveryState: RecoveryState?,
        workoutName: String,
        workoutExerciseCount: Int,
        workoutType: String,
        isRestDay: Bool,
        workoutCompleted: Bool,
        weightText: String,
        bodyFatText: String,
        weightTrendText: String
    ) {
        guard let defaults else {
            print("❌ [Widget] updateAll skipped — no shared defaults")
            return
        }

        defaults.set(recoveryState?.rawValue ?? "", forKey: "widget_recoveryState")
        defaults.set(workoutName, forKey: "widget_workoutName")
        defaults.set(workoutExerciseCount, forKey: "widget_exerciseCount")
        defaults.set(workoutType, forKey: "widget_workoutType")
        defaults.set(isRestDay, forKey: "widget_isRestDay")
        defaults.set(workoutCompleted, forKey: "widget_workoutCompleted")
        defaults.set(weightText, forKey: "widget_weightText")
        defaults.set(bodyFatText, forKey: "widget_bodyFatText")
        defaults.set(weightTrendText, forKey: "widget_weightTrendText")

        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Widget] updateAll — recovery: \(recoveryState?.rawValue ?? "none"), workout: \(workoutName), done: \(workoutCompleted)")
    }

    /// Removes keys the Atlas widget used (habits, streak, Pace, check-in).
    func removeLegacyKeys() {
        guard let defaults else { return }
        let legacy = [
            "widget_paceChanged", "widget_paceDirection", "widget_lastSeenPaceValue",
            "widget_checkInAvailable", "widget_checkInCompleted",
            "widget_streakCount", "widget_habitsTotal", "widget_habitsCompleted",
            "widget_habitNames", "widget_habitStates", "widget_dayCount"
        ]
        legacy.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Widget Sync

/// Builds the widget payload from SwiftData and writes it. Call on launch,
/// foreground, after a workout or cardio session is saved, and after a body
/// comp entry changes.
enum WidgetSync {
    static func refresh(modelContext: ModelContext, unitFormatter: UnitFormatter) {
        let metrics = (try? modelContext.fetch(FetchDescriptor<HealthMetrics>())) ?? []
        let recovery = RecoveryScoreCalculator.assess(metrics: metrics)

        let program = (try? modelContext.fetch(
            FetchDescriptor<TrainingProgram>(predicate: #Predicate { $0.isActive == true })
        ))?.first
        let plannedDay = TodayTraining.plannedDay(in: program)
        let completed = TodayTraining.isCompleted(plannedDay: plannedDay, modelContext: modelContext)

        let workoutType = plannedDay?.dayType ?? "rest"
        let isRest = plannedDay == nil || workoutType == "rest"

        let body = BodySnapshot.latest(modelContext: modelContext)

        WidgetDataWriter.shared.updateAll(
            recoveryState: recovery?.state,
            workoutName: isRest ? "Rest Day" : (plannedDay?.dayName ?? "Rest Day"),
            workoutExerciseCount: plannedDay?.exercises.count ?? 0,
            workoutType: workoutType,
            isRestDay: isRest,
            workoutCompleted: completed,
            weightText: body.weight.map { unitFormatter.displayWeight($0) } ?? "",
            bodyFatText: body.bodyFatPercent.map { String(format: "%.1f%%", $0 * 100) } ?? "",
            weightTrendText: body.weeklyChangeText(unitFormatter: unitFormatter) ?? ""
        )
    }
}
