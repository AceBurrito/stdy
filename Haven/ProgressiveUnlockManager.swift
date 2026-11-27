import Foundation
import SwiftData

// MARK: - Progressive Unlock Manager
// Offers new interventions when user demonstrates consistent adherence
// No tier dependency — uses flat max habit count and PaceInterventionSelector

class ProgressiveUnlockManager {
    
    // Max habits a user can have active (free tier = 3, pro = 10)
    // TODO: Gate this behind subscription status
    private static let maxHabitsFree = 3
    private static let maxHabitsPro = 10
    
    // MARK: - Check if Ready for New Intervention
    static func shouldOfferNewIntervention(
        profile: UserProfile,
        weeklyAdherence: [Double],  // Last 4-6 weeks of adherence rates
        modelContext: ModelContext
    ) -> Bool {
        
        // Criteria: 4+ weeks at 80%+ adherence
        guard weeklyAdherence.count >= 4 else {
            return false
        }
        
        let recentWeeks = Array(weeklyAdherence.prefix(4))
        let averageAdherence = recentWeeks.reduce(0, +) / Double(recentWeeks.count)
        
        // Check if meeting threshold
        let meetsThreshold = averageAdherence >= 0.80
        
        // Check if we've offered recently (don't spam)
        if let lastUnlock = profile.lastInterventionUnlockDate {
            let daysSinceLastUnlock = Calendar.current.dateComponents([.day], from: lastUnlock, to: Date()).day ?? 0
            if daysSinceLastUnlock < 21 {  // Wait at least 3 weeks between offers
                return false
            }
        }
        
        // Check if they've already maxed out habits
        let currentHabitCount = getCurrentHabitCount(profile: profile, modelContext: modelContext)
        let maxHabits = maxHabitsPro
        
        if currentHabitCount >= maxHabits {
            return false  // Already at limit
        }
        
        print("📊 Progressive Unlock Check:")
        print("   Average Adherence: \(Int(averageAdherence * 100))%")
        print("   Current Habits: \(currentHabitCount)/\(maxHabits)")
        print("   Meets Threshold: \(meetsThreshold)")
        
        return meetsThreshold
    }
    
    // MARK: - Generate Next Intervention Recommendation
    static func recommendNextIntervention(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> Intervention? {
        
        print("🔵 Generating next intervention recommendation...")
        
        // Get user's current selections
        guard let selectedIds = profile.selectedInterventionIds else {
            print("❌ No existing selections found")
            return nil
        }
        
        // Get latest metrics
        let descriptor = FetchDescriptor<HealthMetrics>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let metrics = try? modelContext.fetch(descriptor).first
        
        // Build user info for PaceInterventionSelector
        let userInfo = PaceInterventionSelector.UserInfo(
            name: profile.name ?? "Friend",
            age: profile.age ?? 40,
            isMale: profile.gender?.lowercased() == "male",
            primaryGoal: profile.primaryGoal ?? "live_longer",
            sleepHours: metrics?.sleepDuration,
            hrv: metrics?.heartRateVariability,
            rhr: metrics?.restingHeartRate,
            vo2Max: metrics?.vo2Max,
            steps: metrics?.stepCount,
            bodyweight: profile.weight,
            proteinGrams: profile.currentProteinIntake,
            activityLevel: profile.activityLevel
        )
        
        // Assess current deficiencies
        let deficiencies = DeficiencyAssessment.determinePriorities(
            sleepHours: metrics?.sleepDuration,
            proteinGrams: profile.currentProteinIntake,
            bodyWeight: profile.weight,
            vo2Max: metrics?.vo2Max,
            hrv: metrics?.heartRateVariability,
            rhr: metrics?.restingHeartRate,
            steps: metrics?.stepCount,
            activityLevel: profile.activityLevel,
            age: profile.age ?? 40,
            isMale: profile.gender?.lowercased() == "male",
            primaryGoal: profile.primaryGoal ?? "live_longer"
        )
        
        // Use PaceInterventionSelector (deterministic, $0.00)
        let allRecommendations = PaceInterventionSelector.selectInterventions(
            deficiencies: deficiencies,
            userInfo: userInfo
        )
        
        // Filter out already-selected interventions
        let availableInterventions = allRecommendations.interventions.filter { intervention in
            !selectedIds.contains(intervention.id)
        }
        
        // Return highest-impact available intervention
        let nextIntervention = availableInterventions.first
        
        if let next = nextIntervention {
            print("✅ Next intervention: \(next.title) (impact: \(next.impactScore))")
        } else {
            print("⚠️ No new interventions available")
        }
        
        return nextIntervention
    }
    
    // MARK: - Accept New Intervention
    static func acceptNewIntervention(
        profile: UserProfile,
        intervention: Intervention,
        modelContext: ModelContext
    ) throws {
        
        print("✅ Accepting new intervention: \(intervention.title)")
        
        // Add to selected IDs
        var selectedIds = profile.selectedInterventionIds ?? []
        selectedIds.append(intervention.id)
        profile.selectedInterventionIds = selectedIds
        
        // Update JSON
        if var existingInterventions = InterventionRecommendationEngine.getSavedSelections(profile: profile) {
            existingInterventions.append(intervention)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            if let jsonData = try? encoder.encode(existingInterventions),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                profile.selectedInterventionsJSON = jsonString
            }
        }
        
        // Update last unlock date
        profile.lastInterventionUnlockDate = Date()
        
        // Create the habit — use custom title if provided
        let habitTitle = intervention.customTitle ?? intervention.title
        let habitDetails: String
        if let duration = intervention.customDuration {
            habitDetails = "\(duration) minutes daily"
        } else {
            habitDetails = intervention.whyThisMatters
        }
        
        let habit = Habit(
            title: habitTitle,
            details: habitDetails,
            pillar: mapCategoryToPillar(intervention.category),
            habitType: "non_negotiable",
            isTrainingHabit: false,
            isUnlocked: true
        )
        modelContext.insert(habit)
        habit.userProfile = profile
        
        try modelContext.save()
        
        print("✅ New intervention added to profile and habits")
    }
    
    // MARK: - Decline New Intervention
    static func declineNewIntervention(
        profile: UserProfile,
        modelContext: ModelContext
    ) throws {
        
        print("❌ User declined new intervention")
        
        // Update last unlock date to prevent immediate re-offer
        profile.lastInterventionUnlockDate = Date()
        
        try modelContext.save()
    }
    
    // MARK: - Helper: Get Current Habit Count
    private static func getCurrentHabitCount(
        profile: UserProfile,
        modelContext: ModelContext
    ) -> Int {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                habit.isActive == true && habit.habitType == "non_negotiable"
            }
        )
        
        let habits = (try? modelContext.fetch(descriptor)) ?? []
        return habits.count
    }
    
    // MARK: - Helper: Map Category to Pillar
    private static func mapCategoryToPillar(_ category: String) -> String {
        switch category.lowercased() {
        case "sleep": return "Sleep"
        case "nutrition": return "Nutrition"
        case "movement": return "Movement"
        case "recovery": return "Recovery"
        case "lifestyle": return "Lifestyle"
        default: return "Lifestyle"
        }
    }
}