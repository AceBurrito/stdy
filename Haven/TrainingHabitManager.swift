import Foundation
import SwiftData

class TrainingHabitManager {
    
    // MARK: - Create Training Habits from Current Week
    /// Creates training habits from the active training program's current week
    /// For event plans: uses the current event week
    /// For longevity plans: uses the single repeating week
    static func createTrainingHabits(
        profile: UserProfile,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let program = (try? modelContext.fetch(descriptor))?.first else {
                    print("⚠️ No active training program found")
                    return
        }
        
        // First, delete existing training habits
        deleteExistingTrainingHabits(modelContext: modelContext)
        
        // Get workouts for the appropriate week
        let workouts: [PlannedWorkoutDay]
        
        if program.isEventPlan {
            let currentWeek = profile.currentEventWeek
            if let week = program.workoutWeeks.first(where: { $0.weekNumber == currentWeek }) {
                workouts = week.days.sorted { $0.dayOfWeek < $1.dayOfWeek }
                print("🔵 Creating habits from event week \(currentWeek): \(week.phaseName)")
            } else {
                print("⚠️ Could not find event week \(currentWeek)")
                return
            }
        } else {
            workouts = program.workoutDays.sorted { $0.dayOfWeek < $1.dayOfWeek }
            print("🔵 Creating habits from longevity plan")
        }
        
        // Create a habit for each day
        for workout in workouts {
            createHabitFromWorkout(workout, profile: profile, modelContext: modelContext)
            
            // FEAT-003: If this strength day has secondary cardio, create a second habit for it
            if workout.dayType == "strength" && workout.hasSecondaryCardio {
                createSecondaryCardioHabit(workout, profile: profile, modelContext: modelContext)
            }
        }
        
        try? modelContext.save()
        print("✅ Training habits created: \(workouts.count) days")
    }
    
    // MARK: - Create Single Habit from Workout
    private static func createHabitFromWorkout(
        _ workout: PlannedWorkoutDay,
        profile: UserProfile,
        modelContext: ModelContext
    ) {
        let title: String
        let details: String
        let pillar: String
        let trainingDayType: String
        
        switch workout.dayType {
        case "rest":
            title = "Active Recovery"
            details = "Rest day - light movement, stretching, or complete rest"
            pillar = "Recovery"
            trainingDayType = "rest"
            
        case "strength":
            title = workout.dayName
            details = "\(workout.exercises.count) exercises"
            pillar = "Fitness"
            trainingDayType = "strength"
            
        case "cardio":
            title = workout.dayName
            if let duration = workout.cardioDuration {
                details = "\(duration) min • \(workout.cardioType?.capitalized ?? "Cardio")"
            } else {
                details = workout.cardioType?.capitalized ?? "Cardio"
            }
            pillar = "Fitness"
            trainingDayType = "cardio"
            
        case "run":
            title = workout.dayName
            details = formatEnduranceDetails(workout)
            pillar = "Fitness"
            trainingDayType = "run"
            
        case "bike":
            title = workout.dayName
            details = formatEnduranceDetails(workout)
            pillar = "Fitness"
            trainingDayType = "bike"
            
        case "swim":
            title = workout.dayName
            details = formatEnduranceDetails(workout)
            pillar = "Fitness"
            trainingDayType = "swim"
            
        case "brick":
            title = workout.dayName
            if let structure = workout.workoutStructure {
                details = structure
            } else if let duration = workout.cardioDuration {
                details = "\(duration) min • Multi-sport"
            } else {
                details = "Brick workout"
            }
            pillar = "Fitness"
            trainingDayType = "brick"
            
        default:
            title = workout.dayName
            details = workout.cardioNotes ?? workout.dayType.capitalized
            pillar = "Fitness"
            trainingDayType = workout.dayType
        }
        
        let habit = Habit(
            title: title,
            details: details,
            pillar: pillar,
            startDate: Date(),
            habitType: "non_negotiable",
            isTrainingHabit: true,
            trainingDayType: trainingDayType,
            isUnlocked: true,
            dayOfWeek: workout.dayOfWeek
        )
        habit.userProfile = profile
        
        modelContext.insert(habit)
        print("   ✅ Created: \(title) for day \(workout.dayOfWeek)")
    }
    
    // MARK: - FEAT-003: Create Secondary Cardio Habit for Multi-Activity Days
    private static func createSecondaryCardioHabit(
        _ workout: PlannedWorkoutDay,
        profile: UserProfile,
        modelContext: ModelContext
    ) {
        let zone = workout.secondaryCardioZone ?? "Zone 2"
        let duration = workout.secondaryCardioDuration ?? 30
        
        let title = "\(zone) Cardio"
        let details = "\(duration) min"
        
        let habit = Habit(
            title: title,
            details: details,
            pillar: "Fitness",
            startDate: Date(),
            habitType: "non_negotiable",
            isTrainingHabit: true,
            trainingDayType: "cardio",
            isUnlocked: true,
            dayOfWeek: workout.dayOfWeek
        )
        habit.userProfile = profile
        
        modelContext.insert(habit)
        print("   ✅ Created secondary cardio: \(title) for day \(workout.dayOfWeek)")
    }
    
    // MARK: - Format Endurance Details
    private static func formatEnduranceDetails(_ workout: PlannedWorkoutDay) -> String {
        var parts: [String] = []
        
        // Distance
        if let distance = workout.targetDistance, let unit = workout.distanceUnit {
            parts.append(String(format: "%.1f %@", distance, unit))
        }
        
        // Duration
        if let duration = workout.cardioDuration {
            parts.append("~\(duration) min")
        }
        
        // Pace
        if let pace = workout.targetPace {
            parts.append(pace)
        }
        
        // Type
        if parts.isEmpty, let cardioType = workout.cardioType {
            parts.append(cardioType.capitalized)
        }
        
        return parts.joined(separator: " • ")
    }
    
    // MARK: - Delete Existing Training Habits
    static func deleteExistingTrainingHabits(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isTrainingHabit == true }
        )
        
        if let existingHabits = try? modelContext.fetch(descriptor) {
            for habit in existingHabits {
                modelContext.delete(habit)
            }
            print("🗑️ Deleted \(existingHabits.count) existing training habits")
        }
    }
    
    // MARK: - Check and Refresh Habits for New Week
    /// Call this on app launch or daily to check if habits need refreshing
    static func checkAndRefreshHabitsIfNeeded(
        profile: UserProfile,
        modelContext: ModelContext
    ) {
        let progDescriptor = FetchDescriptor<TrainingProgram>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard profile.trainingMode == "event",
            let program = (try? modelContext.fetch(progDescriptor))?.first,
            program.isEventPlan else {
            return
        }
        
        // Check if week has advanced
        let previousWeek = getStoredHabitWeek(modelContext: modelContext)
        let currentWeek = profile.currentEventWeek
        
        if currentWeek != previousWeek {
            print("📅 Event week changed from \(previousWeek) to \(currentWeek) - refreshing habits")
            createTrainingHabits(profile: profile, modelContext: modelContext)
            storeHabitWeek(currentWeek, modelContext: modelContext)
        }
    }
    
    // MARK: - Store/Retrieve Habit Week (simple tracking)
    private static func getStoredHabitWeek(modelContext: ModelContext) -> Int {
        // We can check the first training habit's details or use UserDefaults
        // For simplicity, using UserDefaults
        return UserDefaults.standard.integer(forKey: "currentHabitWeek")
    }
    
    private static func storeHabitWeek(_ week: Int, modelContext: ModelContext) {
        UserDefaults.standard.set(week, forKey: "currentHabitWeek")
    }
    
    // MARK: - Get Today's Training Habit
    static func getTodaysTrainingHabit(modelContext: ModelContext) -> Habit? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date()) - 1 // 0=Sun
        
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { 
                $0.isTrainingHabit == true && $0.isActive == true
            }
        )
        
        if let habits = try? modelContext.fetch(descriptor) {
            return habits.first { $0.dayOfWeek == todayWeekday }
        }
        
        return nil
    }
}