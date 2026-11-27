import Foundation
import SwiftData

// MARK: - Workout Routine
// A reusable workout template (e.g., "Full Body A", "Upper Body").
// Multiple PlannedWorkoutDay objects can reference the same routine.
// Editing the routine updates every day that references it.

@Model
class WorkoutRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var lastModifiedDate: Date = Date()
    var isFromTemplate: Bool = false
    var templateSourceID: String?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var _exercises: [RoutineExercise]?

    var exercises: [RoutineExercise] {
        get { _exercises ?? [] }
        set { _exercises = newValue }
    }

    /// Sorted exercises by sortOrder for display.
    var sortedExercises: [RoutineExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Which days reference this routine (inverse managed manually via query).
    /// We don't use a formal inverse here because PlannedWorkoutDay already has
    /// multiple optional parents (trainingProgram, workoutWeek). SwiftData/CloudKit
    /// handles this better with a manual lookup.

    // Relationships
    var userProfile: UserProfile?

    init(name: String, isFromTemplate: Bool = false, templateSourceID: String? = nil) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        self.isFromTemplate = isFromTemplate
        self.templateSourceID = templateSourceID
        self._exercises = []
    }

    // MARK: - Convenience

    /// Create a deep copy of this routine with a new name.
    /// Caller must insert the returned routine and its exercises into modelContext.
    func duplicate(newName: String) -> WorkoutRoutine {
        let copy = WorkoutRoutine(name: newName, isFromTemplate: false)
        copy.userProfile = self.userProfile
        // Exercises are created separately by the caller from sortedExercises
        return copy
    }
}