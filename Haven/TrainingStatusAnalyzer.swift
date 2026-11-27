import Foundation
import SwiftData

// MARK: - Training Status Analyzer
// Analyzes current training plan performance:
// - Weeks active, adherence %, per-lift e1RM progression
// - Generates recommendation bias for the PlanRecommendationEngine
// Uses existing EstimatedMaxCalculator for e1RM data.

struct TrainingStatusAnalyzer {

    // MARK: - Analysis Result

    struct TrainingAnalysis {
        let weeksActive: Int
        let adherencePercent: Double
        let liftProgressions: [LiftProgression]
        let assessmentText: String
        let bias: PlanRecommendationEngine.RecommendationBias
    }

    struct LiftProgression {
        let exerciseName: String
        let startingE1RM: Double?
        let currentE1RM: Double?
        let changePercent: Double?
        let trend: Trend

        enum Trend: String {
            case improving = "↑"
            case stalling = "→"
            case declining = "↓"
            case insufficient = "—"
        }
    }

    // MARK: - Public API

    /// Analyzes the active training program's performance.
    /// Call this when the user taps "Change Plan" to show them their status.
    static func analyze(
        program: TrainingProgram,
        workoutSessions: [WorkoutSession],
        modelContext: ModelContext
    ) -> TrainingAnalysis {

        let weeksActive = calculateWeeksActive(program: program)
        let adherence = calculateAdherence(program: program, sessions: workoutSessions)
        let progressions = calculateProgressions(sessions: workoutSessions, program: program)
        let bias = determineBias(adherence: adherence, progressions: progressions, weeksActive: weeksActive)
        let text = generateAssessmentText(
            weeksActive: weeksActive,
            adherence: adherence,
            progressions: progressions,
            bias: bias
        )

        return TrainingAnalysis(
            weeksActive: weeksActive,
            adherencePercent: adherence,
            liftProgressions: progressions,
            assessmentText: text,
            bias: bias
        )
    }

    // MARK: - Weeks Active

    private static func calculateWeeksActive(program: TrainingProgram) -> Int {
        guard let startDate = program.startDate ?? program.generatedDate as Date? else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(1, days / 7)
    }

    // MARK: - Adherence

    private static func calculateAdherence(program: TrainingProgram, sessions: [WorkoutSession]) -> Double {
        guard let startDate = program.startDate ?? program.generatedDate as Date? else { return 0 }

        let weeksActive = calculateWeeksActive(program: program)
        let expectedSessions = weeksActive * program.daysPerWeek

        guard expectedSessions > 0 else { return 0 }

        // Count sessions that occurred after the program started
        let relevantSessions = sessions.filter { $0.date >= startDate }
        let completed = relevantSessions.count

        return min(100, Double(completed) / Double(expectedSessions) * 100)
    }

    // MARK: - Lift Progressions

    private static func calculateProgressions(
        sessions: [WorkoutSession],
        program: TrainingProgram
    ) -> [LiftProgression] {

        guard let startDate = program.startDate ?? program.generatedDate as Date? else { return [] }

        // Get all sessions since program started, sorted by date
        let relevantSessions = sessions
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }

        // Collect all compound lifts performed
        var exerciseHistory: [String: [(date: Date, e1rm: Double)]] = [:]

        for session in relevantSessions {
            for exercise in session.exercises {
                let name = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard isCompoundLift(name) else { continue }

                // Calculate e1RM from best set in this exercise
                let bestE1RM = exercise.sets.compactMap { set -> Double? in
                    guard set.reps > 0 else { return nil }
                    if set.isBodyweight {
                        return Double(set.reps) // Track reps for bodyweight
                    }
                    guard let weight = set.weight, weight > 0 else { return nil }
                    // Epley formula: weight × (1 + reps/30)
                    return weight * (1.0 + Double(set.reps) / 30.0)
                }.max()

                if let e1rm = bestE1RM {
                    exerciseHistory[exercise.name, default: []].append((date: session.date, e1rm: e1rm))
                }
            }
        }

        // Build progressions for each tracked lift
        return exerciseHistory.compactMap { name, history -> LiftProgression? in
            guard history.count >= 2 else {
                return LiftProgression(
                    exerciseName: name,
                    startingE1RM: history.first?.e1rm,
                    currentE1RM: history.last?.e1rm,
                    changePercent: nil,
                    trend: .insufficient
                )
            }

            let startE1RM = history.first!.e1rm
            let currentE1RM = history.last!.e1rm

            guard startE1RM > 0 else { return nil }

            let change = ((currentE1RM - startE1RM) / startE1RM) * 100

            let trend: LiftProgression.Trend
            if change > 3 { trend = .improving }
            else if change < -3 { trend = .declining }
            else { trend = .stalling }

            return LiftProgression(
                exerciseName: name,
                startingE1RM: startE1RM,
                currentE1RM: currentE1RM,
                changePercent: change,
                trend: trend
            )
        }
        .sorted { ($0.currentE1RM ?? 0) > ($1.currentE1RM ?? 0) } // Heaviest lifts first
    }

    // MARK: - Bias Determination

    private static func determineBias(
        adherence: Double,
        progressions: [LiftProgression],
        weeksActive: Int
    ) -> PlanRecommendationEngine.RecommendationBias {

        // Low adherence → simplify
        if adherence < 60 {
            return .simplify
        }

        // Check for stalling (multiple lifts not progressing)
        let stallingCount = progressions.filter { $0.trend == .stalling || $0.trend == .declining }.count
        let totalTracked = progressions.filter { $0.trend != .insufficient }.count

        if totalTracked > 0 && stallingCount >= max(2, totalTracked / 2) {
            return .changeStimulus
        }

        // High adherence + good progression = ready to advance
        if adherence >= 80 && weeksActive >= 8 {
            let improvingCount = progressions.filter { $0.trend == .improving }.count
            if improvingCount > totalTracked / 2 {
                return .advance
            }
        }

        // High adherence but short tenure = maintain
        if adherence >= 80 {
            return .maintain
        }

        // Moderate adherence = could go either way
        return .maintain
    }

    // MARK: - Assessment Text

    private static func generateAssessmentText(
        weeksActive: Int,
        adherence: Double,
        progressions: [LiftProgression],
        bias: PlanRecommendationEngine.RecommendationBias
    ) -> String {

        let weekLabel = weeksActive == 1 ? "week" : "weeks"
        var text = "You've been on this plan for \(weeksActive) \(weekLabel) with \(Int(adherence))% adherence."

        let improving = progressions.filter { $0.trend == .improving }
        let stalling = progressions.filter { $0.trend == .stalling }
        let declining = progressions.filter { $0.trend == .declining }

        if !improving.isEmpty {
            let names = improving.prefix(3).map { $0.exerciseName }.joined(separator: ", ")
            text += " \(names) \(improving.count == 1 ? "is" : "are") progressing well."
        }

        if !stalling.isEmpty {
            let names = stalling.prefix(2).map { $0.exerciseName }.joined(separator: ", ")
            text += " \(names) \(stalling.count == 1 ? "has" : "have") plateaued."
        }

        if !declining.isEmpty {
            text += " Some lifts are trending down — check recovery and sleep."
        }

        switch bias {
        case .simplify:
            text += "\n\nAdherence is below 60%. A simpler program might be more sustainable."
        case .changeStimulus:
            text += "\n\nMultiple lifts have plateaued. A change in stimulus could help break through."
        case .advance:
            text += "\n\nStrong adherence and progression. You might be ready for a more challenging program."
        case .moreVolume:
            text += "\n\nYou're handling the current volume well. Consider adding more training days."
        case .maintain:
            if weeksActive < 8 {
                text += "\n\nStill early — this program has more to offer. Consider staying unless something isn't working."
            } else {
                text += "\n\nSolid progress. A change could add variety, or you can keep building on what's working."
            }
        }

        return text
    }

    // MARK: - Helpers

    private static func isCompoundLift(_ name: String) -> Bool {
        let compounds = [
            "squat", "bench press", "deadlift", "overhead press", "barbell row",
            "pull-up", "chin-up", "dip", "hip thrust", "romanian deadlift",
            "front squat", "incline press", "pendlay row", "bent over row",
            "military press", "push press", "clean", "snatch",
            "leg press", "lunges", "split squat", "bulgarian split squat"
        ]
        let lower = name.lowercased()
        return compounds.contains { lower.contains($0) }
    }
}