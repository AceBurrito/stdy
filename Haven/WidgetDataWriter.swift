// WidgetDataWriter.swift
// Haven (Main App target ONLY)
//
// Writes widget data to the shared App Group UserDefaults container.
// The widget extension reads this data via AtlasWidgetProvider.
// Call the appropriate update method after any relevant state change,
// then WidgetCenter.reloadAllTimelines() is called automatically.

import Foundation
import WidgetKit

struct WidgetDataWriter {
    static let shared = WidgetDataWriter()
    
    private let defaults: UserDefaults?
    
    init() {
        let suite = UserDefaults(suiteName: "group.com.atlas.workouts")
        self.defaults = suite
        
        if suite == nil {
            print("❌ [Widget] Failed to create UserDefaults for group.com.atlas.workouts — App Group not accessible")
        } else {
            print("✅ [Widget] Shared UserDefaults container initialized")
        }
    }

    // MARK: - Full Refresh

    /// Call on app launch, foreground entry, midnight rollover, and any major state change.
    func updateAll(
        paceChanged: Bool,
        paceDirection: String,
        checkInAvailable: Bool,
        checkInCompleted: Bool,
        streakCount: Int,
        habitsTotal: Int,
        habitsCompleted: Int,
        habitNames: [String],
        habitStates: [Bool],
        workoutName: String,
        workoutExerciseCount: Int,
        workoutType: String,
        isRestDay: Bool,
        workoutCompleted: Bool,
        dayCount: Int
    ) {
        guard let defaults else {
            print("❌ [Widget] updateAll skipped — no shared defaults")
            return
        }
        
        defaults.set(paceChanged, forKey: "widget_paceChanged")
        defaults.set(paceDirection, forKey: "widget_paceDirection")
        defaults.set(checkInAvailable, forKey: "widget_checkInAvailable")
        defaults.set(checkInCompleted, forKey: "widget_checkInCompleted")
        defaults.set(streakCount, forKey: "widget_streakCount")
        defaults.set(habitsTotal, forKey: "widget_habitsTotal")
        defaults.set(habitsCompleted, forKey: "widget_habitsCompleted")
        defaults.set(habitNames, forKey: "widget_habitNames")
        defaults.set(habitStates, forKey: "widget_habitStates")
        defaults.set(workoutName, forKey: "widget_workoutName")
        defaults.set(workoutExerciseCount, forKey: "widget_exerciseCount")
        defaults.set(workoutType, forKey: "widget_workoutType")
        defaults.set(isRestDay, forKey: "widget_isRestDay")
        defaults.set(workoutCompleted, forKey: "widget_workoutCompleted")
        defaults.set(dayCount, forKey: "widget_dayCount")

        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ [Widget] updateAll — habits: \(habitsCompleted)/\(habitsTotal), streak: \(streakCount), workout: \(workoutName), pace changed: \(paceChanged)")
    }

    // MARK: - Partial Updates

    /// Call after a habit is toggled or habits list changes.
    func updateHabits(completed: Int, total: Int, names: [String], states: [Bool], streak: Int) {
        guard let defaults else {
            print("❌ [Widget] updateHabits skipped — no shared defaults")
            return
        }
        
        defaults.set(completed, forKey: "widget_habitsCompleted")
        defaults.set(total, forKey: "widget_habitsTotal")
        defaults.set(names, forKey: "widget_habitNames")
        defaults.set(states, forKey: "widget_habitStates")
        defaults.set(streak, forKey: "widget_streakCount")
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ [Widget] updateHabits — \(completed)/\(total), streak: \(streak), names: \(names)")
    }

    /// Call after a workout is marked complete.
    func updateWorkoutCompleted() {
        guard let defaults else { return }
        defaults.set(true, forKey: "widget_workoutCompleted")
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Widget] updateWorkoutCompleted")
    }

    /// Call after Pace score recalculation detects a change.
    func updatePaceChanged(direction: String) {
        guard let defaults else { return }
        defaults.set(true, forKey: "widget_paceChanged")
        defaults.set(direction, forKey: "widget_paceDirection")
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Widget] updatePaceChanged — \(direction)")
    }

    /// Call when the user views the Today tab — clears the "Pace changed" flag.
    func clearPaceChanged(currentPaceValue: Double) {
        guard let defaults else { return }
        defaults.set(false, forKey: "widget_paceChanged")
        defaults.set(currentPaceValue, forKey: "widget_lastSeenPaceValue")
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Widget] clearPaceChanged — stored pace: \(currentPaceValue)")
    }

    /// Call when weekly check-in availability changes.
    func updateCheckIn(available: Bool, completed: Bool) {
        guard let defaults else { return }
        defaults.set(available, forKey: "widget_checkInAvailable")
        defaults.set(completed, forKey: "widget_checkInCompleted")
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Widget] updateCheckIn — available: \(available), completed: \(completed)")
    }
}