import Foundation
import SwiftData

// MARK: - Plan Committer
// Converts a TrainingPlanTemplate (or custom plan) into SwiftData objects:
// TrainingProgram → PlannedWorkoutWeek → PlannedWorkoutDay → (references WorkoutRoutine)
//
// Routine system: Strength workouts are now backed by WorkoutRoutine objects.
// When committing a plan, we create shared routines and link days to them.
// Days that share the same workout name share the same routine.

struct PlanCommitter {

    // MARK: - Commit Template Plan

    /// Creates a full TrainingProgram from a template plan with assigned days.
    /// Creates WorkoutRoutine objects for each unique workout and links days to them.
    /// Deactivates any existing active program first.
    @discardableResult
    static func commitTemplatePlan(
        template: TrainingPlanTemplate,
        dayAssignments: [DayAssigner.DayAssignment],
        cardioDays: [CardioDayConfig] = [],
        userProfile: UserProfile,
        modelContext: ModelContext
    ) -> TrainingProgram {

        // Deactivate existing programs
        deactivateExistingPrograms(modelContext: modelContext)

        // Create program
        let program = TrainingProgram(
            programText: template.tagline,
            daysPerWeek: template.strengthDays,
            minutesPerSession: userProfile.trainingMinutesPerSession ?? 45
        )
        program.userProfile = userProfile
        program.isActive = true
        program.isEventPlan = false
        program.startDate = Date()
        program.splitType = template.splitType
        program.programSummary = template.name
        program.totalWeeks = 52 // Ongoing
        program.currentWeek = 1

        // New tracking fields
        program.planSource = "template"
        program.planTemplateID = template.id
        program.planCategory = template.category.rawValue

        modelContext.insert(program)

        // Create Week 1
        let week = PlannedWorkoutWeek(weekNumber: 1, phaseName: "Training")
        week.trainingProgram = program
        modelContext.insert(week)

        // Build WorkoutRoutine for each unique template workout
        var routinesByWorkoutID: [String: WorkoutRoutine] = [:]

        for templateWorkout in template.workouts {
            let routine = WorkoutRoutine(
                name: templateWorkout.name,
                isFromTemplate: true,
                templateSourceID: template.id
            )
            routine.userProfile = userProfile
            modelContext.insert(routine)

            for (exIndex, templateExercise) in templateWorkout.exercises.enumerated() {
                let resolvedName = ExerciseLibrary.find(id: templateExercise.exerciseID)?.name
                    ?? templateExercise.exerciseID
                let definition = ExerciseLibrary.find(id: templateExercise.exerciseID)

                let routineEx = RoutineExercise(
                    exerciseID: templateExercise.exerciseID,
                    exerciseName: resolvedName,
                    sets: templateExercise.sets,
                    reps: String(templateExercise.reps),
                    sortOrder: exIndex,
                    isBodyweight: definition?.isBodyweight ?? isBodyweightExercise(templateExercise.exerciseID)
                )
                routineEx.notes = templateExercise.notes
                routineEx.routine = routine
                modelContext.insert(routineEx)
            }

            routinesByWorkoutID[templateWorkout.id] = routine
        }

        // Create days from assignments
        for (index, assignment) in dayAssignments.enumerated() {
            if assignment.workoutType == "rest" {
                // Check if this rest day has cardio assigned
                if let cardioConfig = cardioDays.first(where: { $0.dayOfWeek == assignment.dayOfWeek }) {
                    let day = createCardioDay(
                        config: cardioConfig,
                        dayOfWeek: assignment.dayOfWeek,
                        orderIndex: index,
                        program: program,
                        week: week,
                        modelContext: modelContext
                    )
                    modelContext.insert(day)
                }
                continue
            }

            guard let templateWorkout = assignment.templateWorkout else { continue }

            let day = PlannedWorkoutDay(
                dayType: "strength",
                dayName: templateWorkout.name,
                dayOfWeek: assignment.dayOfWeek,
                orderIndex: index
            )
            day.trainingProgram = program
            day.workoutWeek = week

            // Link to shared routine
            if let routine = routinesByWorkoutID[templateWorkout.id] {
                day.workoutRoutineID = routine.id.uuidString
            }

            modelContext.insert(day)

            // Also create PlannedExercise copies on the day (backward compatibility).
            // The routine is the source of truth, but legacy code paths that read
            // day.exercises directly will still work during the transition.
            for (exIndex, templateExercise) in templateWorkout.exercises.enumerated() {
                let resolvedName = ExerciseLibrary.find(id: templateExercise.exerciseID)?.name
                    ?? templateExercise.exerciseID
                let definition = ExerciseLibrary.find(id: templateExercise.exerciseID)

                let planned = PlannedExercise(
                    name: resolvedName,
                    targetSets: templateExercise.sets,
                    targetReps: String(templateExercise.reps),
                    orderIndex: exIndex,
                    isBodyweight: definition?.isBodyweight ?? isBodyweightExercise(templateExercise.exerciseID)
                )
                planned.notes = templateExercise.notes
                planned.workoutDay = day
                modelContext.insert(planned)
            }
        }

        // Add any cardio days that are on training days too
        for cardioConfig in cardioDays {
            let alreadyAdded = dayAssignments.contains { assignment in
                assignment.dayOfWeek == cardioConfig.dayOfWeek && assignment.workoutType != "rest"
            }
            if !alreadyAdded {
                let existsAsCardio = cardioDays.contains { $0.dayOfWeek == cardioConfig.dayOfWeek }
                if existsAsCardio {
                    // Already handled in the rest day loop above
                }
            }
        }

        do {
            try modelContext.save()
            print("✅ Plan committed: \(template.name) with \(template.strengthDays) training days + \(routinesByWorkoutID.count) routines")
        } catch {
            print("❌ Failed to commit plan: \(error)")
        }

        return program
    }

    // MARK: - Commit Custom Plan

    /// Creates a TrainingProgram from Build Your Own selections.
    /// Now expects routines to already exist (created during the builder flow).
    @discardableResult
    static func commitCustomPlan(
        customDays: [CustomDayConfig],
        userProfile: UserProfile,
        modelContext: ModelContext
    ) -> TrainingProgram {

        deactivateExistingPrograms(modelContext: modelContext)

        let strengthDayCount = customDays.filter { $0.type == .strength }.count

        let program = TrainingProgram(
            programText: "Custom Plan",
            daysPerWeek: strengthDayCount,
            minutesPerSession: userProfile.trainingMinutesPerSession ?? 45
        )
        program.userProfile = userProfile
        program.isActive = true
        program.isEventPlan = false
        program.startDate = Date()
        program.splitType = "Custom"
        program.programSummary = "Custom Plan"
        program.totalWeeks = 52
        program.currentWeek = 1

        // New tracking fields
        program.planSource = "custom"
        program.planTemplateID = nil
        program.planCategory = nil

        modelContext.insert(program)

        // Create Week 1
        let week = PlannedWorkoutWeek(weekNumber: 1, phaseName: "Training")
        week.trainingProgram = program
        modelContext.insert(week)

        // Create days
        for (index, dayConfig) in customDays.enumerated() {
            switch dayConfig.type {
            case .strength:
                let day = PlannedWorkoutDay(
                    dayType: "strength",
                    dayName: dayConfig.name,
                    dayOfWeek: dayConfig.dayOfWeek,
                    orderIndex: index
                )
                day.trainingProgram = program
                day.workoutWeek = week
                
                // Link to routine if provided
                if let routineID = dayConfig.routineID {
                    day.workoutRoutineID = routineID
                }
                
                // FEAT-003: Attach secondary cardio if configured
                if dayConfig.hasSecondaryCardio {
                    day.hasSecondaryCardio = true
                    day.secondaryCardioDuration = dayConfig.secondaryCardioDuration
                    day.secondaryCardioZone = dayConfig.secondaryCardioZone
                }
                
                modelContext.insert(day)

                // Create PlannedExercise copies for backward compatibility
                for (exIndex, customEx) in dayConfig.exercises.enumerated() {
                    let planned = PlannedExercise(
                        name: customEx.name,
                        targetSets: customEx.sets,
                        targetReps: customEx.reps,
                        orderIndex: exIndex,
                        isBodyweight: isBodyweightExercise(customEx.name)
                    )
                    planned.notes = customEx.notes
                    planned.workoutDay = day
                    modelContext.insert(planned)
                }

            case .cardio:
                let day = PlannedWorkoutDay(
                    dayType: "cardio",
                    dayName: dayConfig.name,
                    dayOfWeek: dayConfig.dayOfWeek,
                    orderIndex: index
                )
                day.cardioType = dayConfig.cardioType
                day.cardioDuration = dayConfig.cardioDurationMinutes
                day.trainingProgram = program
                day.workoutWeek = week
                modelContext.insert(day)

            case .rest:
                break // Skip rest days
            }
        }

        do {
            try modelContext.save()
            print("✅ Custom plan committed with \(strengthDayCount) strength days")
        } catch {
            print("❌ Failed to commit custom plan: \(error)")
        }

        return program
    }

    // MARK: - Cardio Day Config

    struct CardioDayConfig {
        let dayOfWeek: Int
        let cardioType: String     // "Zone 2", "VO2 Max Intervals", etc.
        let durationMinutes: Int
    }

    // MARK: - Custom Day Config

    struct CustomDayConfig {
        let dayOfWeek: Int
        let name: String
        let type: DayType
        let exercises: [CustomExercise]
        let cardioType: String?
        let cardioDurationMinutes: Int?
        // Routine reference (new)
        var routineID: String? = nil
        // FEAT-003: Secondary cardio on strength days
        var hasSecondaryCardio: Bool = false
        var secondaryCardioZone: String? = nil
        var secondaryCardioDuration: Int? = nil

        enum DayType {
            case strength
            case cardio
            case rest
        }
    }

    struct CustomExercise {
        let name: String
        let sets: Int
        let reps: String   // "8-10", "12", "AMRAP"
        let notes: String?
    }

    // MARK: - Helpers

    private static func deactivateExistingPrograms(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true && $0.isEventPlan == false }
        )

        if let existing = try? modelContext.fetch(descriptor) {
            for program in existing {
                program.isActive = false
                print("   Deactivated: \(program.programSummary ?? "unnamed") ")
            }
        }
    }

    private static func createCardioDay(
        config: CardioDayConfig,
        dayOfWeek: Int,
        orderIndex: Int,
        program: TrainingProgram,
        week: PlannedWorkoutWeek,
        modelContext: ModelContext
    ) -> PlannedWorkoutDay {
        let day = PlannedWorkoutDay(
            dayType: "cardio",
            dayName: config.cardioType,
            dayOfWeek: dayOfWeek,
            orderIndex: orderIndex
        )
        day.cardioType = config.cardioType
        day.cardioDuration = config.durationMinutes
        day.trainingProgram = program
        day.workoutWeek = week
        return day
    }

    static func isBodyweightExercise(_ name: String) -> Bool {
        let bodyweight = [
            "push-up", "pushup", "pull-up", "pullup", "chin-up", "chinup",
            "dip", "plank", "burpee", "mountain climber", "lunge",
            "bodyweight squat", "glute bridge", "superman", "bird dog",
            "dead bug", "leg raise", "hanging leg raise", "pike push-up",
            "inverted row", "body row", "sit-up", "crunch"
        ]
        let lower = name.lowercased()
        return bodyweight.contains { lower.contains($0) }
    }
    
    // MARK: - Data Migration (fix previously saved raw exercise IDs)
    
    /// Call on app launch to fix any workouts saved with raw exerciseID strings as names.
    /// Safe because no real display name matches the kebab-case-id format.
    static func migrateRawExerciseIDs(modelContext: ModelContext) {
        // Fix PlannedExercise entries (active plan)
        let plannedDescriptor = FetchDescriptor<PlannedExercise>()
        if let plannedExercises = try? modelContext.fetch(plannedDescriptor) {
            var fixedCount = 0
            for exercise in plannedExercises {
                if let resolved = ExerciseLibrary.find(id: exercise.name) {
                    exercise.name = resolved.name
                    fixedCount += 1
                }
            }
            if fixedCount > 0 {
                print("🔧 [Migration] Fixed \(fixedCount) PlannedExercise names from raw IDs")
            }
        }
        
        // Fix Exercise entries (logged workout history)
        let historyDescriptor = FetchDescriptor<Exercise>()
        if let loggedExercises = try? modelContext.fetch(historyDescriptor) {
            var fixedCount = 0
            for exercise in loggedExercises {
                if let resolved = ExerciseLibrary.find(id: exercise.name) {
                    exercise.name = resolved.name
                    fixedCount += 1
                }
            }
            if fixedCount > 0 {
                print("🔧 [Migration] Fixed \(fixedCount) WorkoutExercise names from raw IDs")
            }
        }
        
        try? modelContext.save()
    }

    // MARK: - Routine Migration

    /// Migrates existing training plans from day-owned exercises to shared WorkoutRoutine objects.
    /// Runs once on app launch. Safe to call multiple times (no-op if routines already exist).
    static func migrateToRoutines(modelContext: ModelContext) {
        // Check if migration is needed: any active non-event program with strength days
        // that have exercises but no workoutRoutineID
        let programDescriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true && $0.isEventPlan == false }
        )
        guard let programs = try? modelContext.fetch(programDescriptor) else { return }

        for program in programs {
            let strengthDays = program.workoutDays.filter { $0.dayType == "strength" }
            let needsMigration = strengthDays.contains { $0.workoutRoutineID == nil && !$0.exercises.isEmpty }
            guard needsMigration else { continue }

            print("🔧 [Routine Migration] Migrating program: \(program.programSummary ?? "unnamed")")

            // Group days by workout name — days with the same name share a routine
            var routinesByName: [String: WorkoutRoutine] = [:]
            let profile = program.userProfile

            for day in strengthDays where day.workoutRoutineID == nil && !day.exercises.isEmpty {
                let workoutName = day.dayName

                if let existingRoutine = routinesByName[workoutName] {
                    // Reuse existing routine
                    day.workoutRoutineID = existingRoutine.id.uuidString
                } else {
                    // Create new routine from this day's exercises
                    let routine = WorkoutRoutine(
                        name: workoutName,
                        isFromTemplate: program.planSource == "template",
                        templateSourceID: program.planTemplateID
                    )
                    routine.userProfile = profile
                    modelContext.insert(routine)

                    let sorted = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
                    for (i, planned) in sorted.enumerated() {
                        let definition = ExerciseLibrary.find(name: planned.name)
                        let routineEx = RoutineExercise(
                            exerciseID: definition?.id ?? planned.name,
                            exerciseName: planned.name,
                            sets: planned.targetSets,
                            reps: planned.targetReps ?? "\(planned.targetRepsForLogging)",
                            sortOrder: i,
                            isBodyweight: planned.isBodyweight
                        )
                        routineEx.notes = planned.notes
                        routineEx.routine = routine
                        modelContext.insert(routineEx)
                    }

                    routinesByName[workoutName] = routine
                    day.workoutRoutineID = routine.id.uuidString
                }
            }

            print("   Created \(routinesByName.count) routines from \(strengthDays.count) strength days")
        }

        do {
            try modelContext.save()
            print("✅ [Routine Migration] Complete")
        } catch {
            print("❌ [Routine Migration] Failed: \(error)")
        }
    }
    
    // MARK: - Template Validation (debug)
    
    /// Validates that every exerciseID in the catalog resolves to an ExerciseLibrary entry.
    /// Call during development/testing to catch typos.
    static func validateTemplateCatalog() {
        var missing: [String] = []
        for plan in TrainingPlanCatalog.allPlans {
            for workout in plan.workouts {
                for exercise in workout.exercises {
                    if ExerciseLibrary.find(id: exercise.exerciseID) == nil {
                        missing.append("Plan '\(plan.name)' → '\(workout.name)' references unknown exercise: \(exercise.exerciseID)")
                    }
                }
            }
        }
        if missing.isEmpty {
            print("✅ [Validation] All template exerciseIDs resolve to ExerciseLibrary entries")
        } else {
            for msg in missing {
                print("⚠️ [Validation] \(msg)")
            }
        }
    }

    // MARK: - Routine Lookup Helper

    /// Fetches a WorkoutRoutine by its UUID string. Used by views to resolve workoutRoutineID.
    static func fetchRoutine(id routineIDString: String?, modelContext: ModelContext) -> WorkoutRoutine? {
        guard let idString = routineIDString,
              let uuid = UUID(uuidString: idString) else { return nil }
        let descriptor = FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate { $0.id == uuid }
        )
        return try? modelContext.fetch(descriptor).first
    }
}