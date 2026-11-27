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
    /// Check if an exercise name matches a key compound lift (bench, squat, deadlift)
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

