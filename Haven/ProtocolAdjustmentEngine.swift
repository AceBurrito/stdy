import Foundation
import SwiftData

// MARK: - Protocol Recommendation Result
struct ProtocolRecommendation {
    let action: ProtocolAction
    let reasoning: String
    let changes: [String]?        // For simplify
    let additions: [String]?      // For progress
    let encouragement: String?    // For maintain
    let sleepWarning: SleepWarningLevel?
    let regressionAlert: RegressionAlert?
}

// MARK: - Protocol Adjustment Engine
class ProtocolAdjustmentEngine {
    
    // MARK: - Main Analysis Function (Unified)
    static func analyzeAndRecommend(
        currentWeek: WeeklyCheckInData,
        previousWeeks: [WeeklyCheckInData],
        habitTrends: [HabitTrend],
        profile: UserProfile,
        modelContext: ModelContext
    ) async throws -> ProtocolRecommendation {
        
        let weeks = [currentWeek] + previousWeeks
        
        // Check for progressive unlock FIRST (before other checks)
        if let nextIntervention = try? await checkProgressiveUnlock(
            profile: profile,
            previousWeeks: previousWeeks,
            modelContext: modelContext
        ) {
            return ProtocolRecommendation(
                action: .progress,
                reasoning: "You've been consistent for 4+ weeks at 80%+ adherence. You've built a solid foundation - ready to add another habit?",
                changes: nil,
                additions: ["Add new intervention: \(nextIntervention.title)"],
                encouragement: nextIntervention.whyThisMatters,
                sleepWarning: nil,
                regressionAlert: nil
            )
        }
        
        // STEP 1: Check for Movement → Training progression
        let movementStatus = ProtocolAdjustmentRules.checkMovementPlanReadiness(
            profile: profile,
            weeks: weeks
        )
        
        if case .ready(let weeksCompleted, let avgAdherence, let fastTrack) = movementStatus {
            return ProtocolRecommendation(
                action: .progress,
                reasoning: buildMovementUpgradeReasoning(
                    weeksCompleted: weeksCompleted,
                    avgAdherence: avgAdherence,
                    fastTrack: fastTrack
                ),
                changes: nil,
                additions: ["Upgrade to Training Plan with \(profile.trainingDaysPerWeek ?? 3)x/week structured programming"],
                encouragement: nil,
                sleepWarning: nil,
                regressionAlert: nil
            )
        }
        
        // STEP 2: Detect sleep issues
        let sleepWarning = ProtocolAdjustmentRules.detectSleepIssue(
            currentWeek: currentWeek,
            previousWeeks: previousWeeks
        )
        
        // STEP 3: Detect regression
        let regressionAlert = ProtocolAdjustmentRules.detectRegression(weeks: weeks)
        
        // STEP 4: Determine action based on rules
        let consecutiveWeeks = ProtocolAdjustmentRules.countConsecutiveWeeks(weeks: weeks)
        
        let action = ProtocolAdjustmentRules.determineAction(
            adherence: currentWeek.habitCompletionRate,
            consecutiveHighWeeks: consecutiveWeeks.high,
            consecutiveLowWeeks: consecutiveWeeks.low,
            avgSleep: currentWeek.avgSleep
        )
        
        print("📊 Protocol Decision: \(action)")
        print("   Adherence: \(Int(currentWeek.habitCompletionRate * 100))%")
        print("   Consecutive high: \(consecutiveWeeks.high)")
        print("   Consecutive low: \(consecutiveWeeks.low)")
        print("   Sleep warning: \(sleepWarning)")
        if let alert = regressionAlert {
            print("   ⚠️ REGRESSION: \(alert.message)")
        }
        
        // STEP 5: Generate deterministic recommendations
        let recommendation: ProtocolRecommendation
        
        switch action {
        case .simplify:
            let fatiguedHabits = HabitFatigueDetector.detectFatigue(
                modelContext: modelContext,
                profile: profile
            )
            
            recommendation = generateSimplifyRecommendation(
                currentWeek: currentWeek,
                habitTrends: habitTrends,
                sleepWarning: sleepWarning,
                regressionAlert: regressionAlert,
                fatiguedHabits: fatiguedHabits
            )
            
        case .progress:
            recommendation = generateProgressRecommendation(
                currentWeek: currentWeek,
                habitTrends: habitTrends,
                consecutiveWeeks: consecutiveWeeks.high
            )
            
        case .maintain:
            let trend = calculateTrend(current: currentWeek, previous: previousWeeks)
            recommendation = generateMaintainRecommendation(
                currentWeek: currentWeek,
                trend: trend,
                sleepWarning: sleepWarning
            )
        }
        
        return recommendation
    }

    static func checkProgressiveUnlock(
        profile: UserProfile,
        previousWeeks: [WeeklyCheckInData],
        modelContext: ModelContext
    ) async throws -> Intervention? {
        
        print("🔍 Checking progressive unlock eligibility...")
        
        let adherenceRates = previousWeeks.prefix(6).map { $0.habitCompletionRate }
        
        let isEligible = ProgressiveUnlockManager.shouldOfferNewIntervention(
            profile: profile,
            weeklyAdherence: adherenceRates,
            modelContext: modelContext
        )
        
        if !isEligible {
            print("❌ Not eligible for progressive unlock")
            return nil
        }
        
        let nextIntervention = try await ProgressiveUnlockManager.recommendNextIntervention(
            profile: profile,
            modelContext: modelContext
        )
        
        if let intervention = nextIntervention {
            print("✅ Progressive unlock available: \(intervention.title)")
        }
        
        return nextIntervention
    }
    
    // MARK: - Movement Upgrade Reasoning
    private static func buildMovementUpgradeReasoning(
        weeksCompleted: Int,
        avgAdherence: Double,
        fastTrack: Bool
    ) -> String {
        if fastTrack {
            return "You've crushed it for \(weeksCompleted) weeks straight with \(Int(avgAdherence * 100))% average adherence. You've built a rock-solid foundation - you're ready to level up to structured training with progressive overload. This is exactly what we want to see."
        } else {
            return "After \(weeksCompleted) weeks and \(Int(avgAdherence * 100))% adherence, you've proven you can show up consistently. Your foundation is solid. Time to add structure and progressive overload with a Training Plan."
        }
    }

    
    // MARK: - Deterministic Recommendation Generators
    
    private static func generateSimplifyRecommendation(
        currentWeek: WeeklyCheckInData,
        habitTrends: [HabitTrend],
        sleepWarning: SleepWarningLevel,
        regressionAlert: RegressionAlert?,
        fatiguedHabits: [HabitFatigueDetector.FatiguedHabit] = []
    ) -> ProtocolRecommendation {
        
        let adherence = Int(currentWeek.habitCompletionRate * 100)
        var reasoning = ""
        var changes: [String] = []
        
        // Build reasoning
        if sleepWarning == .critical {
            reasoning = "Your sleep has dropped to \(String(format: "%.1f", currentWeek.avgSleep))h — everything else is secondary until this improves. We're simplifying your protocol to focus on recovery."
        } else if adherence < 40 {
            reasoning = "At \(adherence)% adherence, you're stretched too thin. Less is more right now — let's cut back to what you can actually do consistently."
        } else {
            reasoning = "Adherence dropped to \(adherence)% this week. Rather than pushing through, let's simplify and rebuild momentum."
        }
        
        // Identify what to cut
        if !fatiguedHabits.isEmpty {
            for fatigued in fatiguedHabits.prefix(2) {
                changes.append("Pause \(fatigued.habit.title) — adherence dropped \(Int(fatigued.decline * 100))% after \(fatigued.weeksSinceCreated) weeks")
            }
        }
        
        // Find lowest-adherence habits from trends
        let lowestHabits = habitTrends
            .sorted { $0.recentAdherence < $1.recentAdherence }
            .prefix(2)
        
        for habit in lowestHabits {
            let alreadyListed = changes.contains(where: { $0.contains(habit.habitName) })
            if !alreadyListed && habit.recentAdherence < 0.5 {
                changes.append("Pause \(habit.habitName) — only \(Int(habit.recentAdherence * 100))% completion recently")
            }
        }
        
        // Sleep-specific change
        if sleepWarning == .critical || sleepWarning == .warning {
            changes.append("Make sleep optimization your #1 priority this week")
        }
        
        // Ensure we have at least one change
        if changes.isEmpty {
            changes.append("Focus on your top 2-3 habits only — drop anything that feels like a burden this week")
        }
        
        return ProtocolRecommendation(
            action: .simplify,
            reasoning: reasoning,
            changes: changes,
            additions: nil,
            encouragement: nil,
            sleepWarning: sleepWarning,
            regressionAlert: regressionAlert
        )
    }
    
    private static func generateProgressRecommendation(
        currentWeek: WeeklyCheckInData,
        habitTrends: [HabitTrend],
        consecutiveWeeks: Int
    ) -> ProtocolRecommendation {
        
        let adherence = Int(currentWeek.habitCompletionRate * 100)
        
        let reasoning = "You've maintained \(adherence)%+ adherence for \(consecutiveWeeks) consecutive weeks. Your consistency has earned this — time to layer in the next piece."
        
        // Suggest additions based on what's missing
        var additions: [String] = []
        
        if currentWeek.avgSleep < 7.0 {
            additions.append("Add a wind-down routine: 30 min screen-free before bed")
        }
        
        if currentWeek.avgHRV < 40 {
            additions.append("Add 5-min breathwork for HRV improvement")
        }
        
        // Default suggestion if nothing specific
        if additions.isEmpty {
            additions.append("Consider adding one new habit from your next priority area")
        }
        
        return ProtocolRecommendation(
            action: .progress,
            reasoning: reasoning,
            changes: nil,
            additions: additions,
            encouragement: nil,
            sleepWarning: nil,
            regressionAlert: nil
        )
    }
    
    private static func generateMaintainRecommendation(
        currentWeek: WeeklyCheckInData,
        trend: String,
        sleepWarning: SleepWarningLevel
    ) -> ProtocolRecommendation {
        
        let adherence = Int(currentWeek.habitCompletionRate * 100)
        var reasoning = ""
        var encouragement = ""
        
        switch trend {
        case "improving":
            reasoning = "You're at \(adherence)% and trending up. Your current protocol is working — no changes needed."
            encouragement = "This is exactly what sustainable progress looks like. Keep showing up."
        case "declining":
            reasoning = "Adherence is at \(adherence)% and has dipped slightly. Not enough to simplify yet, but worth watching."
            encouragement = "One week doesn't define your trajectory. Focus on getting back to your rhythm this week."
        default:
            reasoning = "Steady at \(adherence)% adherence. Your habits are becoming automatic — that's the goal."
            encouragement = "Consistency compounds. Every week you maintain this, you're building a stronger foundation."
        }
        
        if sleepWarning == .warning {
            reasoning += " Keep an eye on sleep — it dipped a bit this week."
        }
        
        return ProtocolRecommendation(
            action: .maintain,
            reasoning: reasoning,
            changes: nil,
            additions: nil,
            encouragement: encouragement,
            sleepWarning: sleepWarning,
            regressionAlert: nil
        )
    }
    
    // MARK: - Helper Functions
    private static func calculateTrend(current: WeeklyCheckInData, previous: [WeeklyCheckInData]) -> String {
        guard let lastWeek = previous.first else { return "stable" }
        
        let change = current.habitCompletionRate - lastWeek.habitCompletionRate
        
        if change > 0.15 { return "improving" }
        if change < -0.15 { return "declining" }
        return "stable"
    }
}

// MARK: - Errors
enum ProtocolAdjustmentError: Error {
    case invalidResponse
}