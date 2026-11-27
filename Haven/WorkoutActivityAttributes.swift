// WorkoutActivityAttributes.swift
//
// Shared between atlas (main app) and WorkoutActivity (widget extension).
// ⚠️ Target Membership: BOTH atlas AND WorkoutActivityExtension

import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        // Current exercise info
        var exerciseName: String
        var currentSet: Int          // 1-indexed: the set the user is ABOUT to do
        var totalSets: Int
        
        // What to lift next (pre-filled from last set or plan)
        var nextWeight: Double?
        var nextReps: Int
        var isBodyweight: Bool
        
        // Rest timer
        var restTimerEnd: Date?      // nil = not resting
        var isResting: Bool
        
        // Workout overview
        var workoutName: String
        var totalExercises: Int
        var completedExercises: Int
        
        // Elapsed time
        var workoutStartTime: Date?
        
        // Workout finished
        var isWorkoutComplete: Bool = false
    }
    
    // Static context (set once when activity starts)
    var workoutStartTime: Date
}
