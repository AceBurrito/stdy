// AtlasWidgetEntry.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Data model for the home screen widget timeline entries.
// Values are written by the app (WidgetDataWriter) into App Group UserDefaults.

import WidgetKit

struct AtlasWidgetEntry: TimelineEntry {
    let date: Date

    // Recovery — raw value of the app's RecoveryState ("ready", "good", "manage", "recover"), "" if unknown
    let recoveryState: String

    // Training
    let workoutName: String
    let workoutExerciseCount: Int
    let workoutType: String         // "strength", "cardio", "rest"
    let isRestDay: Bool
    let workoutCompleted: Bool

    // Body snapshot (pre-formatted by the app in the user's units)
    let weightText: String
    let bodyFatText: String
    let weightTrendText: String
}

// MARK: - Sample Data

extension AtlasWidgetEntry {
    static let sample = AtlasWidgetEntry(
        date: Date(),
        recoveryState: "good",
        workoutName: "Upper A",
        workoutExerciseCount: 5,
        workoutType: "strength",
        isRestDay: false,
        workoutCompleted: false,
        weightText: "182.4 lbs",
        bodyFatText: "18.2%",
        weightTrendText: "−0.8 lbs / 7d"
    )
}
