// WorkoutIntents.swift
//
// App Intents that run from Live Activity lock screen buttons.
// These execute WITHOUT opening the app.
//
// ⚠️ Target Membership: BOTH atlas AND WorkoutActivityExtension

import AppIntents
import ActivityKit
import Foundation

// MARK: - Log Set Intent

struct LogSetIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Log Set"
    static var description: IntentDescription = "Logs the next set with the displayed weight and reps"
    
    func perform() async throws -> some IntentResult {
        guard var state = SharedWorkoutStore.load() else { return .result() }
        
        let exIndex = state.currentExerciseIndex
        guard exIndex >= 0 && exIndex < state.exercises.count else { return .result() }
        
        let nextSetIdx = state.exercises[exIndex].nextSetIndex
        
        // Don't log past the last set
        guard nextSetIdx < state.exercises[exIndex].sets.count else {
            if advanceExercise(&state) {
                SharedWorkoutStore.save(state)
                await updateActivity(state: state, restEnd: nil, workoutComplete: false)
            }
            return .result()
        }
        
        // Mark set as completed
        state.exercises[exIndex].sets[nextSetIdx].isCompleted = true
        
        let wasLastSet = state.exercises[exIndex].allSetsComplete
        
        // Check if entire workout is done
        let allExercisesDone = state.exercises.allSatisfy { $0.allSetsComplete }
        
        if allExercisesDone {
            SharedWorkoutStore.save(state)
            await updateActivity(state: state, restEnd: nil, workoutComplete: true)
            return .result()
        }
        
        // Rest timer: 90s default, skip if last set of this exercise
        let restEnd: Date? = wasLastSet ? nil : Date().addingTimeInterval(90)
        
        // If all sets done for this exercise, advance to next
        if wasLastSet {
            _ = advanceExercise(&state)
        }
        
        SharedWorkoutStore.save(state)
        await updateActivity(state: state, restEnd: restEnd, workoutComplete: false)
        
        return .result()
    }
    
    @discardableResult
    private func advanceExercise(_ state: inout SharedWorkoutState) -> Bool {
        for i in (state.currentExerciseIndex + 1)..<state.exercises.count {
            if !state.exercises[i].allSetsComplete {
                state.currentExerciseIndex = i
                return true
            }
        }
        return false
    }
    
    private func updateActivity(state: SharedWorkoutState, restEnd: Date?, workoutComplete: Bool) async {
        let exercise = state.currentExercise ?? state.exercises.last
        guard let exercise = exercise else { return }
        
        let nextSetIdx = exercise.nextSetIndex
        let nextSet = nextSetIdx < exercise.sets.count ? exercise.sets[nextSetIdx] : nil
        let lastCompleted = exercise.sets.last(where: { $0.isCompleted })
        
        // Count total sets across all exercises
        let totalSetsInWorkout = state.exercises.reduce(0) { $0 + $1.sets.count }
        
        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            currentSet: min(nextSetIdx + 1, exercise.sets.count),
            totalSets: exercise.sets.count,
            nextWeight: nextSet?.weight ?? lastCompleted?.weight,
            nextReps: nextSet?.reps ?? lastCompleted?.reps ?? 0,
            isBodyweight: exercise.isBodyweight,
            restTimerEnd: restEnd,
            isResting: restEnd != nil,
            workoutName: state.workoutName,
            totalExercises: state.exercises.count,
            completedExercises: state.totalCompletedExercises,
            workoutStartTime: state.workoutStartTime,
            isWorkoutComplete: workoutComplete
        )
        
        let content = ActivityContent(state: contentState, staleDate: restEnd)
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}

// MARK: - Skip Rest Intent

struct SkipRestIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Skip Rest"
    static var description: IntentDescription = "Skips the rest timer"
    
    func perform() async throws -> some IntentResult {
        guard let state = SharedWorkoutStore.load(),
              let exercise = state.currentExercise else { return .result() }
        
        let nextSetIdx = exercise.nextSetIndex
        let nextSet = nextSetIdx < exercise.sets.count ? exercise.sets[nextSetIdx] : nil
        let lastCompleted = exercise.sets.last(where: { $0.isCompleted })
        
        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            currentSet: min(nextSetIdx + 1, exercise.sets.count),
            totalSets: exercise.sets.count,
            nextWeight: nextSet?.weight ?? lastCompleted?.weight,
            nextReps: nextSet?.reps ?? lastCompleted?.reps ?? 0,
            isBodyweight: exercise.isBodyweight,
            restTimerEnd: nil,
            isResting: false,
            workoutName: state.workoutName,
            totalExercises: state.exercises.count,
            completedExercises: state.totalCompletedExercises,
            workoutStartTime: state.workoutStartTime
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.update(content)
        }
        
        return .result()
    }
}

// MARK: - Add Rest Time (+15s)

struct AddRestTimeIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Add Rest Time"
    static var description: IntentDescription = "Adds 15 seconds to the rest timer"
    
    func perform() async throws -> some IntentResult {
        guard let state = SharedWorkoutStore.load(),
              let exercise = state.currentExercise else { return .result() }
        
        let nextSetIdx = exercise.nextSetIndex
        let nextSet = nextSetIdx < exercise.sets.count ? exercise.sets[nextSetIdx] : nil
        let lastCompleted = exercise.sets.last(where: { $0.isCompleted })
        
        var newRestEnd: Date? = nil
        for activity in Activity<WorkoutActivityAttributes>.activities {
            if let currentEnd = activity.content.state.restTimerEnd {
                newRestEnd = currentEnd.addingTimeInterval(15)
            }
        }
        if newRestEnd == nil { newRestEnd = Date().addingTimeInterval(15) }
        
        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            currentSet: min(nextSetIdx + 1, exercise.sets.count),
            totalSets: exercise.sets.count,
            nextWeight: nextSet?.weight ?? lastCompleted?.weight,
            nextReps: nextSet?.reps ?? lastCompleted?.reps ?? 0,
            isBodyweight: exercise.isBodyweight,
            restTimerEnd: newRestEnd,
            isResting: true,
            workoutName: state.workoutName,
            totalExercises: state.exercises.count,
            completedExercises: state.totalCompletedExercises,
            workoutStartTime: state.workoutStartTime
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.update(content)
        }
        
        return .result()
    }
}

// MARK: - Subtract Rest Time (-15s)

struct SubtractRestTimeIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Subtract Rest Time"
    static var description: IntentDescription = "Removes 15 seconds from the rest timer"
    
    func perform() async throws -> some IntentResult {
        guard let state = SharedWorkoutStore.load(),
              let exercise = state.currentExercise else { return .result() }
        
        let nextSetIdx = exercise.nextSetIndex
        let nextSet = nextSetIdx < exercise.sets.count ? exercise.sets[nextSetIdx] : nil
        let lastCompleted = exercise.sets.last(where: { $0.isCompleted })
        
        var newRestEnd: Date? = nil
        for activity in Activity<WorkoutActivityAttributes>.activities {
            if let currentEnd = activity.content.state.restTimerEnd {
                let adjusted = currentEnd.addingTimeInterval(-15)
                newRestEnd = adjusted > Date() ? adjusted : nil
            }
        }
        
        let contentState = WorkoutActivityAttributes.ContentState(
            exerciseName: exercise.name,
            currentSet: min(nextSetIdx + 1, exercise.sets.count),
            totalSets: exercise.sets.count,
            nextWeight: nextSet?.weight ?? lastCompleted?.weight,
            nextReps: nextSet?.reps ?? lastCompleted?.reps ?? 0,
            isBodyweight: exercise.isBodyweight,
            restTimerEnd: newRestEnd,
            isResting: newRestEnd != nil,
            workoutName: state.workoutName,
            totalExercises: state.exercises.count,
            completedExercises: state.totalCompletedExercises,
            workoutStartTime: state.workoutStartTime
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.update(content)
        }
        
        return .result()
    }
}

// MARK: - Add Weight (+5 lbs)

struct AddWeightIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Add Weight"
    static var description: IntentDescription = "Increases weight by 5 lbs"
    
    func perform() async throws -> some IntentResult {
        guard var state = SharedWorkoutStore.load() else { return .result() }
        
        let exIndex = state.currentExerciseIndex
        guard exIndex >= 0 && exIndex < state.exercises.count else { return .result() }
        
        let nextSetIdx = state.exercises[exIndex].nextSetIndex
        guard nextSetIdx < state.exercises[exIndex].sets.count else { return .result() }
        
        let increment = state.exercises[exIndex].weightIncrement
        state.exercises[exIndex].sets[nextSetIdx].weight = (state.exercises[exIndex].sets[nextSetIdx].weight ?? 0) + increment
        
        SharedWorkoutStore.save(state)
        await refreshActivity(state: state)
        
        return .result()
    }
}

// MARK: - Subtract Weight (-5 lbs)

struct SubtractWeightIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Subtract Weight"
    static var description: IntentDescription = "Decreases weight by 5 lbs"
    
    func perform() async throws -> some IntentResult {
        guard var state = SharedWorkoutStore.load() else { return .result() }
        
        let exIndex = state.currentExerciseIndex
        guard exIndex >= 0 && exIndex < state.exercises.count else { return .result() }
        
        let nextSetIdx = state.exercises[exIndex].nextSetIndex
        guard nextSetIdx < state.exercises[exIndex].sets.count else { return .result() }
        
        let increment = state.exercises[exIndex].weightIncrement
        let current = state.exercises[exIndex].sets[nextSetIdx].weight ?? 0
        state.exercises[exIndex].sets[nextSetIdx].weight = max(0, current - increment)
        
        SharedWorkoutStore.save(state)
        await refreshActivity(state: state)
        
        return .result()
    }
}

// MARK: - Add Rep (+1)

struct AddRepIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Add Rep"
    static var description: IntentDescription = "Increases reps by 1"
    
    func perform() async throws -> some IntentResult {
        guard var state = SharedWorkoutStore.load() else { return .result() }
        
        let exIndex = state.currentExerciseIndex
        guard exIndex >= 0 && exIndex < state.exercises.count else { return .result() }
        
        let nextSetIdx = state.exercises[exIndex].nextSetIndex
        guard nextSetIdx < state.exercises[exIndex].sets.count else { return .result() }
        
        state.exercises[exIndex].sets[nextSetIdx].reps += 1
        
        SharedWorkoutStore.save(state)
        await refreshActivity(state: state)
        
        return .result()
    }
}

// MARK: - Subtract Rep (-1)

struct SubtractRepIntent: LiveActivityIntent {
    
    static var title: LocalizedStringResource = "Subtract Rep"
    static var description: IntentDescription = "Decreases reps by 1"
    
    func perform() async throws -> some IntentResult {
        guard var state = SharedWorkoutStore.load() else { return .result() }
        
        let exIndex = state.currentExerciseIndex
        guard exIndex >= 0 && exIndex < state.exercises.count else { return .result() }
        
        let nextSetIdx = state.exercises[exIndex].nextSetIndex
        guard nextSetIdx < state.exercises[exIndex].sets.count else { return .result() }
        
        state.exercises[exIndex].sets[nextSetIdx].reps = max(0, state.exercises[exIndex].sets[nextSetIdx].reps - 1)
        
        SharedWorkoutStore.save(state)
        await refreshActivity(state: state)
        
        return .result()
    }
}

// MARK: - Shared Helper

private func refreshActivity(state: SharedWorkoutState) async {
    guard let exercise = state.currentExercise else { return }
    
    let nextSetIdx = exercise.nextSetIndex
    let nextSet = nextSetIdx < exercise.sets.count ? exercise.sets[nextSetIdx] : nil
    let lastCompleted = exercise.sets.last(where: { $0.isCompleted })
    
    var currentRestEnd: Date? = nil
    var currentIsResting = false
    for activity in Activity<WorkoutActivityAttributes>.activities {
        currentRestEnd = activity.content.state.restTimerEnd
        currentIsResting = activity.content.state.isResting
    }
    
    let contentState = WorkoutActivityAttributes.ContentState(
        exerciseName: exercise.name,
        currentSet: min(nextSetIdx + 1, exercise.sets.count),
        totalSets: exercise.sets.count,
        nextWeight: nextSet?.weight ?? lastCompleted?.weight,
        nextReps: nextSet?.reps ?? lastCompleted?.reps ?? 0,
        isBodyweight: exercise.isBodyweight,
        restTimerEnd: currentRestEnd,
        isResting: currentIsResting,
        workoutName: state.workoutName,
        totalExercises: state.exercises.count,
        completedExercises: state.totalCompletedExercises,
        workoutStartTime: state.workoutStartTime
    )
    
    let content = ActivityContent(state: contentState, staleDate: nil)
    for activity in Activity<WorkoutActivityAttributes>.activities {
        await activity.update(content)
    }
}