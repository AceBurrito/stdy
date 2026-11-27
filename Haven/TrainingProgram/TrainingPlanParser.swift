import Foundation
import SwiftData

// MARK: - Training Plan Parser
class TrainingPlanParser {
    
    // MARK: - Parse AI Response into Models (Longevity - Single Week)
    static func parsePlan(
        from jsonString: String,
        modelContext: ModelContext,
        userProfile: UserProfile?
    ) -> TrainingProgram? {
        
        // Clean the response (remove markdown if present)
        let cleanedJSON = cleanJSONResponse(jsonString)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            return nil
        }
        
        do {
            let planData = try JSONDecoder().decode(TrainingPlanJSON.self, from: data)
            
            // Create TrainingProgram
            let program = TrainingProgram(
                programText: jsonString,
                daysPerWeek: planData.workoutDays.filter { $0.dayType != "rest" }.count,
                minutesPerSession: userProfile?.trainingMinutesPerSession ?? 45
            )
            program.userProfile = userProfile
            program.splitType = planData.splitType
            program.programSummary = planData.summary
            program.startDate = Date()
            program.isActive = true
            program.isEventPlan = false
            program.totalWeeks = 1
            program.currentWeek = 1
            
            // Create PlannedWorkoutDays (backward compatible - directly on program)
            for (index, dayData) in planData.workoutDays.enumerated() {
                let workoutDay = createWorkoutDay(from: dayData, orderIndex: index)
                workoutDay.trainingProgram = program
                
                // Create PlannedExercises
                for (exerciseIndex, exerciseData) in dayData.exercises.enumerated() {
                    let exercise = createExercise(from: exerciseData, orderIndex: exerciseIndex)
                    exercise.workoutDay = workoutDay
                    workoutDay.exercises.append(exercise)
                    modelContext.insert(exercise)
                }
                
                program.workoutDays.append(workoutDay)
                modelContext.insert(workoutDay)
            }
            
            modelContext.insert(program)
            
            do {
                try modelContext.save()
                print("✅ Training plan parsed and saved:")
                print("   Split: \(planData.splitType)")
                print("   Days: \(program.workoutDays.count)")
                print("   Training days: \(program.daysPerWeek)")
                return program
            } catch {
                print("❌ Failed to save training plan: \(error)")
                return nil
            }
            
        } catch {
            print("❌ Failed to parse training plan JSON: \(error)")
            print("   Raw response: \(jsonString.prefix(500))...")
            return nil
        }
    }
    
    // MARK: - Parse Event Plan (Multi-Week)
    static func parseEventPlan(
        from jsonString: String,
        modelContext: ModelContext,
        userProfile: UserProfile?,
        eventType: String,
        eventName: String?,
        eventDate: Date?,
        totalWeeks: Int
    ) -> TrainingProgram? {
        
        let cleanedJSON = cleanJSONResponse(jsonString)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            return nil
        }
        
        do {
            let planData = try JSONDecoder().decode(EventTrainingPlanJSON.self, from: data)
            
            // Create TrainingProgram
            let program = TrainingProgram(
                programText: jsonString,
                daysPerWeek: planData.daysPerWeek,
                minutesPerSession: userProfile?.trainingMinutesPerSession ?? 45
            )
            program.userProfile = userProfile
            program.splitType = "event_specific"
            program.programSummary = planData.summary
            program.startDate = Date()
            program.isActive = true
            
            // Event-specific fields
            program.isEventPlan = true
            program.eventType = eventType
            program.eventName = eventName
            program.eventDate = eventDate
            program.totalWeeks = planData.weeks.count
            program.currentWeek = 1
            program.currentPhase = 1
            
            // Encode phases
            if let phasesData = try? JSONEncoder().encode(planData.phases) {
                program.phasesJSON = String(data: phasesData, encoding: .utf8)
            }
            
            // Create PlannedWorkoutWeeks
            for weekData in planData.weeks {
                let week = PlannedWorkoutWeek(
                    weekNumber: weekData.weekNumber,
                    phaseName: weekData.phase
                )
                week.weekFocus = weekData.focus
                week.totalVolume = weekData.totalVolume
                week.trainingProgram = program
                
                // Create PlannedWorkoutDays for this week
                for (index, dayData) in weekData.days.enumerated() {
                    let workoutDay = createEventWorkoutDay(from: dayData, orderIndex: index)
                    workoutDay.workoutWeek = week
                    
                    // Create PlannedExercises (for strength days)
                    for (exerciseIndex, exerciseData) in dayData.exercises.enumerated() {
                        let exercise = createExercise(from: exerciseData, orderIndex: exerciseIndex)
                        exercise.workoutDay = workoutDay
                        workoutDay.exercises.append(exercise)
                        modelContext.insert(exercise)
                    }
                    
                    week.days.append(workoutDay)
                    modelContext.insert(workoutDay)
                }
                
                program.workoutWeeks.append(week)
                modelContext.insert(week)
            }
            
            modelContext.insert(program)
            
            do {
                try modelContext.save()
                print("✅ Event training plan parsed and saved:")
                print("   Event: \(eventType)")
                print("   Total weeks: \(program.totalWeeks)")
                print("   Phases: \(planData.phases)")
                return program
            } catch {
                print("❌ Failed to save event training plan: \(error)")
                return nil
            }
            
        } catch {
            print("❌ Failed to parse event training plan JSON: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            print("   Raw response: \(jsonString.prefix(2000))...")
            return nil
        }
    }
    
    // MARK: - Helper: Create Workout Day from JSON
    private static func createWorkoutDay(from dayData: WorkoutDayJSON, orderIndex: Int) -> PlannedWorkoutDay {
        let workoutDay = PlannedWorkoutDay(
            dayType: dayData.dayType,
            dayName: dayData.dayName,
            dayOfWeek: dayData.dayOfWeek,
            orderIndex: orderIndex
        )
        
        // ⭐ NEW: Store user's original activity name
        workoutDay.userActivityName = dayData.userActivityName
        
        // Cardio fields
        workoutDay.cardioType = dayData.cardioType
        workoutDay.cardioIntensityLevel = dayData.cardioIntensityLevel
        workoutDay.cardioProtocol = dayData.cardioProtocol
        workoutDay.cardioDuration = dayData.cardioDuration
        workoutDay.cardioNotes = dayData.cardioNotes
        workoutDay.targetHRMin = dayData.targetHRMin
        workoutDay.targetHRMax = dayData.targetHRMax
        
        return workoutDay
    }
    
    // MARK: - Helper: Create Event Workout Day from JSON
    private static func createEventWorkoutDay(from dayData: EventWorkoutDayJSON, orderIndex: Int) -> PlannedWorkoutDay {
        let workoutDay = PlannedWorkoutDay(
            dayType: dayData.dayType,
            dayName: dayData.dayName,
            dayOfWeek: dayData.dayOfWeek,
            orderIndex: orderIndex
        )
        
        // ⭐ NEW: Store user's original activity name
        workoutDay.userActivityName = dayData.userActivityName
        
        // Cardio fields
        workoutDay.cardioType = dayData.cardioType
        workoutDay.cardioIntensityLevel = dayData.cardioIntensityLevel
        workoutDay.cardioProtocol = dayData.cardioProtocol
        workoutDay.cardioDuration = dayData.cardioDuration
        workoutDay.cardioNotes = dayData.cardioNotes
        workoutDay.targetHRMin = dayData.targetHRMin
        workoutDay.targetHRMax = dayData.targetHRMax
        
        // Event-specific: distance-based workouts
        workoutDay.targetDistance = dayData.targetDistance
        workoutDay.distanceUnit = dayData.distanceUnit
        workoutDay.targetPace = dayData.targetPace
        workoutDay.workoutStructure = dayData.workoutStructure
        
        // Brick workout support
        workoutDay.isBrickWorkout = dayData.isBrickWorkout ?? false
        workoutDay.brickComponents = dayData.brickComponents
        
        return workoutDay
    }
    
    // MARK: - Helper: Create Exercise from JSON
    private static func createExercise(from exerciseData: ExerciseJSON, orderIndex: Int) -> PlannedExercise {
        let exercise = PlannedExercise(
            name: exerciseData.name,
            targetSets: exerciseData.targetSets,
            targetReps: exerciseData.targetReps ?? "0",
            orderIndex: orderIndex,
            isBodyweight: exerciseData.isBodyweight
        )
        exercise.notes = exerciseData.notes
        exercise.equipmentNeeded = exerciseData.equipmentNeeded
        return exercise
    }
    
    // MARK: - Clean JSON Response
    private static func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - JSON Decodable Structures (Longevity Plan)

struct TrainingPlanJSON: Decodable {
    let splitType: String
    let summary: String
    let workoutDays: [WorkoutDayJSON]
}

struct WorkoutDayJSON: Decodable {
    let dayOfWeek: Int
    let dayType: String
    let dayName: String
    let exercises: [ExerciseJSON]
    let userActivityName: String?  // ⭐ NEW
    let cardioType: String?
    let cardioIntensityLevel: String?
    let cardioProtocol: String?
    let cardioDuration: Int?
    let cardioNotes: String?
    let targetHRMin: Int?
    let targetHRMax: Int?
}


// MARK: - JSON Decodable Structures (Event Plan)

struct EventTrainingPlanJSON: Decodable {
    let eventType: String
    let summary: String
    let daysPerWeek: Int
    let totalWeeks: Int
    let phases: [String: [Int]]      // {"base": [1, 8], "build": [9, 16], "peak": [17, 19], "taper": [20, 21]}
    let weeks: [EventWeekJSON]
}

struct EventWeekJSON: Decodable {
    let weekNumber: Int
    let phase: String                // "Base", "Build", "Peak", "Taper"
    let focus: String                // "Building aerobic endurance"
    let totalVolume: String?         // "~6 hours"
    let days: [EventWorkoutDayJSON]
}

struct EventWorkoutDayJSON: Decodable {
    let dayOfWeek: Int
    let dayType: String              // "swim", "bike", "run", "brick", "strength", "rest"
    let dayName: String              // "Long Run", "Brick: Bike → Run"
    let exercises: [ExerciseJSON]    // For strength days
    let userActivityName: String?    // ⭐ NEW
    
    // Cardio fields
    let cardioType: String?
    let cardioIntensityLevel: String?
    let cardioProtocol: String?
    let cardioDuration: Int?
    let cardioNotes: String?
    let targetHRMin: Int?
    let targetHRMax: Int?
    
    // Distance-based fields
    let targetDistance: Double?
    let distanceUnit: String?        // "miles", "meters", "km"
    let targetPace: String?          // "8:30/mile"
    let workoutStructure: String?    // "Warmup 10min, Main set, Cooldown"
    
    // Brick workout
    let isBrickWorkout: Bool?
    let brickComponents: String?     // JSON string of components
}