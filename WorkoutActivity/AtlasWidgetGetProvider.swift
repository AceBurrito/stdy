// AtlasWidgetProvider.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// Reads widget data from shared UserDefaults (App Group) and provides
// timeline entries for the home screen widget.

import WidgetKit

struct AtlasWidgetProvider: TimelineProvider {
    let defaults = UserDefaults(suiteName: "group.com.atlas.workouts")

    func placeholder(in context: Context) -> AtlasWidgetEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (AtlasWidgetEntry) -> Void) {
        completion(context.isPreview ? .sample : readCurrentData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AtlasWidgetEntry>) -> Void) {
        let entry = readCurrentData()
        // The app pushes reloads on every change; this is a fallback so the
        // day rolls over even if the app isn't opened.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readCurrentData() -> AtlasWidgetEntry {
        let exerciseLines = defaults?.stringArray(forKey: "widget_exercises") ?? []
        let exercises: [(name: String, scheme: String)] = exerciseLines.map { line in
            let parts = line.components(separatedBy: "\t")
            return (name: parts.first ?? line, scheme: parts.count > 1 ? parts[1] : "")
        }
        return AtlasWidgetEntry(
            date: Date(),
            recoveryState: defaults?.string(forKey: "widget_recoveryState") ?? "",
            recoveryHint: defaults?.string(forKey: "widget_recoveryHint") ?? "",
            signals: defaults?.stringArray(forKey: "widget_signals") ?? [],
            workoutName: defaults?.string(forKey: "widget_workoutName") ?? "Rest Day",
            workoutExerciseCount: defaults?.integer(forKey: "widget_exerciseCount") ?? 0,
            workoutType: defaults?.string(forKey: "widget_workoutType") ?? "rest",
            isRestDay: defaults?.bool(forKey: "widget_isRestDay") ?? true,
            workoutCompleted: defaults?.bool(forKey: "widget_workoutCompleted") ?? false,
            exercises: exercises,
            workoutDetail: defaults?.string(forKey: "widget_workoutDetail") ?? "",
            weightText: defaults?.string(forKey: "widget_weightText") ?? "",
            bodyFatText: defaults?.string(forKey: "widget_bodyFatText") ?? "",
            weightTrendText: defaults?.string(forKey: "widget_weightTrendText") ?? ""
        )
    }
}
