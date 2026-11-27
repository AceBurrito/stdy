import Foundation
import SwiftData

// MARK: - Estimated 1RM Calculator
// Uses the Epley formula: e1RM = weight × (1 + reps / 30)
// Most validated formula across multiple studies (LeSuer et al. 1997, Reynolds et al. 2006)
// Accurate within ~5% for reps ≤ 10, less reliable above 12 reps

struct EstimatedMaxCalculator {
    
    // MARK: - Single Set e1RM (Epley Formula)
    /// Calculate estimated 1-rep max from a single set
    /// - Parameters:
    ///   - weight: Weight lifted in lbs
    ///   - reps: Number of reps completed
    /// - Returns: Estimated 1RM in lbs, or nil if inputs invalid
    static func calculate1RM(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps > 0 else { return nil }
        
        // If they did a true 1RM, just return it
        if reps == 1 { return weight }
        
        // Epley formula: e1RM = weight × (1 + reps / 30)
        // Capped at 12 reps for reliability — beyond that, the estimate gets noisy
        let effectiveReps = min(reps, 12)
        let e1RM = weight * (1.0 + Double(effectiveReps) / 30.0)
        
        return round(e1RM * 10) / 10  // Round to 1 decimal
    }
    
    // MARK: - Best e1RM from Exercise Sets
    /// Find the highest estimated 1RM across all sets of an exercise
    static func bestE1RM(from exercise: Exercise) -> Double? {
        let estimates = exercise.sets.compactMap { set -> Double? in
            guard let weight = set.weight, weight > 0, set.reps > 0 else { return nil }
            // Skip bodyweight exercises — no meaningful e1RM
            if set.isBodyweight { return nil }
            return calculate1RM(weight: weight, reps: set.reps)
        }
        return estimates.max()
    }
    
    // MARK: - Best e1RM from Exercise History (Last N Days)
    /// Get the highest estimated 1RM for an exercise across recent workout history
    static func bestE1RM(
        exerciseName: String,
        modelContext: ModelContext,
        daysBack: Int = 30
    ) -> EstimatedMaxResult? {
        let history = WorkoutHistoryService.getExerciseHistory(
            for: exerciseName,
            modelContext: modelContext,
            limit: 50
        )
        
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        
        var bestEstimate: Double = 0
        var bestWeight: Double = 0
        var bestReps: Int = 0
        var bestDate: Date?
        
        for exercise in history {
            guard let sessionDate = exercise.workoutSession?.date,
                  sessionDate >= cutoff else { continue }
            
            for set in exercise.sets {
                guard let weight = set.weight, weight > 0, set.reps > 0,
                      !set.isBodyweight else { continue }
                
                if let e1rm = calculate1RM(weight: weight, reps: set.reps),
                   e1rm > bestEstimate {
                    bestEstimate = e1rm
                    bestWeight = weight
                    bestReps = set.reps
                    bestDate = sessionDate
                }
            }
        }
        
        guard bestEstimate > 0 else { return nil }
        
        return EstimatedMaxResult(
            exerciseName: exerciseName,
            estimatedMax: bestEstimate,
            basedOnWeight: bestWeight,
            basedOnReps: bestReps,
            date: bestDate ?? Date()
        )
    }
    
    // MARK: - e1RM Trend (for chart display)
    /// Get e1RM for each session of an exercise, oldest to newest
    static func e1RMTrend(
        exerciseName: String,
        modelContext: ModelContext,
        limit: Int = 20
    ) -> [EstimatedMaxDataPoint] {
        let history = WorkoutHistoryService.getExerciseHistory(
            for: exerciseName,
            modelContext: modelContext,
            limit: limit
        )
        
        return history.compactMap { exercise -> EstimatedMaxDataPoint? in
            guard let date = exercise.workoutSession?.date,
                  let e1rm = bestE1RM(from: exercise) else { return nil }
            
            return EstimatedMaxDataPoint(date: date, estimatedMax: e1rm)
        }.reversed()  // Oldest to newest for chart
    }
    
    // MARK: - Compound Lift Detection
    /// Check if an exercise name matches a key compound lift for Pace scoring
    static func compoundLiftCategory(for exerciseName: String) -> CompoundLiftType? {
        let name = exerciseName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Bench press variants
        if name.contains("bench press") || name.contains("bench") && !name.contains("incline") && !name.contains("decline") {
            // Flat bench only for 1RM estimation
            if name.contains("flat") || !name.contains("incline") && !name.contains("decline") {
                return .bench
            }
        }
        
        // Squat variants
        if name.contains("squat") {
            // Back squat and front squat count, not leg press
            if name.contains("back") || name.contains("front") || name == "squat" || name == "barbell squat" {
                return .squat
            }
        }
        
        // Deadlift variants
        if name.contains("deadlift") || name.contains("dead lift") {
            // Conventional and sumo count
            if !name.contains("romanian") && !name.contains("rdl") && !name.contains("stiff") {
                return .deadlift
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct EstimatedMaxResult {
    let exerciseName: String
    let estimatedMax: Double       // e1RM in lbs
    let basedOnWeight: Double      // The set weight used
    let basedOnReps: Int           // The set reps used
    let date: Date                 // When the set was performed
    
    var formattedMax: String {
        "\(Int(estimatedMax)) lbs"
    }
    
    var basisDescription: String {
        "\(Int(basedOnWeight)) × \(basedOnReps)"
    }
}

struct EstimatedMaxDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let estimatedMax: Double
}

enum CompoundLiftType: String, CaseIterable {
    case bench = "Bench Press"
    case squat = "Squat"
    case deadlift = "Deadlift"
}

// MARK: - Monthly Pace Strength Refresh Manager
// Automatically pulls workout data to update Pace strength component

class MonthlyPaceStrengthRefresh {
    
    /// Check if it's time for a monthly strength refresh (30+ days since last)
    static func shouldRefresh(profile: UserProfile) -> Bool {
        guard let lastAssessment = profile.lastStrengthAssessmentDate else {
            // Never assessed — check if they have workout data
            return true
        }
        
        let daysSince = Calendar.current.dateComponents(
            [.day], from: lastAssessment, to: Date()
        ).day ?? 0
        
        return daysSince >= 30
    }
    
    /// Auto-refresh strength data from workout logs
    /// Returns true if Pace was updated, false if no data available
    @discardableResult
    static func refreshFromWorkoutData(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> StrengthRefreshResult {
        
        print("💪 Monthly Strength Refresh: scanning workout history...")
        
        var updatedLifts: [CompoundLiftType: EstimatedMaxResult] = [:]
        
        // Scan all logged exercises for compound lifts
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else {
            print("   ❌ Could not fetch workout sessions")
            return StrengthRefreshResult(updated: false, lifts: [:])
        }
        
        // Look at last 30 days of workouts
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= cutoff }
        
        print("   📊 Found \(recentSessions.count) sessions in last 30 days")
        
        // Find best e1RM for each compound lift
        for session in recentSessions {
            for exercise in session.exercises {
                guard let liftType = EstimatedMaxCalculator.compoundLiftCategory(for: exercise.name),
                      let e1rm = EstimatedMaxCalculator.bestE1RM(from: exercise) else { continue }
                
                let result = EstimatedMaxResult(
                    exerciseName: exercise.name,
                    estimatedMax: e1rm,
                    basedOnWeight: exercise.sets.compactMap { $0.weight }.max() ?? 0,
                    basedOnReps: exercise.sets.map { $0.reps }.max() ?? 0,
                    date: session.date
                )
                
                // Keep the highest e1RM for each lift type
                if let existing = updatedLifts[liftType] {
                    if e1rm > existing.estimatedMax {
                        updatedLifts[liftType] = result
                    }
                } else {
                    updatedLifts[liftType] = result
                }
            }
        }
        
        // Update profile with new estimated maxes
        var anyUpdated = false
        
        if let bench = updatedLifts[.bench] {
            let oldValue = profile.benchPressMax
            profile.benchPressMax = bench.estimatedMax
            anyUpdated = true
            print("   🏋️ Bench: \(oldValue.map { "\(Int($0))" } ?? "nil") → \(Int(bench.estimatedMax)) lbs (from \(bench.basisDescription))")
        }
        
        if let squat = updatedLifts[.squat] {
            let oldValue = profile.squatMax
            profile.squatMax = squat.estimatedMax
            anyUpdated = true
            print("   🏋️ Squat: \(oldValue.map { "\(Int($0))" } ?? "nil") → \(Int(squat.estimatedMax)) lbs (from \(squat.basisDescription))")
        }
        
        if let deadlift = updatedLifts[.deadlift] {
            let oldValue = profile.deadliftMax
            profile.deadliftMax = deadlift.estimatedMax
            anyUpdated = true
            print("   🏋️ Deadlift: \(oldValue.map { "\(Int($0))" } ?? "nil") → \(Int(deadlift.estimatedMax)) lbs (from \(deadlift.basisDescription))")
        }
        
        if anyUpdated {
            // KEY: Set source to workoutDerived — full confidence, no discount
            profile.strengthDataSource = "workoutDerived"
            profile.lastStrengthAssessmentDate = Date()
            try? modelContext.save()
            print("   ✅ Strength data updated (source: workoutDerived), Pace will recalculate on next refresh")
        } else {
            print("   ⚠️ No compound lift data found in last 30 days")
        }
        
        return StrengthRefreshResult(
            updated: anyUpdated,
            lifts: updatedLifts
        )
    }
}

// MARK: - Refresh Result

struct StrengthRefreshResult {
    let updated: Bool
    let lifts: [CompoundLiftType: EstimatedMaxResult]
    
    var summary: String {
        guard updated else {
            return "No compound lift data found. Log bench press, squat, or deadlift workouts for automatic strength tracking."
        }
        
        let liftSummaries = lifts.map { "\($0.key.rawValue): \(Int($0.value.estimatedMax)) lbs" }
        return "Updated from workout logs: " + liftSummaries.joined(separator: ", ")
    }
}