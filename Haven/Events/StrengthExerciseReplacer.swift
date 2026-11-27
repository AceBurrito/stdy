import Foundation
import SwiftData

// MARK: - Strength Exercise Replacer
// Replaces exercises in loaded event training plans based on user's strength goals
// NO API calls, NO template modification - just object manipulation before saving

class StrengthExerciseReplacer {
    
    // MARK: - Main Replacement Function
    
    static func replaceExercises(
        in weeks: [PlannedWorkoutWeek],
        strengthGoal: String, // "injury_prevention" or "build_strength"
        equipmentAccess: String, // "full_gym" or "home_gym"
        modelContext: ModelContext
    ) {
        
        print("🏋️ [StrengthReplacer] Starting exercise replacement")
        print("   Goal: \(strengthGoal)")
        print("   Equipment: \(equipmentAccess)")
        
        var replacedCount = 0
        
        for week in weeks {
            let weekPhase = week.phaseName.lowercased()
            
            for day in week.days where day.dayType == "strength" {
                
                print("   📅 Week \(week.weekNumber): \(day.dayName)")
                
                // Get appropriate exercise library
                let newExerciseTemplates = StrengthExerciseLibraries.getExerciseLibrary(
                    dayName: day.dayName,
                    strengthGoal: strengthGoal,
                    equipmentAccess: equipmentAccess,
                    weekPhase: weekPhase
                )
                
                // If no replacement library (shouldn't happen), skip
                if newExerciseTemplates.isEmpty {
                    print("      ⚠️ No replacement library found, keeping original")
                    continue
                }
                
                // Delete old exercises from context
                for exercise in day.exercises {
                    modelContext.delete(exercise)
                }
                day.exercises.removeAll()
                
                // Add new exercises from library
                for (index, template) in newExerciseTemplates.enumerated() {
                    let exercise = PlannedExercise(
                        name: template.name,
                        targetSets: template.sets,
                        targetReps: template.reps,
                        orderIndex: index,
                        isBodyweight: template.isBodyweight
                    )
                    exercise.equipmentNeeded = template.equipment
                    exercise.notes = template.notes
                    exercise.workoutDay = day
                    day.exercises.append(exercise)
                    modelContext.insert(exercise)
                }
                
                // Adjust duration if building serious strength
                if strengthGoal == "build_strength" {
                    day.cardioDuration = 50 // Longer sessions for compound lifts
                }
                
                replacedCount += 1
                print("      ✅ Replaced \(newExerciseTemplates.count) exercises")
            }
        }
        
        print("✅ [StrengthReplacer] Completed: \(replacedCount) strength days modified")
    }
    
    // MARK: - Remove Strength Days (if user wants 0 strength)
    
    static func removeStrengthDays(
        from weeks: [PlannedWorkoutWeek],
        modelContext: ModelContext
    ) {
        
        print("🚫 [StrengthReplacer] Removing all strength training days")
        
        var removedCount = 0
        
        for week in weeks {
            for day in week.days where day.dayType == "strength" {
                
                // Delete exercises first
                for exercise in day.exercises {
                    modelContext.delete(exercise)
                }
                
                // Convert strength day to rest day
                day.dayType = "rest"
                day.dayName = "Rest Day"
                day.cardioDuration = nil
                day.exercises.removeAll()
                
                removedCount += 1
                print("   ✅ Week \(week.weekNumber): Converted \(day.dayName) → Rest Day")
            }
        }
        
        print("✅ [StrengthReplacer] Removed \(removedCount) strength days")
    }
    
    // MARK: - Add Extra Strength Day (if user wants 3x/week)
    
    static func addExtraStrengthDay(
        to weeks: [PlannedWorkoutWeek],
        strengthGoal: String,
        equipmentAccess: String,
        modelContext: ModelContext
    ) {
        
        print("➕ [StrengthReplacer] Adding 3rd strength day per week")
        
        var addedCount = 0
        
        for week in weeks {
            // Find a rest day to convert (prefer Thursday/Friday)
            if let restDay = week.days.first(where: { 
                $0.dayType == "rest" && ($0.dayOfWeek == 4 || $0.dayOfWeek == 5) 
            }) {
                
                // Convert to upper body strength day
                restDay.dayType = "strength"
                restDay.dayName = "Upper Body Strength"
                restDay.cardioDuration = strengthGoal == "build_strength" ? 50 : 40
                
                // Get upper body exercises
                let exerciseTemplates = StrengthExerciseLibraries.getExerciseLibrary(
                    dayName: "Upper Body Strength",
                    strengthGoal: strengthGoal,
                    equipmentAccess: equipmentAccess
                )
                
                // Add exercises
                for (index, template) in exerciseTemplates.enumerated() {
                    let exercise = PlannedExercise(
                        name: template.name,
                        targetSets: template.sets,
                        targetReps: template.reps,
                        orderIndex: index,
                        isBodyweight: template.isBodyweight
                    )
                    exercise.equipmentNeeded = template.equipment
                    exercise.notes = template.notes
                    exercise.workoutDay = restDay
                    restDay.exercises.append(exercise)
                    modelContext.insert(exercise)
                }
                
                addedCount += 1
                print("   ✅ Week \(week.weekNumber): Added Upper Body on \(getDayName(restDay.dayOfWeek))")
            }
        }
        
        print("✅ [StrengthReplacer] Added \(addedCount) extra strength days")
    }
    
    // MARK: - Remove One Strength Day (if user wants 1x/week)
    
    static func reduceToOneStrengthDay(
        in weeks: [PlannedWorkoutWeek],
        modelContext: ModelContext
    ) {
        
        print("➖ [StrengthReplacer] Reducing to 1 strength day per week")
        
        var removedCount = 0
        
        for week in weeks {
            let strengthDays = week.days.filter { $0.dayType == "strength" }
            
            // Keep first strength day (usually Tuesday), remove the rest
            for (index, day) in strengthDays.enumerated() {
                if index > 0 { // Remove all except first
                    
                    // Delete exercises
                    for exercise in day.exercises {
                        modelContext.delete(exercise)
                    }
                    
                    // Convert to rest
                    day.dayType = "rest"
                    day.dayName = "Rest Day"
                    day.cardioDuration = nil
                    day.exercises.removeAll()
                    
                    removedCount += 1
                    print("   ✅ Week \(week.weekNumber): Removed strength day → Rest")
                }
            }
        }
        
        print("✅ [StrengthReplacer] Reduced to 1 day, removed \(removedCount) strength days")
    }
    
    // MARK: - Apply User Preferences (Main Entry Point)
    
    static func applyStrengthPreferences(
        to weeks: [PlannedWorkoutWeek],
        strengthDaysPerWeek: Int, // 0, 1, 2, or 3
        strengthGoal: String?, // "injury_prevention" or "build_strength"
        equipmentAccess: String?, // "full_gym" or "home_gym"
        modelContext: ModelContext
    ) {
        
        print("🎯 [StrengthReplacer] Applying user preferences:")
        print("   Days per week: \(strengthDaysPerWeek)")
        print("   Goal: \(strengthGoal ?? "default")")
        print("   Equipment: \(equipmentAccess ?? "default")")
        
        // Count current strength days (templates have 2 by default)
        let currentStrengthDays = weeks.first?.days.filter { $0.dayType == "strength" }.count ?? 2
        
        switch strengthDaysPerWeek {
        case 0:
            // Remove all strength training
            removeStrengthDays(from: weeks, modelContext: modelContext)
            
        case 1:
            // Keep 1 strength day, remove the rest
            reduceToOneStrengthDay(in: weeks, modelContext: modelContext)
            
            // Apply exercise replacements if goal is build strength
            if let goal = strengthGoal, goal == "build_strength",
               let equipment = equipmentAccess {
                replaceExercises(
                    in: weeks,
                    strengthGoal: goal,
                    equipmentAccess: equipment,
                    modelContext: modelContext
                )
            }
            
        case 2:
            // Templates have 2 by default - just replace exercises if needed
            if let goal = strengthGoal, goal == "build_strength",
               let equipment = equipmentAccess {
                replaceExercises(
                    in: weeks,
                    strengthGoal: goal,
                    equipmentAccess: equipment,
                    modelContext: modelContext
                )
            }
            // If injury_prevention, keep template exercises as-is (they're already good)
            
        case 3:
            // Add 3rd strength day
            addExtraStrengthDay(
                to: weeks,
                strengthGoal: strengthGoal ?? "injury_prevention",
                equipmentAccess: equipmentAccess ?? "full_gym",
                modelContext: modelContext
            )
            
            // Replace exercises in all 3 days if build strength
            if let goal = strengthGoal, goal == "build_strength",
               let equipment = equipmentAccess {
                replaceExercises(
                    in: weeks,
                    strengthGoal: goal,
                    equipmentAccess: equipment,
                    modelContext: modelContext
                )
            }
            
        default:
            print("⚠️ [StrengthReplacer] Invalid strength days: \(strengthDaysPerWeek)")
        }
        
        print("✅ [StrengthReplacer] Strength preferences applied successfully")
    }
    
    // MARK: - Helper
    
    private static func getDayName(_ dayOfWeek: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard dayOfWeek >= 0 && dayOfWeek < days.count else { return "Unknown" }
        return days[dayOfWeek]
    }
}