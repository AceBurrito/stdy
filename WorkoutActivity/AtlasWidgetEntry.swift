// AtlasWidgetEntry.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Data model for the Atlas home screen widget timeline entries.

import WidgetKit

struct AtlasWidgetEntry: TimelineEntry {
    let date: Date

    // Top line — contextual message
    let paceChanged: Bool
    let paceDirection: String       // "improved" or "update"
    let checkInAvailable: Bool
    let checkInCompleted: Bool

    // Streak
    let streakCount: Int

    // Habits
    let habitsTotal: Int
    let habitsCompleted: Int
    let habitNames: [String]
    let habitStates: [Bool]

    // Training
    let workoutName: String
    let workoutExerciseCount: Int
    let workoutType: String         // "strength", "cardio", "rest"
    let isRestDay: Bool
    let workoutCompleted: Bool

    // Meta
    let dayCount: Int
}
