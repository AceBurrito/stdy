import Foundation
import SwiftData

// MARK: - Strength Data Merger
// Single source of truth for combining self-reported and workout-derived
// strength data. Always picks the HIGHER e1RM for each lift.
//
// Why higher wins:
// - If user reports 225 bench but logged 185×8 (e1RM 234) → 234 is more accurate
// - If user reports 275 bench but only logged 185×8 → 275 stays until disproven
// - Workout-derived data is "full confidence" (no self-report discount)
// - Self-reported data is useful as a floor until real data arrives

struct StrengthDataMerger {
    
    // MARK: - Merge and Update Profile
    
    /// Scans workout history for compound lift data, merges with existing
    /// profile data (keeping the higher value), and updates the profile.
    /// Call this after saving a strength assessment or on monthly refresh.
    ///
    /// Returns a summary of what changed.
    @discardableResult
    static func mergeAndUpdate(
        profile: UserProfile,
        modelContext: ModelContext,
        daysBack: Int = 30
    ) -> MergeResult {
        
        print("💪 StrengthDataMerger: scanning last \(daysBack) days...")
        
        // Step 1: Get workout-derived e1RMs from recent sessions
        let workoutLifts = scanWorkoutHistory(modelContext: modelContext, daysBack: daysBack)
        
        // Step 2: Get current profile values (from self-report or previous scan)
        let currentBench = profile.benchPressMax
        let currentSquat = profile.squatMax
        let currentDeadlift = profile.deadliftMax
        
        // Step 3: Merge — keep the higher value for each lift
        var changes: [String] = []
        var anyWorkoutData = false
        
        // Bench Press
        if let workoutBench = workoutLifts[.bench] {
            anyWorkoutData = true
            let best = max(workoutBench.estimatedMax, currentBench ?? 0)
            if best != currentBench {
                profile.benchPressMax = best
                let source = best == workoutBench.estimatedMax ? "workout" : "self-report"
                changes.append("Bench: \(Int(best)) lbs (\(source))")
                print("   🏋️ Bench: \(currentBench.map { "\(Int($0))" } ?? "nil") → \(Int(best)) lbs (from \(source): \(workoutBench.basisDescription))")
            } else {
                print("   🏋️ Bench: unchanged at \(Int(best)) lbs")
            }
        }
        
        // Squat
        if let workoutSquat = workoutLifts[.squat] {
            anyWorkoutData = true
            let best = max(workoutSquat.estimatedMax, currentSquat ?? 0)
            if best != currentSquat {
                profile.squatMax = best
                let source = best == workoutSquat.estimatedMax ? "workout" : "self-report"
                changes.append("Squat: \(Int(best)) lbs (\(source))")
                print("   🏋️ Squat: \(currentSquat.map { "\(Int($0))" } ?? "nil") → \(Int(best)) lbs (from \(source): \(workoutSquat.basisDescription))")
            } else {
                print("   🏋️ Squat: unchanged at \(Int(best)) lbs")
            }
        }
        
        // Deadlift
        if let workoutDeadlift = workoutLifts[.deadlift] {
            anyWorkoutData = true
            let best = max(workoutDeadlift.estimatedMax, currentDeadlift ?? 0)
            if best != currentDeadlift {
                profile.deadliftMax = best
                let source = best == workoutDeadlift.estimatedMax ? "workout" : "self-report"
                changes.append("Deadlift: \(Int(best)) lbs (\(source))")
                print("   🏋️ Deadlift: \(currentDeadlift.map { "\(Int($0))" } ?? "nil") → \(Int(best)) lbs (from \(source): \(workoutDeadlift.basisDescription))")
            } else {
                print("   🏋️ Deadlift: unchanged at \(Int(best)) lbs")
            }
        }
        
        // Step 4: Update data source and timestamp
        if anyWorkoutData {
            // If we have workout data, upgrade confidence to workoutDerived
            profile.strengthDataSource = "workoutDerived"
            profile.lastStrengthAssessmentDate = Date()
            print("   ✅ Source upgraded to workoutDerived")
        } else if profile.strengthDataSource == nil {
            // No workout data and no previous source — check if we have self-reported
            let hasSelfReported = (currentBench ?? 0) > 0 || (currentSquat ?? 0) > 0 || (currentDeadlift ?? 0) > 0
            if hasSelfReported {
                profile.strengthDataSource = "selfReported"
            }
        }
        
        // Step 5: Save
        if !changes.isEmpty {
            try? modelContext.save()
            print("   ✅ Strength data merged: \(changes.joined(separator: ", "))")
        } else {
            print("   ℹ️ No changes after merge")
        }
        
        return MergeResult(
            changes: changes,
            hasWorkoutData: anyWorkoutData,
            workoutLifts: workoutLifts
        )
    }
    
    // MARK: - Scan Workout History for Compound Lifts
    
    /// Finds the best e1RM for bench, squat, and deadlift from recent workout sessions.
    static func scanWorkoutHistory(
        modelContext: ModelContext,
        daysBack: Int = 30
    ) -> [CompoundLiftType: EstimatedMaxResult] {
        
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else { return [:] }
        
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= cutoff }
        
        var bestByLift: [CompoundLiftType: EstimatedMaxResult] = [:]
        
        for session in recentSessions {
            for exercise in session.exercises {
                // Check if this exercise matches a compound lift category
                guard let liftType = EstimatedMaxCalculator.compoundLiftCategory(for: exercise.name) else { continue }
                guard let e1rm = EstimatedMaxCalculator.bestE1RM(from: exercise) else { continue }
                
                let result = EstimatedMaxResult(
                    exerciseName: exercise.name,
                    estimatedMax: e1rm,
                    basedOnWeight: exercise.sets.compactMap { $0.weight }.max() ?? 0,
                    basedOnReps: exercise.sets.map { $0.reps }.max() ?? 0,
                    date: session.date
                )
                
                if let existing = bestByLift[liftType] {
                    if e1rm > existing.estimatedMax {
                        bestByLift[liftType] = result
                    }
                } else {
                    bestByLift[liftType] = result
                }
            }
        }
        
        return bestByLift
    }
    
    // MARK: - Get Current Strength Summary (for display)
    
    /// Returns a display-friendly summary of current strength data and its sources.
    /// Useful for showing in the Strength Percentile card or assessment screen.
    static func currentStrengthSummary(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> StrengthSummary {
        let workoutLifts = scanWorkoutHistory(modelContext: modelContext, daysBack: 30)
        
        return StrengthSummary(
            benchMax: profile.benchPressMax,
            squatMax: profile.squatMax,
            deadliftMax: profile.deadliftMax,
            dataSource: profile.strengthDataSource ?? "none",
            lastAssessmentDate: profile.lastStrengthAssessmentDate,
            hasWorkoutDerivedBench: workoutLifts[.bench] != nil,
            hasWorkoutDerivedSquat: workoutLifts[.squat] != nil,
            hasWorkoutDerivedDeadlift: workoutLifts[.deadlift] != nil,
            workoutBenchE1RM: workoutLifts[.bench]?.estimatedMax,
            workoutSquatE1RM: workoutLifts[.squat]?.estimatedMax,
            workoutDeadliftE1RM: workoutLifts[.deadlift]?.estimatedMax
        )
    }
}

// MARK: - Supporting Types

struct MergeResult {
    let changes: [String]
    let hasWorkoutData: Bool
    let workoutLifts: [CompoundLiftType: EstimatedMaxResult]
    
    var hasChanges: Bool { !changes.isEmpty }
    
    var summary: String {
        if changes.isEmpty {
            return hasWorkoutData
                ? "Strength data confirmed from workout logs."
                : "No compound lift data found in recent workouts."
        }
        return "Updated: " + changes.joined(separator: ", ")
    }
}

struct StrengthSummary {
    let benchMax: Double?
    let squatMax: Double?
    let deadliftMax: Double?
    let dataSource: String
    let lastAssessmentDate: Date?
    
    let hasWorkoutDerivedBench: Bool
    let hasWorkoutDerivedSquat: Bool
    let hasWorkoutDerivedDeadlift: Bool
    
    let workoutBenchE1RM: Double?
    let workoutSquatE1RM: Double?
    let workoutDeadliftE1RM: Double?
    
    var hasAnyLiftData: Bool {
        (benchMax ?? 0) > 0 || (squatMax ?? 0) > 0 || (deadliftMax ?? 0) > 0
    }
    
    var hasAnyWorkoutData: Bool {
        hasWorkoutDerivedBench || hasWorkoutDerivedSquat || hasWorkoutDerivedDeadlift
    }
}