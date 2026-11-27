import Foundation

// MARK: - Exercise Alternatives
// Provides swap suggestions by looking up the same muscle group in ExerciseLibrary.
// No AI call, no network — fully offline.

struct ExerciseAlternatives {
    
    struct Alternative: Identifiable {
        let id: String
        let name: String
        let reason: String
        let equipment: String
        let isBodyweight: Bool
        let isTimed: Bool
        let defaultSets: Int
        let defaultReps: Int
        let weightIncrement: Double
        let definition: ExerciseDefinition
    }
    
    /// Find alternatives for an exercise by name.
    /// Returns exercises in the same muscle group, excluding the current one.
    /// Prioritizes: same category first (compound→compound, isolation→isolation),
    /// then different category, capped at 5 results.
    static func alternatives(for exerciseName: String) -> [Alternative] {
        guard let current = ExerciseLibrary.find(name: exerciseName) else {
            return []
        }
        return alternatives(for: current)
    }
    
    /// Find alternatives for an exercise by definition.
    static func alternatives(for current: ExerciseDefinition) -> [Alternative] {
        let sameGroup = ExerciseLibrary.exercises(for: current.muscleGroup)
            .filter { $0.id != current.id }
        
        // Sort: same category first, then different category
        let sorted = sameGroup.sorted { a, b in
            let aMatch = a.category == current.category
            let bMatch = b.category == current.category
            if aMatch != bMatch { return aMatch }
            // Within same priority, prefer same equipment type
            let aEquip = a.equipment == current.equipment
            let bEquip = b.equipment == current.equipment
            if aEquip != bEquip { return aEquip }
            return a.name < b.name
        }
        
        return Array(sorted.prefix(5)).map { def in
            Alternative(
                id: def.id,
                name: def.name,
                reason: reasonText(from: current, to: def),
                equipment: def.equipment.rawValue,
                isBodyweight: def.isBodyweight,
                isTimed: def.isTimed,
                defaultSets: def.defaultSets,
                defaultReps: def.defaultReps,
                weightIncrement: def.weightIncrement,
                definition: def
            )
        }
    }
    
    /// Check if alternatives exist for an exercise name
    static func hasAlternatives(for exerciseName: String) -> Bool {
        guard let current = ExerciseLibrary.find(name: exerciseName) else {
            return false
        }
        return ExerciseLibrary.exercises(for: current.muscleGroup).count > 1
    }
    
    // MARK: - Reason Text Generation
    
    private static func reasonText(from current: ExerciseDefinition, to alt: ExerciseDefinition) -> String {
        var reasons: [String] = []
        
        // Equipment difference
        if alt.equipment != current.equipment {
            if alt.isBodyweight {
                reasons.append("No equipment needed")
            } else {
                reasons.append(alt.equipment.rawValue)
            }
        }
        
        // Category difference
        if alt.category != current.category {
            reasons.append(alt.category == .compound ? "Compound movement" : "Isolation focus")
        }
        
        // Unilateral
        if alt.isUnilateral && !current.isUnilateral {
            reasons.append("Single-leg/arm variation")
        }
        
        // Same pattern, different tool
        if alt.category == current.category && alt.equipment != current.equipment {
            reasons.append("Same movement pattern")
        }
        
        if reasons.isEmpty {
            reasons.append("Similar muscle activation")
        }
        
        return reasons.prefix(2).joined(separator: " • ")
    }
}