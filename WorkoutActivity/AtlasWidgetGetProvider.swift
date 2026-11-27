// AtlasWidgetProvider.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Reads widget data from shared UserDefaults (App Group) and provides
// timeline entries for the home screen widget.

import WidgetKit

struct AtlasWidgetProvider: TimelineProvider {
    let defaults = UserDefaults(suiteName: "group.com.atlas.workouts")

    func placeholder(in context: Context) -> AtlasWidgetEntry {
        AtlasWidgetEntry(
            date: Date(),
            paceChanged: true,
            paceDirection: "improved",
            checkInAvailable: false,
            checkInCompleted: false,
            streakCount: 4,
            habitsTotal: 3,
            habitsCompleted: 1,
            habitNames: ["Sauna Sessions", "Morning Sunlight", "Dead Hang"],
            habitStates: [false, true, false],
            workoutName: "Full Body A",
            workoutExerciseCount: 5,
            workoutType: "strength",
            isRestDay: false,
            workoutCompleted: false,
            dayCount: 12
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AtlasWidgetEntry) -> Void) {
        completion(readCurrentData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AtlasWidgetEntry>) -> Void) {
        let entry = readCurrentData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readCurrentData() -> AtlasWidgetEntry {
        AtlasWidgetEntry(
            date: Date(),
            paceChanged: defaults?.bool(forKey: "widget_paceChanged") ?? false,
            paceDirection: defaults?.string(forKey: "widget_paceDirection") ?? "update",
            checkInAvailable: defaults?.bool(forKey: "widget_checkInAvailable") ?? false,
            checkInCompleted: defaults?.bool(forKey: "widget_checkInCompleted") ?? false,
            streakCount: defaults?.integer(forKey: "widget_streakCount") ?? 0,
            habitsTotal: defaults?.integer(forKey: "widget_habitsTotal") ?? 3,
            habitsCompleted: defaults?.integer(forKey: "widget_habitsCompleted") ?? 0,
            habitNames: defaults?.stringArray(forKey: "widget_habitNames") ?? [],
            habitStates: (defaults?.array(forKey: "widget_habitStates") as? [Bool]) ?? [],
            workoutName: defaults?.string(forKey: "widget_workoutName") ?? "Rest Day",
            workoutExerciseCount: defaults?.integer(forKey: "widget_exerciseCount") ?? 0,
            workoutType: defaults?.string(forKey: "widget_workoutType") ?? "rest",
            isRestDay: defaults?.bool(forKey: "widget_isRestDay") ?? true,
            workoutCompleted: defaults?.bool(forKey: "widget_workoutCompleted") ?? false,
            dayCount: defaults?.integer(forKey: "widget_dayCount") ?? 1
        )
    }
}
