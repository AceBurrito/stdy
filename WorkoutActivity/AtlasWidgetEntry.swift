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
    /// Short call for the day, e.g. "Keep 2–3 reps in reserve"
    var recoveryHint: String = ""
    /// One line per input, e.g. ["HRV −35%", "RHR at avg", "Sleep —"]
    var signals: [String] = []

    // Training
    let workoutName: String
    let workoutExerciseCount: Int
    let workoutType: String         // "strength", "cardio", "rest"
    let isRestDay: Bool
    let workoutCompleted: Bool
    /// Planned exercises in order: (name, "3 × 10")
    var exercises: [(name: String, scheme: String)] = []
    /// Cardio detail, e.g. "30 min · 130–145 bpm"
    var workoutDetail: String = ""

    // Body snapshot (still written by the app; no longer shown on the widget)
    var weightText: String = ""
    var bodyFatText: String = ""
    var weightTrendText: String = ""
}

// MARK: - Sample Data

extension AtlasWidgetEntry {
    static let sample = AtlasWidgetEntry(
        date: Date(),
        recoveryState: "manage",
        recoveryHint: "Keep 2–3 reps in reserve",
        signals: ["HRV −35%", "RHR at avg", "Sleep —"],
        workoutName: "C: Hinge + Pull",
        workoutExerciseCount: 5,
        workoutType: "strength",
        isRestDay: false,
        workoutCompleted: false,
        exercises: [
            (name: "Romanian Deadlift (Barbell)", scheme: "3 × 10"),
            (name: "Bulgarian Split Squat", scheme: "3 × 10"),
            (name: "Tricep Pushdown", scheme: "3 × 12"),
            (name: "Seated Cable Row", scheme: "3 × 12"),
            (name: "Face Pull", scheme: "3 × 15")
        ]
    )
}
