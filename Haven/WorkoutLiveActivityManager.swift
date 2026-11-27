// WorkoutLiveActivityManager.swift
// atlas (main app target ONLY)
//
// Controls the Live Activity lifecycle from WorkoutLogView.
// BUG-015 FIX: Ends ALL active workout activities (not just the tracked reference),
// preventing orphaned Live Activities on force-quit, crash, or missed end calls.

import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityManager {
    
    static let shared = WorkoutLiveActivityManager()
    
    private var currentActivity: Activity<WorkoutActivityAttributes>?
    
    private init() {}
    
    // MARK: - Start
    
    func startActivity(
        workoutName: String,
        exerciseName: String,
        totalSets: Int,
        totalExercises: Int,
        nextWeight: Double?,
        nextReps: Int,
        isBodyweight: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled")
            return
        }
        
        // Kill any existing activities first (prevents duplicates)
        endAllActivities()
        
        let now = Date()
        let attributes = WorkoutActivityAttributes(workoutStartTime: now)
        
        let initialState = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: 1,
            totalSets: totalSets,
            nextWeight: nextWeight,
            nextReps: nextReps,
            isBodyweight: isBodyweight,
            restTimerEnd: nil,
            isResting: false,
            workoutName: workoutName,
            totalExercises: totalExercises,
            completedExercises: 0,
            workoutStartTime: now
        )
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("✅ Live Activity started")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update (set completed)
    
    func updateSetCompleted(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        nextWeight: Double?,
        nextReps: Int,
        isBodyweight: Bool,
        restEndDate: Date?,
        workoutName: String,
        totalExercises: Int,
        completedExercises: Int,
        workoutStartTime: Date?
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: min(currentSet, totalSets),
            totalSets: totalSets,
            nextWeight: nextWeight,
            nextReps: nextReps,
            isBodyweight: isBodyweight,
            restTimerEnd: restEndDate,
            isResting: restEndDate != nil,
            workoutName: workoutName,
            totalExercises: totalExercises,
            completedExercises: completedExercises,
            workoutStartTime: workoutStartTime
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
            print("✅ Live Activity updated: \(exerciseName) set \(currentSet)")
        }
    }
    
    // MARK: - Update (rest dismissed)
    
    func updateRestDismissed(
        exerciseName: String,
        nextSet: Int,
        totalSets: Int,
        nextWeight: Double?,
        nextReps: Int,
        isBodyweight: Bool,
        workoutName: String,
        totalExercises: Int,
        completedExercises: Int,
        workoutStartTime: Date?
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: min(nextSet, totalSets),
            totalSets: totalSets,
            nextWeight: nextWeight,
            nextReps: nextReps,
            isBodyweight: isBodyweight,
            restTimerEnd: nil,
            isResting: false,
            workoutName: workoutName,
            totalExercises: totalExercises,
            completedExercises: completedExercises,
            workoutStartTime: workoutStartTime
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
            print("✅ Live Activity: rest cleared")
        }
    }
    
    // MARK: - End (Single tracked activity)
    
    /// Ends the currently tracked activity AND iterates over all active workout activities
    /// to catch any orphans from crashes, force-quits, or missed end calls.
    func endActivity() {
        endAllActivities()
    }
    
    // MARK: - End ALL Activities (BUG-015 Fix)
    
    /// Iterates over ALL active workout Live Activities and ends them immediately.
    /// This catches orphaned activities that lost their reference (crash, force-quit, etc).
    /// Calling this on an already-ended activity is safe — it no-ops.
    private func endAllActivities() {
        // End the tracked reference first
        if let activity = currentActivity {
            let finalState = activity.content.state
            let content = ActivityContent(state: finalState, staleDate: Date())
            Task {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
        
        // Kill ALL active workout activities (catches orphans)
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let finalState = activity.content.state
                let content = ActivityContent(state: finalState, staleDate: Date())
                await activity.end(content, dismissalPolicy: .immediate)
            }
            
            let remaining = Activity<WorkoutActivityAttributes>.activities.count
            if remaining == 0 {
                print("✅ Live Activity ended (all activities cleared)")
            } else {
                print("⚠️ Live Activity end attempted, \(remaining) still active")
            }
        }
    }
    
    // MARK: - Stale Activity Cleanup (call on app launch / foreground)
    
    /// Kills any Live Activities that have been running for more than 4 hours.
    /// Call this from scenePhase == .active or .task on the root view.
    /// Catches edge cases: app crash during workout, force-quit, or iOS killing the app.
    func cleanupStaleActivities() {
        Task {
            let staleThreshold: TimeInterval = 4 * 60 * 60  // 4 hours
            var cleanedCount = 0
            
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let startTime = activity.attributes.workoutStartTime
                if Date().timeIntervalSince(startTime) > staleThreshold {
                    let finalState = activity.content.state
                    let content = ActivityContent(state: finalState, staleDate: Date())
                    await activity.end(content, dismissalPolicy: .immediate)
                    cleanedCount += 1
                    print("🧹 Killed stale Live Activity running since \(startTime.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            
            if cleanedCount > 0 {
                print("🧹 Cleaned up \(cleanedCount) stale Live Activity(ies)")
            }
        }
    }
    
    // MARK: - Check
    
    var isActive: Bool {
        // Check both our tracked reference AND the system's active activities
        if currentActivity != nil { return true }
        return !Activity<WorkoutActivityAttributes>.activities.isEmpty
    }
}