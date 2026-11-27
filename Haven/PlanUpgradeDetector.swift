import Foundation
import SwiftData

// MARK: - Plan Upgrade Detector
// Checks if the user should be shown a nudge card on TodayView
// suggesting they change their training plan.
//
// Triggers:
// 1. Basic Movement plan + 4+ weeks + high adherence → suggest progression
// 2. Same plan for 12+ weeks → suggest variety
// 3. Multiple lifts stalling → suggest change stimulus
//
// Cooldown: 2 weeks after dismissal before showing again.
// Storage: UserDefaults for dismissal date.

struct PlanUpgradeDetector {

    // MARK: - Nudge Result

    struct UpgradeNudge {
        let title: String
        let message: String
        let nudgeType: NudgeType
    }

    enum NudgeType: String {
        case readyToProgress    // Beginner plan + high adherence
        case timeForVariety     // 12+ weeks same plan
        case plateauDetected    // Multiple lifts stalling
    }

    // MARK: - UserDefaults Keys

    private static let dismissalDateKey = "planUpgradeNudgeDismissedDate"
    private static let cooldownDays = 14

    // MARK: - Public API

    /// Check if a nudge should be shown. Returns nil if no nudge needed.
    static func checkForNudge(
        program: TrainingProgram,
        workoutSessions: [WorkoutSession],
        modelContext: ModelContext
    ) -> UpgradeNudge? {

        // Check cooldown first
        if let dismissedDate = UserDefaults.standard.object(forKey: dismissalDateKey) as? Date {
            let daysSinceDismissal = Calendar.current.dateComponents([.day], from: dismissedDate, to: Date()).day ?? 0
            if daysSinceDismissal < cooldownDays {
                return nil
            }
        }

        // Must be an active longevity program (not event training)
        guard program.isActive, !program.isEventPlan else { return nil }

        let weeksActive = calculateWeeksActive(program: program)

        // Trigger 1: Basic/fundamentals plan + 4+ weeks + good adherence
        if let planCategory = program.planCategory,
        planCategory == PlanCategory.basicMovement.rawValue,           weeksActive >= 4 {
            let adherence = calculateAdherence(program: program, sessions: workoutSessions)
            if adherence >= 75 {
                return UpgradeNudge(
                    title: "Ready for More",
                    message: "You've built a solid foundation with \(Int(adherence))% adherence over \(weeksActive) weeks. Time to level up?",
                    nudgeType: .readyToProgress
                )
            }
        }

        // Trigger 2: Same plan for 12+ weeks
        if weeksActive >= 12 {
            return UpgradeNudge(
                title: "Fresh Stimulus",
                message: "You've been on this plan for \(weeksActive) weeks. A new program could spark new gains.",
                nudgeType: .timeForVariety
            )
        }

        // Trigger 3: Multiple lifts stalling
        let analysis = TrainingStatusAnalyzer.analyze(
            program: program,
            workoutSessions: workoutSessions,
            modelContext: modelContext
        )
        let stallingLifts = analysis.liftProgressions.filter {
            $0.trend == .stalling || $0.trend == .declining
        }
        if stallingLifts.count >= 2 {
            let names = stallingLifts.prefix(2).map { $0.exerciseName }.joined(separator: " and ")
            return UpgradeNudge(
                title: "Plateau Detected",
                message: "\(names) haven't progressed recently. A different approach could help break through.",
                nudgeType: .plateauDetected
            )
        }

        return nil
    }

    // MARK: - Dismissal

    /// Call when user dismisses the nudge card. Starts 2-week cooldown.
    static func dismissNudge() {
        UserDefaults.standard.set(Date(), forKey: dismissalDateKey)
    }

    /// Reset dismissal (for testing)
    static func resetDismissal() {
        UserDefaults.standard.removeObject(forKey: dismissalDateKey)
    }

    // MARK: - Helpers

    private static func calculateWeeksActive(program: TrainingProgram) -> Int {
        let startDate = program.startDate ?? program.generatedDate
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(1, days / 7)
    }

    private static func calculateAdherence(program: TrainingProgram, sessions: [WorkoutSession]) -> Double {
        let startDate = program.startDate ?? program.generatedDate
        let weeksActive = calculateWeeksActive(program: program)
        let expectedSessions = weeksActive * program.daysPerWeek
        guard expectedSessions > 0 else { return 0 }

        let relevantSessions = sessions.filter { $0.date >= startDate }
        return min(100, Double(relevantSessions.count) / Double(expectedSessions) * 100)
    }
}