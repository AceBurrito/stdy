import Foundation
import SwiftData

struct HabitFatigueDetector {
    
    struct FatiguedHabit {
        let habit: Habit
        let weeksSinceCreated: Int
        let currentRate: Double
        let decline: Double
        let suggestion: String
    }
    
    static func detectFatigue(
        modelContext: ModelContext,
        profile: UserProfile
    ) -> [FatiguedHabit] {
        
        let dataController = DataController(modelContext: modelContext)
        
        // Get all active habits
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { $0.isActive == true }
        )
        
        guard let habits = try? modelContext.fetch(habitDescriptor) else {
            return []
        }
        
        var fatiguedHabits: [FatiguedHabit] = []
        
        for habit in habits {
            // Calculate weeks since created
            let weeksSinceCreated = Calendar.current.dateComponents(
                [.weekOfYear],
                from: habit.startDate,
                to: Date()
            ).weekOfYear ?? 0
            
            // Only check habits that have been around 12+ weeks
            guard weeksSinceCreated >= 12 else { continue }
            
            // Get current and previous rates
            let currentRate = dataController.getHabitCompletionRateForPeriod(habit: habit, days: 7)
            let previousRate = dataController.getHabitCompletionRateHistorical(
                habit: habit,
                daysAgo: 7,
                duration: 7
            ) ?? 1.0
            
            let decline = previousRate - currentRate
            
            // Flag if declining by 20%+ after 12+ weeks
            if decline >= 0.20 {
                let suggestion = generateSuggestion(for: habit, profile: profile)
                
                fatiguedHabits.append(FatiguedHabit(
                    habit: habit,
                    weeksSinceCreated: weeksSinceCreated,
                    currentRate: currentRate,
                    decline: decline,
                    suggestion: suggestion
                ))
            }
        }
        
        return fatiguedHabits
    }
    
    private static func generateSuggestion(for habit: Habit, profile: UserProfile) -> String {
        let title = habit.title.lowercased()
        
        // Suggest variety based on habit type
        if title.contains("run") {
            return "Try cycling or swimming for variety"
        } else if title.contains("walk") {
            return "Mix in hiking or rucking"
        } else if title.contains("lift") || title.contains("strength") {
            return "Switch to a different training split or rep scheme"
        } else if title.contains("yoga") {
            return "Try Pilates or mobility work"
        } else if title.contains("meditation") {
            return "Try breathwork or journaling"
        } else if title.contains("sleep") {
            return "Reassess sleep environment and routine"
        } else {
            return "Consider a fresh approach or temporary break"
        }
    }
}