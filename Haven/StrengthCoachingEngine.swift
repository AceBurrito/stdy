import Foundation
import SwiftData

// MARK: - Strength Coaching Engine
// Generates deterministic, one-line coaching notes for workout history cards.
// Mirrors the cardio tab's zone coaching pattern — no AI, just smart logic.

struct StrengthCoachingEngine {
    
    // MARK: - Generate Coaching Note for a Session
    
    /// Generates a single coaching insight for a completed workout session.
    /// Returns nil if nothing notable happened (avoids noise).
    static func generateNote(
        for session: WorkoutSession,
        previousSession: WorkoutSession?,
        modelContext: ModelContext
    ) -> String? {
        let exercises = session.exercises
        guard !exercises.isEmpty else { return nil }
        
        // Classify each exercise's progression
        let progressions = exercises.map { exercise -> ExerciseProgressionResult in
            classifyProgression(exercise: exercise, modelContext: modelContext)
        }
        
        let improvedCount = progressions.filter { $0.type == .improved }.count
        let prCount = progressions.filter { $0.type == .pr }.count
        let totalCount = progressions.count
        
        // Priority 1: PR hit
        if prCount > 0 {
            let prExercise = progressions.first(where: { $0.type == .pr })?.exerciseName ?? "a lift"
            if prCount > 1 {
                return "\(prCount) new PRs. Big session."
            }
            return "New PR on \(prExercise). That's a milestone."
        }
        
        // Priority 2: All exercises improved
        if improvedCount == totalCount && totalCount >= 3 {
            return "Every lift progressed. Strong session."
        }
        
        // Priority 3: Majority improved
        if improvedCount > totalCount / 2 && totalCount >= 3 {
            return "\(improvedCount) of \(totalCount) exercises improved. Good momentum."
        }
        
        // Priority 4: Volume up significantly vs same-named workout
        if let prev = previousSession {
            let currentVol = sessionVolume(session)
            let prevVol = sessionVolume(prev)
            if prevVol > 0 && currentVol > prevVol * 1.1 {
                let pct = Int(((currentVol - prevVol) / prevVol) * 100)
                return "Volume up \(pct)% from last time. Progressive overload in action."
            }
        }
        
        // Priority 5: Half improved
        if improvedCount > 0 && totalCount >= 2 {
            return "\(improvedCount) of \(totalCount) exercises improved. Solid work."
        }
        
        // Priority 6: Maintenance (nothing improved but nothing regressed)
        let regressedCount = progressions.filter { $0.type == .regressed }.count
        if regressedCount == 0 && totalCount >= 3 {
            return "Maintenance session. Add a rep per set next time."
        }
        
        // Priority 7: First session ever
        let firstTimeCount = progressions.filter { $0.type == .firstTime }.count
        if firstTimeCount == totalCount {
            return "Baseline logged. We'll track progression from here."
        }
        
        // Priority 8: First session for a new workout
        if firstTimeCount > totalCount / 2 {
            return "New exercises added. Baselines set for \(firstTimeCount) lifts."
        }
        
        return nil // Nothing notable — no noise
    }
    
    // MARK: - Classify Individual Exercise Progression
    
    private static func classifyProgression(
        exercise: Exercise,
        modelContext: ModelContext
    ) -> ExerciseProgressionResult {
        // Get previous instance of this exercise
        guard let session = exercise.workoutSession else {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .firstTime)
        }
        
        let previous = WorkoutHistoryService.getLastWorkout(
            for: exercise.name,
            modelContext: modelContext,
            beforeDate: session.date
        )
        
        guard let prev = previous else {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .firstTime)
        }
        
        let currentE1RM = EstimatedMaxCalculator.bestE1RM(from: exercise)
        let prevE1RM = EstimatedMaxCalculator.bestE1RM(from: prev)
        
        guard let curr = currentE1RM, let prevMax = prevE1RM else {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .stable)
        }
        
        let change = (curr - prevMax) / prevMax
        
        // Check if this is an all-time PR
        let allTimeE1RM = allTimeBestE1RM(exerciseName: exercise.name, excluding: session.date, modelContext: modelContext)
        if curr > (allTimeE1RM ?? 0) && allTimeE1RM != nil {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .pr)
        }
        
        if change > 0.02 {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .improved)
        } else if change < -0.05 {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .regressed)
        } else {
            return ExerciseProgressionResult(exerciseName: exercise.name, type: .stable)
        }
    }
    
    // MARK: - All-Time Best e1RM (excluding a specific date)
    
    private static func allTimeBestE1RM(
        exerciseName: String,
        excluding date: Date,
        modelContext: ModelContext
    ) -> Double? {
        let history = WorkoutHistoryService.getExerciseHistory(
            for: exerciseName,
            modelContext: modelContext,
            limit: 100
        )
        
        return history
            .filter { $0.workoutSession?.date != date }
            .compactMap { EstimatedMaxCalculator.bestE1RM(from: $0) }
            .max()
    }
    
    // MARK: - Session Volume Helper
    
    private static func sessionVolume(_ session: WorkoutSession) -> Double {
        if let stored = session.totalVolume, stored > 0 { return stored }
        return session.exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
        }
    }
}

// MARK: - Supporting Types

struct ExerciseProgressionResult {
    let exerciseName: String
    let type: ProgressionClassification
    
    enum ProgressionClassification {
        case pr          // All-time best e1RM
        case improved    // e1RM up > 2%
        case stable      // e1RM within ±2-5%
        case regressed   // e1RM down > 5%
        case firstTime   // No previous data
    }
}