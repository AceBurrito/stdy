// SharedWorkoutState.swift
//
// Lightweight workout state shared between the main app and widget extension
// via App Group UserDefaults. This is what the lock screen buttons read/write.
//
// ⚠️ Target Membership: BOTH atlas AND WorkoutActivityExtension

import Foundation

struct SharedWorkoutState: Codable {
    var workoutName: String
    var exercises: [SharedExercise]
    var currentExerciseIndex: Int
    var workoutStartTime: Date?
    
    struct SharedExercise: Codable {
        let name: String
        let exerciseId: String?
        var sets: [SharedSet]
        let isBodyweight: Bool
        let isTimed: Bool
        let weightIncrement: Double
        
        /// Index of the next set to complete (0-based)
        var nextSetIndex: Int {
            sets.firstIndex(where: { !$0.isCompleted }) ?? sets.count
        }
        
        var allSetsComplete: Bool {
            sets.allSatisfy { $0.isCompleted }
        }
    }
    
    struct SharedSet: Codable {
        var weight: Double?
        var reps: Int
        var isCompleted: Bool
        var isBodyweight: Bool
    }
    
    // MARK: - Current Exercise Helpers
    
    var currentExercise: SharedExercise? {
        guard currentExerciseIndex >= 0 && currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }
    
    var totalCompletedExercises: Int {
        exercises.filter { $0.allSetsComplete }.count
    }
}

// MARK: - Shared Storage

final class SharedWorkoutStore {
    
    private static let stateKey = "atlas_shared_workout_state"
    private static let defaults = UserDefaults(suiteName: "group.com.atlas.workout") ?? UserDefaults.standard
    
    static func save(_ state: SharedWorkoutState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }
    
    static func load() -> SharedWorkoutState? {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SharedWorkoutState.self, from: data) else {
            return nil
        }
        return state
    }
    
    static func clear() {
        defaults.removeObject(forKey: stateKey)
    }
}
