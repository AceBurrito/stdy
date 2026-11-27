import Foundation
import SwiftData

// MARK: - Routine Exercise
// An exercise entry within a WorkoutRoutine.
// Stores the exercise reference, target sets/reps, and sort position.
// The exercise is identified by name (matches ExerciseLibrary display names).

@Model
class RoutineExercise {
    var id: UUID = UUID()
    var exerciseID: String = ""       // ExerciseLibrary ID (kebab-case)
    var exerciseName: String = ""     // Display name from ExerciseLibrary
    var sets: Int = 3
    var reps: String = "10"           // "8-10", "12", "AMRAP", etc.
    var notes: String?
    var sortOrder: Int = 0
    var isBodyweight: Bool = false

    var routine: WorkoutRoutine?

    init(exerciseID: String, exerciseName: String, sets: Int = 3, reps: String = "10", sortOrder: Int = 0, isBodyweight: Bool = false) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.sortOrder = sortOrder
        self.isBodyweight = isBodyweight
    }

    // MARK: - Parsed Reps (mirrors PlannedExercise logic)

    var repsMin: Int? {
        guard !reps.isEmpty else { return nil }
        if reps.contains("-") {
            let parts = reps.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let min = Int(parts[0]) { return min }
        }
        if let val = Int(reps) { return val }
        return 10 // fallback for "AMRAP" etc.
    }

    var repsMax: Int? {
        guard !reps.isEmpty else { return nil }
        if reps.contains("-") {
            let parts = reps.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let max = Int(parts[1]) { return max }
        }
        if let val = Int(reps) { return val }
        return 15
    }

    var repsForLogging: Int {
        repsMin ?? 10
    }
}