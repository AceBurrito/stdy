// AtlasWidget.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Home screen widget definition. Supports systemSmall and systemMedium.
// Small: today's recovery call + workout. Medium: adds why (HRV/RHR/sleep)
// and a preview of the workout's first exercises.
// The kind stays "AtlasWidget" so widgets users already placed keep working.

import WidgetKit
import SwiftUI

struct AtlasWidget: Widget {
    let kind: String = "AtlasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtlasWidgetProvider()) { entry in
            AtlasWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("How recovered you are, what that means for today, and the workout you have planned.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AtlasWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AtlasWidgetEntry

    var body: some View {
        switch family {
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
    AtlasWidgetEntry.sample
    AtlasWidgetEntry(
        date: Date(), recoveryState: "", workoutName: "Rest Day", workoutExerciseCount: 0,
        workoutType: "rest", isRestDay: true, workoutCompleted: false
    )
}

#Preview(as: .systemMedium) {
    AtlasWidget()
} timeline: {
    AtlasWidgetEntry.sample
    AtlasWidgetEntry(
        date: Date(), recoveryState: "ready", recoveryHint: "Go heavy today",
        signals: ["HRV +12%", "RHR −3", "Sleep 7.8h"],
        workoutName: "Zone 2", workoutExerciseCount: 0, workoutType: "cardio",
        isRestDay: false, workoutCompleted: false, workoutDetail: "30 min · 130–145 bpm"
    )
    AtlasWidgetEntry(
        date: Date(), recoveryState: "good", recoveryHint: "Train as planned",
        signals: ["HRV at avg", "RHR at avg", "Sleep 7.1h"],
        workoutName: "A: Push", workoutExerciseCount: 5, workoutType: "strength",
        isRestDay: false, workoutCompleted: true
    )
}
