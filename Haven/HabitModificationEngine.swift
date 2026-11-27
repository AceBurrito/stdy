import Foundation
import SwiftData

// MARK: - Habit Modification Engine
class HabitModificationEngine {
    
    // MARK: - Apply Protocol Recommendation
    static func applyRecommendation(
        _ recommendation: ProtocolRecommendation,
        modelContext: ModelContext
    ) throws {
        
        print("🔧 Applying protocol recommendation: \(recommendation.action)")
        
        switch recommendation.action {
        case .simplify:
            try applySimplification(changes: recommendation.changes ?? [], modelContext: modelContext)
            
        case .progress:
            try applyProgression(additions: recommendation.additions ?? [], modelContext: modelContext)
            
        case .maintain:
            // No habit changes needed for maintain
            print("✅ Maintaining current protocol - no changes needed")
        }
    }
    
    // MARK: - Simplify: Reduce Habits
    private static func applySimplification(
        changes: [String],
        modelContext: ModelContext
    ) throws {
        
        // Get all active habits
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { $0.isActive == true }
        )
        
        guard let activeHabits = try? modelContext.fetch(descriptor) else {
            print("❌ Failed to fetch active habits")
            return
        }
        
        print("📊 Current active habits: \(activeHabits.count)")
        
        // Strategy: Keep only the most consistently performed habit (usually sleep)
        // or if changes mention specific habits, keep those
        
        // Find the habit with highest recent completion rate
        let habitScores = activeHabits.map { habit -> (habit: Habit, score: Double) in
            let completionRate = calculateRecentCompletionRate(habit: habit, modelContext: modelContext)
            return (habit, completionRate)
        }.sorted { $0.score > $1.score }
        
        // Keep top 1-2 habits, archive the rest
        let habitsToKeep = min(2, habitScores.count)
        
        for (index, habitScore) in habitScores.enumerated() {
            if index < habitsToKeep {
                print("✅ Keeping: \(habitScore.habit.title)")
            } else {
                habitScore.habit.isActive = false
                print("📦 Archived: \(habitScore.habit.title)")
            }
        }
        
        try modelContext.save()
        print("✅ Simplification applied: \(habitsToKeep) habits remaining")
    }
    
    // MARK: - Progress: Add New Habits
    private static func applyProgression(
        additions: [String],
        modelContext: ModelContext
    ) throws {
        
        print("📈 Adding new habits for progression")
        
        // Parse additions and create new habits
        for addition in additions {
            let habit = parseAndCreateHabit(from: addition)
            modelContext.insert(habit)
            print("✅ Added: \(habit.title)")
        }
        
        try modelContext.save()
        print("✅ Progression applied: \(additions.count) new habits added")
    }
    
    // MARK: - Helper: Parse Addition String into Habit
    private static func parseAndCreateHabit(from text: String) -> Habit {
        // Simple parsing - look for keywords
        let lowercased = text.lowercased()
        
        var title = text
        var details = ""
        var pillar = "General"
        
        // Detect pillar and provide defaults
        if lowercased.contains("sleep") {
            pillar = "Sleep"
            title = "Sleep Schedule"
            details = text
        } else if lowercased.contains("cardio") || lowercased.contains("zone 2") || lowercased.contains("walk") {
            pillar = "Fitness"
            title = "Zone 2 Cardio"
            details = text
        } else if lowercased.contains("strength") || lowercased.contains("resistance") {
            pillar = "Fitness"
            title = "Resistance Training"
            details = text
        } else if lowercased.contains("protein") {
            pillar = "Nutrition"
            title = "Protein Target"
            details = text
        } else if lowercased.contains("recovery") || lowercased.contains("stress") {
            pillar = "Recovery"
            title = "Recovery Practice"
            details = text
        }
        
        return Habit(title: title, details: details, pillar: pillar)
    }
    
    // MARK: - Helper: Calculate Recent Completion Rate
    private static func calculateRecentCompletionRate(
        habit: Habit,
        modelContext: ModelContext
    ) -> Double {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return 0.0
        }
        
        // Fetch all completions and filter in Swift (predicate doesn't support UUID comparison well)
        let allCompletionsDescriptor = FetchDescriptor<HabitCompletion>()
        let allCompletions = (try? modelContext.fetch(allCompletionsDescriptor)) ?? []
        
        let completions = allCompletions.filter { completion in
            guard let completionHabit = completion.habit else { return false }
            return completionHabit.id == habit.id &&
                   completion.date >= weekAgo &&
                   completion.completed == true
        }
        
        return Double(completions.count) / 7.0
    }
}