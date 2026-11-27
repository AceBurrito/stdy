// AtlasWidget.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Home screen widget definition. Supports systemSmall and systemMedium.
// Shows habits, training, streak, Pace tease, and weekly check-in prompt.

import WidgetKit
import SwiftUI

struct AtlasWidget: Widget {
    let kind: String = "AtlasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtlasWidgetProvider()) { entry in
            AtlasWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Atlas")
        .description("Habits, training, and Pace updates at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AtlasWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AtlasWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            AtlasWidgetSmallView(entry: entry)
        case .systemMedium:
            AtlasWidgetMediumView(entry: entry)
        default:
            AtlasWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    AtlasWidget()
} timeline: {
    // Check-in state
    AtlasWidgetEntry(
        date: Date(),
        paceChanged: false, paceDirection: "improved",
        checkInAvailable: true, checkInCompleted: false,
        streakCount: 4,
        habitsTotal: 3, habitsCompleted: 1,
        habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
        habitStates: [false, true, false],
        workoutName: "Upper Body A", workoutExerciseCount: 5,
        workoutType: "strength", isRestDay: false, workoutCompleted: false,
        dayCount: 12
    )
    // Pace changed state
    AtlasWidgetEntry(
        date: Date(),
        paceChanged: true, paceDirection: "improved",
        checkInAvailable: false, checkInCompleted: false,
        streakCount: 7,
        habitsTotal: 3, habitsCompleted: 3,
        habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
        habitStates: [true, true, true],
        workoutName: "Lower Body", workoutExerciseCount: 5,
        workoutType: "strength", isRestDay: false, workoutCompleted: true,
        dayCount: 15
    )
    // Quiet day
    AtlasWidgetEntry(
        date: Date(),
        paceChanged: false, paceDirection: "improved",
        checkInAvailable: false, checkInCompleted: false,
        streakCount: 2,
        habitsTotal: 3, habitsCompleted: 0,
        habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
        habitStates: [false, false, false],
        workoutName: "Rest Day", workoutExerciseCount: 0,
        workoutType: "rest", isRestDay: true, workoutCompleted: false,
        dayCount: 8
    )
}

#Preview(as: .systemMedium) {
    AtlasWidget()
} timeline: {
    AtlasWidgetEntry(
        date: Date(),
        paceChanged: false, paceDirection: "improved",
        checkInAvailable: true, checkInCompleted: false,
        streakCount: 4,
        habitsTotal: 3, habitsCompleted: 1,
        habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
        habitStates: [false, true, false],
        workoutName: "Upper Body A", workoutExerciseCount: 5,
        workoutType: "strength", isRestDay: false, workoutCompleted: false,
        dayCount: 12
    )
    AtlasWidgetEntry(
        date: Date(),
        paceChanged: true, paceDirection: "improved",
        checkInAvailable: false, checkInCompleted: false,
        streakCount: 7,
        habitsTotal: 3, habitsCompleted: 3,
        habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
        habitStates: [true, true, true],
        workoutName: "Lower Body", workoutExerciseCount: 5,
        workoutType: "strength", isRestDay: false, workoutCompleted: true,
        dayCount: 15
    )
}
