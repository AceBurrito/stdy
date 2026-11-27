// WorkoutDraftManager.swift
// atlas (main app target ONLY)
//
// Persists workout-in-progress state so it survives app backgrounding.
// Uses shared App Group UserDefaults so the widget extension can also access it.

import Foundation

// MARK: - App Group Container

let sharedDefaults = UserDefaults(suiteName: "group.com.atlas.workout") ?? UserDefaults.standard

struct WorkoutDraft: Codable {
    let workoutName: String
    let exercises: [DraftExercise]
    let globalNotes: String
    let workoutStartTime: Date?
    let savedAt: Date
    
    struct DraftExercise: Codable {
        let name: String
        let exerciseId: String?
        let sets: [DraftSet]
        let lastPerformance: String
        let hasHistory: Bool
        let progressionSuggestion: String?
        let weightIncrement: Double
        let isBodyweight: Bool
        let isTimed: Bool
    }
    
    struct DraftSet: Codable {
        let plannedWeight: Double?
        let plannedReps: Int
        let actualWeight: Double?
        let actualReps: Int
        let isBodyweight: Bool
        let isTimed: Bool
        let isCompleted: Bool
        let rpe: Int?
    }
}

final class WorkoutDraftManager {
    
    private static let draftKey = "atlas_workout_draft"
    
    // MARK: - Save
    
    static func saveDraft(
        workoutName: String,
        exercises: [LoggingExercise],
        globalNotes: String,
        workoutStartTime: Date?
    ) {
        let draftExercises = exercises.map { exercise in
            WorkoutDraft.DraftExercise(
                name: exercise.name,
                exerciseId: exercise.exerciseId,
                sets: exercise.sets.map { set in
                    WorkoutDraft.DraftSet(
                        plannedWeight: set.plannedWeight,
                        plannedReps: set.plannedReps,
                        actualWeight: set.actualWeight,
                        actualReps: set.actualReps,
                        isBodyweight: set.isBodyweight,
                        isTimed: set.isTimed,
                        isCompleted: set.isCompleted,
                        rpe: set.rpe
                    )
                },
                lastPerformance: exercise.lastPerformance,
                hasHistory: exercise.hasHistory,
                progressionSuggestion: exercise.progressionSuggestion,
                weightIncrement: exercise.weightIncrement,
                isBodyweight: exercise.isBodyweight,
                isTimed: exercise.isTimed
            )
        }
        
        let draft = WorkoutDraft(
            workoutName: workoutName,
            exercises: draftExercises,
            globalNotes: globalNotes,
            workoutStartTime: workoutStartTime,
            savedAt: Date()
        )
        
        if let data = try? JSONEncoder().encode(draft) {
            sharedDefaults.set(data, forKey: draftKey)
            print("✅ Workout draft saved (\(exercises.count) exercises)")
        }
    }
    
    // MARK: - Load
    
    static func loadDraft() -> WorkoutDraft? {
        guard let data = sharedDefaults.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data) else {
            return nil
        }
        
        let hoursSinceSave = Date().timeIntervalSince(draft.savedAt) / 3600
        if hoursSinceSave > 4 {
            clearDraft()
            return nil
        }
        
        return draft
    }
    
    // MARK: - Clear
    
    static func clearDraft() {
        sharedDefaults.removeObject(forKey: draftKey)
    }
    
    // MARK: - Check
    
    static var hasDraft: Bool {
        loadDraft() != nil
    }
    
    // MARK: - Restore to LoggingExercise array
    
    static func restoreExercises(from draft: WorkoutDraft) -> [LoggingExercise] {
        draft.exercises.map { draftExercise in
            LoggingExercise(
                name: draftExercise.name,
                exerciseId: draftExercise.exerciseId,
                sets: draftExercise.sets.map { draftSet in
                    LoggingSet(
                        plannedWeight: draftSet.plannedWeight,
                        plannedReps: draftSet.plannedReps,
                        actualWeight: draftSet.actualWeight,
                        actualReps: draftSet.actualReps,
                        isBodyweight: draftSet.isBodyweight,
                        isTimed: draftSet.isTimed,
                        isCompleted: draftSet.isCompleted,
                        rpe: draftSet.rpe
                    )
                },
                lastPerformance: draftExercise.lastPerformance,
                hasHistory: draftExercise.hasHistory,
                progressionSuggestion: draftExercise.progressionSuggestion,
                weightIncrement: draftExercise.weightIncrement,
                isBodyweight: draftExercise.isBodyweight,
                isTimed: draftExercise.isTimed
            )
        }
    }
}
