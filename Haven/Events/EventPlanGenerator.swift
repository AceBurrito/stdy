import Foundation
import SwiftData

    // MARK: - Training Plan Error
    enum TrainingPlanError: Error {
        case noProfile
        case parsingFailed
        case generationFailed(String)
    }


// MARK: - Event Plan Generator
class EventPlanGenerator {

    // MARK: - Generate Event Plan with Templates
    
    static func generateEventPlanWithTemplates(
        profile: UserProfile,
        modelContext: ModelContext,
        assessment: UserCapabilityAssessment,
        eventType: String,
        eventName: String?,
        eventDate: Date,
        weeksUntilEvent: Int
    ) async throws -> (masterPlan: EventMasterPlan, program: TrainingProgram) {
        
        print("🔵 [EventPlanGenerator] Generating event plan from template")
        
        // Find best template
        let template = TemplateManager.findBestTemplate(
            eventType: eventType,
            assessment: assessment,
            weekDuration: weeksUntilEvent,
            modelContext: modelContext
        )
        
        guard let template = template else {
            print("❌ [EventPlanGenerator] No template found - cannot proceed")
            throw TrainingPlanError.noProfile
        }
        
        print("✅ [EventPlanGenerator] Using template: \(template.experienceLevel) \(template.eventType) (\(template.weekDuration) weeks)")
        
        // Create master plan (metadata only)
        let masterPlan = EventMasterPlan(eventType: eventType, totalWeeks: weeksUntilEvent)
        masterPlan.eventName = eventName
        masterPlan.eventDate = eventDate
        masterPlan.assessmentId = assessment.id
        masterPlan.usesTemplates = true
        masterPlan.templateId = template.id
        masterPlan.phasesJSON = template.phasesJSON
        masterPlan.isActive = true
        
        // Deactivate existing master plans
        let descriptor = FetchDescriptor<EventMasterPlan>(
            predicate: #Predicate { $0.isActive == true }
        )
        if let existingPlans = try? modelContext.fetch(descriptor) {
            for plan in existingPlans {
                plan.isActive = false
            }
        }
        
        modelContext.insert(masterPlan)
        
        // Create training program
        let program = createEventProgram(
            profile: profile,
            modelContext: modelContext,
            masterPlan: masterPlan
        )
        
        // Parse template weeks
        guard let planData = template.fullPlanJSON.data(using: .utf8) else {
            print("❌ [EventPlanGenerator] Failed to convert fullPlanJSON to data")
            throw TrainingPlanError.parsingFailed
        }
        
        // Try to decode with better error handling
        do {
            let weeksArray = try JSONDecoder().decode([WeekDetailsJSON].self, from: planData)
            print("✅ [EventPlanGenerator] Parsed \(weeksArray.count) weeks from template")
            
            let templateWeeks = template.weekDuration
            let actualWeeks = weeksUntilEvent
            
            // Handle bridge plan if user has more weeks than template
            if actualWeeks > templateWeeks {
                let extraWeeks = actualWeeks - templateWeeks
                print("📅 [EventPlanGenerator] User has \(actualWeeks) weeks, template is \(templateWeeks) weeks")
                print("🌉 [BridgePlan] Creating \(extraWeeks)-week bridge plan")
                
                // Create bridge weeks
                let bridgeWeeks = try await createBridgePlan(
                    profile: profile,
                    modelContext: modelContext,
                    assessment: assessment,
                    extraWeeks: extraWeeks,
                    targetEventType: eventType,
                    templateStartWeek: extraWeeks + 1
                )
                
                // Add bridge weeks to program FIRST
                for week in bridgeWeeks {
                    week.trainingProgram = program
                    program.workoutWeeks.append(week)
                }
                
                // Then add template weeks (renumber them to start after bridge)
                for weekData in weeksArray {
                    let adjustedWeekNumber = weekData.weekNumber + extraWeeks
                    let week = try parseWeekDetails(
                        from: weekData,
                        weekNumber: adjustedWeekNumber,
                        phaseName: weekData.phase ?? "Training",
                        modelContext: modelContext
                    )
                    
                    week.trainingProgram = program
                    program.workoutWeeks.append(week)
                    modelContext.insert(week)
                }
                
                print("✅ [EventPlanGenerator] Created plan: \(extraWeeks) bridge weeks + \(weeksArray.count) template weeks")
                
                // ⭐ APPLY STRENGTH PREFERENCES (bridge + template weeks)
                print("🏋️ [EventPlanGenerator] Applying strength preferences to all weeks...")
                StrengthExerciseReplacer.applyStrengthPreferences(
                    to: program.workoutWeeks,
                    strengthDaysPerWeek: assessment.strengthDaysPerWeek ?? 2,
                    strengthGoal: assessment.strengthGoal,
                    equipmentAccess: assessment.equipmentAccess,
                    modelContext: modelContext
                )
                
            } else if actualWeeks < templateWeeks {
                // User has fewer weeks than template - use last N weeks of template
                let weeksToSkip = templateWeeks - actualWeeks
                print("⚠️ [EventPlanGenerator] User has \(actualWeeks) weeks, template is \(templateWeeks) weeks")
                print("🔄 [EventPlanGenerator] Using last \(actualWeeks) weeks of template (skipping first \(weeksToSkip) weeks)")
                
                // Load only the last N weeks, renumbered from 1
                let weeksToUse = Array(weeksArray.suffix(actualWeeks))
                
                for (index, weekData) in weeksToUse.enumerated() {
                    let week = try parseWeekDetails(
                        from: weekData,
                        weekNumber: index + 1,  // Renumber from 1
                        phaseName: weekData.phase ?? "Training",
                        modelContext: modelContext
                    )
                    week.trainingProgram = program
                    program.workoutWeeks.append(week)
                    modelContext.insert(week)
                }
                
                print("✅ [EventPlanGenerator] Using weeks \(weeksToSkip + 1)-\(templateWeeks) from template, renumbered as 1-\(actualWeeks)")
                
                // ⭐ APPLY STRENGTH PREFERENCES
                print("🏋️ [EventPlanGenerator] Applying strength preferences...")
                StrengthExerciseReplacer.applyStrengthPreferences(
                    to: program.workoutWeeks,
                    strengthDaysPerWeek: assessment.strengthDaysPerWeek ?? 2,
                    strengthGoal: assessment.strengthGoal,
                    equipmentAccess: assessment.equipmentAccess,
                    modelContext: modelContext
                )
                
            } else {
                // Perfect match - use template as-is
                print("✅ [EventPlanGenerator] Perfect duration match - using template as-is")
                
                for weekData in weeksArray {
                    let week = try parseWeekDetails(
                        from: weekData,
                        weekNumber: weekData.weekNumber,
                        phaseName: weekData.phase ?? "Training",
                        modelContext: modelContext
                    )
                    week.trainingProgram = program
                    program.workoutWeeks.append(week)
                    modelContext.insert(week)
                }
                
                // ⭐ APPLY STRENGTH PREFERENCES
                print("🏋️ [EventPlanGenerator] Applying strength preferences...")
                StrengthExerciseReplacer.applyStrengthPreferences(
                    to: program.workoutWeeks,
                    strengthDaysPerWeek: assessment.strengthDaysPerWeek ?? 2,
                    strengthGoal: assessment.strengthGoal,
                    equipmentAccess: assessment.equipmentAccess,
                    modelContext: modelContext
                )
            }
            
            // Update profile
            profile.currentEventWeek = 1
            profile.eventPlanStartDate = Date()
            profile.lastEventWeekAdvanceDate = Date()
            
            try? modelContext.save()
            
            print("✅ [EventPlanGenerator] Event plan created: \(program.workoutWeeks.count) total weeks")
            
            return (masterPlan, program)
            
        } catch {
            print("❌ [EventPlanGenerator] Failed to parse template weeks")
            print("   Error: \(error)")
            throw TrainingPlanError.parsingFailed
        }
    }
    
    // MARK: - Create Initial Training Program
    
    static func createEventProgram(
        profile: UserProfile,
        modelContext: ModelContext,
        masterPlan: EventMasterPlan
    ) -> TrainingProgram {
        
        // Deactivate existing programs
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        if let existingPrograms = try? modelContext.fetch(descriptor) {
            for program in existingPrograms {
                program.isActive = false
            }
        }
        
        // Create new program
        let program = TrainingProgram(
            programText: "",
            daysPerWeek: profile.trainingDaysPerWeek ?? 5,
            minutesPerSession: profile.trainingMinutesPerSession ?? 60
        )
        
        program.userProfile = profile
        program.splitType = "event_specific"
        program.programSummary = "\(masterPlan.totalWeeks)-week \(masterPlan.eventType) training plan"
        program.startDate = Date()
        program.isActive = true
        program.isEventPlan = true
        program.eventType = masterPlan.eventType
        program.eventName = masterPlan.eventName
        program.eventDate = masterPlan.eventDate
        program.totalWeeks = masterPlan.totalWeeks
        program.currentWeek = 1
        program.currentPhase = 1
        program.phasesJSON = masterPlan.phasesJSON
        
        modelContext.insert(program)
        try? modelContext.save()
        
        return program
    }
    
    // MARK: - Parse Week Details (from WeekDetailsJSON struct)
    
   private static func parseWeekDetails(
    from weekJSON: WeekDetailsJSON,
    weekNumber: Int,
    phaseName: String,
    modelContext: ModelContext
) throws -> PlannedWorkoutWeek {
    
    let week = PlannedWorkoutWeek(
        weekNumber: weekNumber,
        phaseName: phaseName
    )
    
    // Handle focus field (different names in different templates)
    week.weekFocus = weekJSON.focus ?? weekJSON.focusArea ?? "Progressive training"
    
    // Handle volume field (different names and types in different templates)
    if let weeklyMileage = weekJSON.weeklyMileage {
        week.totalVolume = "\(weeklyMileage) miles/week"
    } else {
        week.totalVolume = weekJSON.totalWeeklyMileage ?? weekJSON.totalVolume ?? "Varies"
    }
    
    // Create workout days
    for (index, dayData) in weekJSON.days.enumerated() {
        let workoutDay = PlannedWorkoutDay(
            dayType: dayData.dayType,
            dayName: dayData.dayName,
            dayOfWeek: dayData.dayOfWeek,
            orderIndex: index
        )
        
        // Cardio fields
        workoutDay.cardioType = dayData.cardioType
        workoutDay.cardioDuration = dayData.cardioDuration
        workoutDay.cardioNotes = dayData.cardioNotes
        workoutDay.targetHRMin = dayData.targetHRMin
        workoutDay.targetHRMax = dayData.targetHRMax
        workoutDay.targetDistance = dayData.targetDistance
        workoutDay.distanceUnit = dayData.distanceUnit
        workoutDay.targetPace = dayData.targetPace
        workoutDay.workoutStructure = dayData.workoutStructure
        workoutDay.isBrickWorkout = dayData.isBrickWorkout ?? false
        
        // Create exercises
        for (exerciseIndex, exerciseData) in dayData.exercises.enumerated() {
            let exercise = PlannedExercise(
                name: exerciseData.name,
                targetSets: exerciseData.targetSets,
                targetReps: exerciseData.targetReps ?? "0",
                orderIndex: exerciseIndex,
                isBodyweight: exerciseData.isBodyweight
            )
            exercise.notes = exerciseData.notes
            exercise.equipmentNeeded = exerciseData.equipmentNeeded
            exercise.workoutDay = workoutDay
            workoutDay.exercises.append(exercise)
            modelContext.insert(exercise)
        }
        
        workoutDay.workoutWeek = week
        week.days.append(workoutDay)
        modelContext.insert(workoutDay)
    }
    
    return week
}
    
    // MARK: - Bridge Plan Creation
    
    static func createBridgePlan(
        profile: UserProfile,
        modelContext: ModelContext,
        assessment: UserCapabilityAssessment,
        extraWeeks: Int,
        targetEventType: String,
        templateStartWeek: Int
    ) async throws -> [PlannedWorkoutWeek] {
        
        print("🌉 [BridgePlan] Creating \(extraWeeks)-week foundation plan")
        
        var bridgeWeeks: [PlannedWorkoutWeek] = []
        
        // Determine base training volume from assessment
        let baseRunDuration = getBaseDuration(from: assessment.runningCapability)
        let weeklyIncrease = calculateWeeklyIncrease(
            baseDuration: baseRunDuration,
            weeksAvailable: extraWeeks,
            targetEvent: targetEventType
        )
        
        print("🌉 [BridgePlan] Base duration: \(baseRunDuration) min, weekly increase: \(weeklyIncrease) min")
        
        for weekNum in 1...extraWeeks {
            let week = PlannedWorkoutWeek(
                weekNumber: weekNum,
                phaseName: "Foundation Building"
            )
            week.weekFocus = "Building aerobic base before event-specific training"
            week.totalVolume = "Progressive base building"
            
            // Calculate this week's run duration
            let currentRunDuration = baseRunDuration + ((weekNum - 1) * weeklyIncrease)
            
            // Progressive structure: Start with 2 runs/week, build to 3-4
            let runsThisWeek = min(4, 2 + (weekNum / 2))
            
            let weekStructure = createBridgeWeekStructure(
                weekNumber: weekNum,
                runCount: runsThisWeek,
                runDuration: currentRunDuration,
                eventType: targetEventType
            )
            
            for (index, dayData) in weekStructure.enumerated() {
                let workoutDay = PlannedWorkoutDay(
                    dayType: dayData.type,
                    dayName: dayData.name,
                    dayOfWeek: dayData.dayOfWeek,
                    orderIndex: index
                )
                
                if dayData.type == "run" {
                    workoutDay.cardioType = "easy"
                    workoutDay.cardioDuration = dayData.duration
                    workoutDay.cardioNotes = "Conversational pace, building aerobic base. Focus on consistency over speed."
                    workoutDay.targetDistance = Double(dayData.duration) / 10.0 // ~10 min/mile estimate
                    workoutDay.distanceUnit = "miles"
                    workoutDay.targetPace = "Conversational (60-70% max HR)"
                }
                
                if dayData.type == "strength" {
                    let exercises = getBasicStrengthExercises(
                        dayName: dayData.name,
                        weekNumber: weekNum,
                        eventType: targetEventType
                    )
                    
                    for (exIndex, exData) in exercises.enumerated() {
                        let exercise = PlannedExercise(
                            name: exData.name,
                            targetSets: exData.sets,
                            targetReps: exData.reps,
                            orderIndex: exIndex,
                            isBodyweight: exData.isBodyweight
                        )
                        exercise.notes = exData.notes
                        exercise.workoutDay = workoutDay
                        workoutDay.exercises.append(exercise)
                        modelContext.insert(exercise)
                    }
                    
                    workoutDay.cardioDuration = 40 // 40 min strength session
                }
                
                workoutDay.workoutWeek = week
                week.days.append(workoutDay)
                modelContext.insert(workoutDay)
            }
            
            bridgeWeeks.append(week)
            modelContext.insert(week)
        }
        
        print("✅ [BridgePlan] Created \(bridgeWeeks.count) foundation weeks")
        return bridgeWeeks
    }
    
    // MARK: - Bridge Plan Helpers
    
    private static func getBaseDuration(from capability: String) -> Int {
        switch capability {
        case "cannot_run_10min": return 10
        case "10_15min": return 15
        case "20_30min": return 25
        case "30_45min": return 35
        case "45_60min": return 50
        case "60plus": return 60
        default: return 20
        }
    }
    
    private static func calculateWeeklyIncrease(
        baseDuration: Int,
        weeksAvailable: Int,
        targetEvent: String
    ) -> Int {
        let targetDuration: Int
        switch targetEvent {
        case "5k": targetDuration = 30
        case "10k": targetDuration = 45
        case "half_marathon": targetDuration = 60
        case "marathon": targetDuration = 75
        case "hyrox": targetDuration = 40
        default: targetDuration = 45
        }
        
        let totalIncrease = max(0, targetDuration - baseDuration)
        let weeklyIncrease = weeksAvailable > 0 ? totalIncrease / weeksAvailable : 5
        
        return min(max(weeklyIncrease, 5), 15)
    }
    
    private static func createBridgeWeekStructure(
        weekNumber: Int,
        runCount: Int,
        runDuration: Int,
        eventType: String
    ) -> [(type: String, name: String, dayOfWeek: Int, duration: Int)] {
        
        var structure: [(type: String, name: String, dayOfWeek: Int, duration: Int)] = []
        
        structure.append(("rest", "Rest Day", 0, 0))
        
        switch runCount {
        case 2:
            structure.append(("run", "Easy Run", 1, runDuration))
            structure.append(("strength", "Lower Body Strength", 2, 40))
            structure.append(("rest", "Rest Day", 3, 0))
            structure.append(("run", "Easy Run", 4, runDuration))
            structure.append(("strength", "Upper Body + Core", 5, 40))
            structure.append(("rest", "Rest Day", 6, 0))
            
        case 3:
            structure.append(("run", "Easy Run", 1, runDuration))
            structure.append(("strength", "Lower Body Strength", 2, 40))
            structure.append(("run", "Easy Run", 3, runDuration))
            structure.append(("rest", "Rest Day", 4, 0))
            structure.append(("strength", "Upper Body + Core", 5, 40))
            structure.append(("run", "Easy Run", 6, runDuration))
            
        default:
            structure.append(("run", "Easy Run", 1, runDuration))
            structure.append(("strength", "Lower Body Strength", 2, 40))
            structure.append(("run", "Easy Run", 3, runDuration))
            structure.append(("run", "Easy Run", 4, runDuration))
            structure.append(("strength", "Upper Body + Core", 5, 40))
            structure.append(("run", "Easy Run", 6, runDuration))
        }
        
        return structure
    }
    
    private static func getBasicStrengthExercises(
        dayName: String,
        weekNumber: Int,
        eventType: String
    ) -> [(name: String, sets: Int, reps: String?, isBodyweight: Bool, notes: String)] {
        
        let sets = min(3 + (weekNumber / 3), 4)
        
        if dayName.contains("Lower") {
            return [
                ("Goblet Squat", sets, "12", false, "Focus on depth and control"),
                ("Romanian Deadlift", sets, "10", false, "Hamstring and glute focus"),
                ("Walking Lunges", sets, "20", true, "10 per leg, balance and stability"),
                ("Single-Leg Glute Bridge", sets, "12", true, "12 per leg, hip strength"),
                ("Plank", 3, "45 sec", true, "45-60 seconds, core stability")
            ]
        } else {
            return [
                ("Pushups", sets, "12", true, "Modify as needed, chest and triceps"),
                ("Dumbbell Rows", sets, "10", false, "Each arm, back strength"),
                ("Overhead Press", sets, "10", false, "Shoulder stability and strength"),
                ("Dead Bug", 3, "20", true, "10 per side, core control"),
                ("Side Plank", 3, "30 sec", true, "30 seconds each side, oblique strength")
            ]
        }
    }
    
    // MARK: - Ensure Week Exists (for lazy loading)
    
    static func ensureWeekExists(
        profile: UserProfile,
        modelContext: ModelContext,
        weekNumber: Int
    ) async throws -> PlannedWorkoutWeek {
        
        // Check if week already exists in the program
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        guard let program = try? modelContext.fetch(descriptor).first else {
            print("❌ No active training program found")
            throw TrainingPlanError.noProfile
        }
        
        if let existingWeek = program.workoutWeeks.first(where: { $0.weekNumber == weekNumber }) {
            print("✅ Week \(weekNumber) already exists")
            return existingWeek
        }
        
        // For template-based plans, weeks should all be pre-generated
        // This function is mainly for non-template plans
        print("⚠️ Week \(weekNumber) not found - cannot generate dynamically for template plans")
        throw TrainingPlanError.parsingFailed
    }
    
    // MARK: - Generate Master Plan (for non-template generation)
    
    static func generateMasterPlan(
        profile: UserProfile,
        modelContext: ModelContext,
        eventType: String,
        eventName: String?,
        eventDate: Date,
        weeksUntilEvent: Int,
        assessment: UserCapabilityAssessment
    ) async throws -> EventMasterPlan {
        
        print("🔵 Generating EVENT MASTER PLAN: \(eventType), \(weeksUntilEvent) weeks")
        
        // Deactivate existing master plans
        let descriptor = FetchDescriptor<EventMasterPlan>(
            predicate: #Predicate { $0.isActive == true }
        )
        if let existingPlans = try? modelContext.fetch(descriptor) {
            for plan in existingPlans {
                plan.isActive = false
            }
        }
        
        let masterPlan = EventMasterPlan(eventType: eventType, totalWeeks: weeksUntilEvent)
        masterPlan.eventName = eventName
        masterPlan.eventDate = eventDate
        masterPlan.assessmentId = assessment.id
        masterPlan.userProfile = profile
        masterPlan.isActive = true
        
        modelContext.insert(masterPlan)
        try? modelContext.save()
        
        print("✅ Master plan created")
        
        return masterPlan
    }
    
    // MARK: - Generate Week Details (for lazy loading - not used in template system)
    
    static func generateWeekDetails(
        profile: UserProfile,
        modelContext: ModelContext,
        masterPlan: EventMasterPlan,
        weekNumber: Int
    ) async throws -> PlannedWorkoutWeek {
        
        print("🔵 Generating WEEK \(weekNumber) details for \(masterPlan.eventType)")
        
        // This is a placeholder - template system pre-generates all weeks
        throw TrainingPlanError.parsingFailed
    }
}