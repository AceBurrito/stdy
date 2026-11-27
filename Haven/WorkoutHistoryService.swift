import Foundation
import SwiftData

class WorkoutHistoryService {
    
    // MARK: - Get Last Workout for Exercise
    
    static func getLastWorkout(
        for exerciseName: String,
        modelContext: ModelContext,
        beforeDate: Date = Date()
    ) -> Exercise? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else { return nil }
        
        let normalized = exerciseName.lowercased()
        
        for session in sessions where session.date < beforeDate {
            for exercise in session.exercises {
                if exercise.name.lowercased() == normalized {
                    return exercise
                }
            }
        }
        return nil
    }
    
    // MARK: - Get Exercise History
    
    static func getExerciseHistory(
        for exerciseName: String,
        modelContext: ModelContext,
        limit: Int = 10
    ) -> [Exercise] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else { return [] }
        
        let normalized = exerciseName.lowercased()
        var results: [Exercise] = []
        
        for session in sessions {
            for exercise in session.exercises {
                if exercise.name.lowercased() == normalized {
                    results.append(exercise)
                    if results.count >= limit { return results }
                }
            }
        }
        return results
    }
    
    // MARK: - Calculate Progress Between Two Sessions
    
    static func calculateProgress(current: Exercise, previous: Exercise) -> ExerciseProgress {
        let currentVol = volume(of: current)
        let previousVol = volume(of: previous)
        let currentMax = maxWeight(of: current)
        let previousMax = maxWeight(of: previous)
        let currentReps = totalReps(of: current)
        let previousReps = totalReps(of: previous)
        
        return ExerciseProgress(
            volumeChange: currentVol - previousVol,
            weightIncrease: currentMax - previousMax,
            repsChange: currentReps - previousReps,
            improved: currentVol > previousVol || currentMax > previousMax
        )
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Smart Progression Suggestions
    //
    // This is the brain of workout logging. It analyzes
    // history and generates specific, coach-quality
    // suggestions for the next session.
    //
    // Progression ladder:
    // 1. Hit all target reps → increase weight
    // 2. Partial target reps → hold weight, chase reps
    // 3. Reps declining → check recovery, consider deload
    // 4. Stalled 3+ sessions → suggest variation or deload
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    static func suggestProgression(
        for exercise: Exercise,
        history: [Exercise]
    ) -> ProgressionSuggestion {
        
        // No history at all — first time
        guard !exercise.sets.isEmpty else {
            return ProgressionSuggestion(
                recommendation: "Start with a weight you can control for 8-10 reps",
                suggestedWeight: nil,
                suggestedReps: nil,
                type: .firstTime
            )
        }
        
        let workingSets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        // TODO: Filter out warmup sets once 1WorkoutSet has an isWarmup property
        guard !workingSets.isEmpty else {
            return ProgressionSuggestion(
                recommendation: "Start with a weight you can control for 8-10 reps",
                suggestedWeight: nil,
                suggestedReps: nil,
                type: .firstTime
            )
        }
        
        // Get exercise definition from library for smart increments
        let definition = ExerciseLibrary.find(name: exercise.name)
        let increment = definition?.weightIncrement ?? 5.0
        let defaultTarget = definition?.defaultReps ?? 10
        
        // Analyze the last session
        let primaryWeight = workingSets.first?.weight ?? 0
        let targetReps = workingSets.first?.reps ?? defaultTarget
        let repCounts = workingSets.map { $0.reps }
        let allHitTarget = workingSets.allSatisfy { $0.reps >= targetReps }
        let avgReps = Double(repCounts.reduce(0, +)) / Double(repCounts.count)
        let lastSetReps = workingSets.last?.reps ?? 0
        let repDropOff = targetReps - lastSetReps  // How much reps fell from target
        let setsAtTarget = workingSets.filter { $0.reps >= targetReps }.count
        
        // Analyze trend across multiple sessions
        let recentHistory = Array(history.prefix(5))
        let stallCount = countStalledSessions(current: exercise, history: recentHistory)
        let isRegressing = detectRegression(current: exercise, history: recentHistory)
        
        // ── Decision Tree ──
        
        // CASE 1: Regression — reps or weight declining
        if isRegressing && recentHistory.count >= 2 {
            let suggestion = buildRegressionSuggestion(
                exerciseName: exercise.name,
                weight: primaryWeight,
                history: recentHistory
            )
            return suggestion
        }
        
        // CASE 2: Stalled for 3+ sessions at same weight/reps
        if stallCount >= 3 {
            return buildStallSuggestion(
                exerciseName: exercise.name,
                weight: primaryWeight,
                targetReps: targetReps,
                increment: increment,
                stallCount: stallCount
            )
        }
        
        // CASE 3: Crushed it — all sets hit target reps
        if allHitTarget && workingSets.count >= 3 {
            let newWeight = primaryWeight + increment
            let repStr = formatReps(repCounts)
            
            return ProgressionSuggestion(
                recommendation: "Hit \(repStr) last time — bump to \(formatWeight(newWeight))",
                suggestedWeight: newWeight,
                suggestedReps: targetReps,
                type: .increaseWeight
            )
        }
        
        // CASE 4: Almost there — most sets hit target, slight drop on last set(s)
        if setsAtTarget >= workingSets.count - 1 && repDropOff <= 2 {
            return ProgressionSuggestion(
                recommendation: "Close — went \(formatReps(repCounts)) at \(formatWeight(primaryWeight)). Chase \(targetReps) across all sets",
                suggestedWeight: primaryWeight,
                suggestedReps: targetReps,
                type: .holdWeight
            )
        }
        
        // CASE 5: Moderate drop-off — hold weight, build endurance
        if avgReps >= Double(targetReps) * 0.75 {
            return ProgressionSuggestion(
                recommendation: "Stay at \(formatWeight(primaryWeight)), aim for \(targetReps) on all \(workingSets.count) sets",
                suggestedWeight: primaryWeight,
                suggestedReps: targetReps,
                type: .holdWeight
            )
        }
        
        // CASE 6: Significant drop-off — weight might be too heavy
        let reducedWeight = primaryWeight - increment
        return ProgressionSuggestion(
            recommendation: "Reps dropped to \(formatReps(repCounts)) — try \(formatWeight(max(reducedWeight, 0))) and build back up",
            suggestedWeight: max(reducedWeight, 0),
            suggestedReps: targetReps,
            type: .reduceWeight
        )
    }
    
    // MARK: - Stall Detection
    
    /// Counts consecutive sessions where weight AND top-set reps atlas't changed
    private static func countStalledSessions(current: Exercise, history: [Exercise]) -> Int {
        let currentWeight = current.sets.first?.weight ?? 0
        let currentTopReps = current.sets.map { $0.reps }.max() ?? 0
        
        var stallCount = 0
        for past in history {
            let pastWeight = past.sets.first?.weight ?? 0
            let pastTopReps = past.sets.map { $0.reps }.max() ?? 0
            
            // Same weight, same or fewer reps = stalled
            if abs(pastWeight - currentWeight) < 1.0 && pastTopReps <= currentTopReps {
                stallCount += 1
            } else {
                break  // Streak broken
            }
        }
        return stallCount
    }
    
    // MARK: - Regression Detection
    
    /// Returns true if performance is trending downward over recent sessions
    private static func detectRegression(current: Exercise, history: [Exercise]) -> Bool {
        guard history.count >= 2 else { return false }
        
        let currentVol = volume(of: current)
        let prevVol = volume(of: history[0])
        let prev2Vol = history.count >= 2 ? volume(of: history[1]) : prevVol
        
        // Volume declining for 2+ consecutive sessions
        return currentVol < prevVol && prevVol < prev2Vol
    }
    
    // MARK: - Build Specific Suggestions
    
    private static func buildRegressionSuggestion(
        exerciseName: String,
        weight: Double,
        history: [Exercise]
    ) -> ProgressionSuggestion {
        // Check how severe the regression is
        let currentVol = history.isEmpty ? 0 : volume(of: history[0])
        let peakVol = history.map { volume(of: $0) }.max() ?? currentVol
        let dropPercent = peakVol > 0 ? (1.0 - currentVol / peakVol) * 100 : 0
        
        if dropPercent > 20 {
            // Significant regression — suggest deload
            let deloadWeight = (weight * 0.85).rounded(to: 5)
            return ProgressionSuggestion(
                recommendation: "Volume down \(Int(dropPercent))% — deload to \(formatWeight(deloadWeight)) and rebuild",
                suggestedWeight: deloadWeight,
                suggestedReps: nil,
                type: .deload
            )
        } else {
            // Mild regression — probably recovery issue
            return ProgressionSuggestion(
                recommendation: "Performance dipping — hold at \(formatWeight(weight)) and check sleep/recovery",
                suggestedWeight: weight,
                suggestedReps: nil,
                type: .recoveryCheck
            )
        }
    }
    
    private static func buildStallSuggestion(
        exerciseName: String,
        weight: Double,
        targetReps: Int,
        increment: Double,
        stallCount: Int
    ) -> ProgressionSuggestion {
        if stallCount >= 5 {
            // Long stall — deload and rebuild
            let deloadWeight = (weight * 0.9).rounded(to: 5)
            return ProgressionSuggestion(
                recommendation: "\(stallCount) sessions at \(formatWeight(weight)) — deload to \(formatWeight(deloadWeight)), add reps, build back",
                suggestedWeight: deloadWeight,
                suggestedReps: targetReps + 2,
                type: .deload
            )
        } else {
            // Short stall — try a micro-progression or rep bump
            let microWeight = weight + (increment / 2)
            return ProgressionSuggestion(
                recommendation: "Stalled \(stallCount) sessions — try \(formatWeight(microWeight)) or add a rep per set",
                suggestedWeight: microWeight,
                suggestedReps: targetReps,
                type: .microProgression
            )
        }
    }
    
    // MARK: - Detect PRs
    
    static func detectPRs(for exercise: Exercise, modelContext: ModelContext) -> [PersonalRecord] {
        var newPRs: [PersonalRecord] = []
        
        guard let session = exercise.workoutSession, !exercise.sets.isEmpty else { return [] }
        
        let history = getExerciseHistory(for: exercise.name, modelContext: modelContext, limit: 50)
        
        // Current session stats
        let currentMaxWeight = exercise.sets.compactMap { $0.weight }.max() ?? 0
        let currentMaxReps = exercise.sets.map { $0.reps }.max() ?? 0
        let currentVolume = volume(of: exercise)
        
        // Best set: weight × reps (e1RM proxy)
        let currentBestSet = exercise.sets.map { set -> Double in
            let w = set.weight ?? 0
            return w * Double(set.reps)
        }.max() ?? 0
        
        // Historical bests (excluding current session)
        var bestWeight: Double = 0
        var bestReps: Int = 0
        var bestVolume: Double = 0
        var bestSet: Double = 0
        
        for past in history {
            guard past.workoutSession?.date != session.date else { continue }
            bestWeight = max(bestWeight, past.sets.compactMap { $0.weight }.max() ?? 0)
            bestReps = max(bestReps, past.sets.map { $0.reps }.max() ?? 0)
            bestVolume = max(bestVolume, volume(of: past))
            let pastBestSet = past.sets.map { ($0.weight ?? 0) * Double($0.reps) }.max() ?? 0
            bestSet = max(bestSet, pastBestSet)
        }
        
        // Weight PR
        if currentMaxWeight > 0 && currentMaxWeight > bestWeight {
            let pr = PersonalRecord(
                exerciseName: exercise.name,
                recordType: "weight",
                value: currentMaxWeight,
                date: session.date
            )
            pr.workoutSessionId = session.id
            pr.previousRecord = bestWeight > 0 ? bestWeight : nil
            newPRs.append(pr)
        }
        
        // Best Set PR (weight × reps — most meaningful for progressive overload)
        if currentBestSet > 0 && currentBestSet > bestSet {
            let pr = PersonalRecord(
                exerciseName: exercise.name,
                recordType: "bestSet",
                value: currentBestSet,
                date: session.date
            )
            pr.workoutSessionId = session.id
            pr.previousRecord = bestSet > 0 ? bestSet : nil
            newPRs.append(pr)
        }
        
        // Volume PR (total session volume for this exercise)
        if currentVolume > 0 && currentVolume > bestVolume {
            let pr = PersonalRecord(
                exerciseName: exercise.name,
                recordType: "volume",
                value: currentVolume,
                date: session.date
            )
            pr.workoutSessionId = session.id
            pr.previousRecord = bestVolume > 0 ? bestVolume : nil
            newPRs.append(pr)
        }
        
        // Save PRs
        for pr in newPRs {
            modelContext.insert(pr)
        }
        if !newPRs.isEmpty {
            try? modelContext.save()
        }
        
        return newPRs
    }
    
    // MARK: - Find Historical PRs
    
    static func findPRs(for exerciseName: String, modelContext: ModelContext) -> ExercisePRs {
        let history = getExerciseHistory(for: exerciseName, modelContext: modelContext, limit: 50)
        
        var maxWeight: Double = 0, maxWeightDate: Date?
        var maxVolume: Double = 0, maxVolumeDate: Date?
        var maxReps: Int = 0, maxRepsDate: Date?
        var maxBestSet: Double = 0, maxBestSetDate: Date?
        
        for exercise in history {
            let date = exercise.workoutSession?.date
            let w = exercise.sets.compactMap { $0.weight }.max() ?? 0
            let v = volume(of: exercise)
            let r = exercise.sets.map { $0.reps }.max() ?? 0
            let bs = exercise.sets.map { ($0.weight ?? 0) * Double($0.reps) }.max() ?? 0
            
            if w > maxWeight { maxWeight = w; maxWeightDate = date }
            if v > maxVolume { maxVolume = v; maxVolumeDate = date }
            if r > maxReps { maxReps = r; maxRepsDate = date }
            if bs > maxBestSet { maxBestSet = bs; maxBestSetDate = date }
        }
        
        return ExercisePRs(
            maxWeight: maxWeight > 0 ? maxWeight : nil,
            maxWeightDate: maxWeightDate,
            maxVolume: maxVolume > 0 ? maxVolume : nil,
            maxVolumeDate: maxVolumeDate,
            maxReps: maxReps > 0 ? maxReps : nil,
            maxRepsDate: maxRepsDate,
            maxBestSet: maxBestSet > 0 ? maxBestSet : nil,
            maxBestSetDate: maxBestSetDate
        )
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private static func volume(of exercise: Exercise) -> Double {
        exercise.sets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps) }
    }
    
    private static func maxWeight(of exercise: Exercise) -> Double {
        exercise.sets.compactMap { $0.weight }.max() ?? 0
    }
    
    private static func totalReps(of exercise: Exercise) -> Int {
        exercise.sets.reduce(0) { $0 + $1.reps }
    }
    
    /// Format weight for display: "185" or "182.5" (only show decimal if needed)
    static func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lbs"
        } else {
            return "\(weight) lbs"
        }
    }
    
    /// Format rep array for display: "10, 10, 8" or "10 across"
    static func formatReps(_ reps: [Int]) -> String {
        if Set(reps).count == 1, let rep = reps.first {
            return "\(rep) across"
        }
        return reps.map(String.init).joined(separator: ", ")
    }
    
    /// Format last performance for inline display: "185×10, 185×10, 185×8"
    static func formatLastPerformance(_ exercise: Exercise) -> String {
        let sets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        return sets.map { set in
            if set.isBodyweight {
                return "BW×\(set.reps)"
            } else if let weight = set.weight {
                return "\(Int(weight))×\(set.reps)"
            } else {
                return "\(set.reps) reps"
            }
        }.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

struct ExerciseProgress {
    let volumeChange: Double
    let weightIncrease: Double
    let repsChange: Int
    let improved: Bool
}

struct ProgressionSuggestion {
    let recommendation: String
    let suggestedWeight: Double?
    let suggestedReps: Int?
    let type: ProgressionType
    
    enum ProgressionType {
        case firstTime          // No history
        case increaseWeight     // Hit all targets, time to go up
        case holdWeight         // Close but not there yet
        case reduceWeight       // Weight too heavy
        case microProgression   // Stalled, try smaller jump
        case deload             // Significant stall or regression
        case recoveryCheck      // Performance dipping, likely external
    }
}

struct ExercisePRs {
    let maxWeight: Double?
    let maxWeightDate: Date?
    let maxVolume: Double?
    let maxVolumeDate: Date?
    let maxReps: Int?
    let maxRepsDate: Date?
    let maxBestSet: Double?
    let maxBestSetDate: Date?
}

// MARK: - Double Rounding Helper

extension Double {
    /// Round to nearest increment (e.g. round to nearest 5)
    func rounded(to increment: Double) -> Double {
        (self / increment).rounded() * increment
    }
}
