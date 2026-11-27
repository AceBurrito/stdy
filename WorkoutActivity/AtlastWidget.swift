// AtlasWidget.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Home screen widget definition. Supports systemSmall and systemMedium.
// Small: recovery state + today's training. Medium: adds a body comp snapshot.
// The kind stays "AtlasWidget" so widgets users already placed keep working.

import WidgetKit
import SwiftUI

struct AtlasWidget: Widget {
    let kind: String = "AtlasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtlasWidgetProvider()) { entry in
            AtlasWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recovery & Training")
        .description("Today's recovery state, training, and body composition.")
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
        date: Date(), recoveryState: "manage",
        workoutName: "Lower A", workoutExerciseCount: 5, workoutType: "strength",
        isRestDay: false, workoutCompleted: true,
        weightText: "182.4 lbs", bodyFatText: "", weightTrendText: ""
    )
    AtlasWidgetEntry(
        date: Date(), recoveryState: "",
        workoutName: "Rest Day", workoutExerciseCount: 0, workoutType: "rest",
        isRestDay: true, workoutCompleted: false,
        weightText: "", bodyFatText: "", weightTrendText: ""
    )
}

#Preview(as: .systemMedium) {
    AtlasWidget()
} timeline: {
    AtlasWidgetEntry.sample
    AtlasWidgetEntry(
        date: Date(), recoveryState: "ready",
        workoutName: "Zone 2", workoutExerciseCount: 0, workoutType: "cardio",
        isRestDay: false, workoutCompleted: false,
        weightText: "82.7 kg", bodyFatText: "16.9%", weightTrendText: "−0.4 kg / 7d"
    )
}
