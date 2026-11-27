import Foundation

// MARK: - Plan Recommendation Engine
// Scores and recommends 3-4 training plans from TrainingPlanCatalog
// based on user goals, equipment, experience, and optional bias.
// No AI, no network calls — pure deterministic logic.

struct PlanRecommendationEngine {

    // MARK: - Profile Mappers

    /// Maps UserProfile.availableEquipment display string to EquipmentTier enum
    static func mapEquipment(_ raw: String?) -> EquipmentTier {
        guard let raw = raw?.lowercased() else { return .fullGym }
        if raw.contains("no equipment") || raw.contains("minimal") || raw.contains("bodyweight") {
            return .bodyweight
        }
        if raw.contains("home") || raw.contains("dumbbell") {
            return .dumbbells
        }
        return .fullGym
    }

    /// Maps UserProfile.experienceLevel string to ExperienceLevel enum
    static func mapExperience(_ raw: String?) -> ExperienceLevel {
        guard let raw = raw?.lowercased() else { return .beginner }
        if raw.contains("advanced") { return .advanced }
        if raw.contains("intermediate") { return .intermediate }
        return .beginner
    }

    /// Maps a UserProfile goal string to the tags used in TrainingPlanTemplate.goalAlignment.
    /// Current goals: "lose_fat", "build_muscle", "recomp", "maintain".
    /// Legacy Atlas goals ("live_longer", "look_better", ...) are still mapped so
    /// older profiles keep getting sensible recommendations.
    /// Catalog tags: "liveLonger", "lookBetter", "feelBetter", "getStronger"
    static func mapGoal(_ raw: String) -> [String] {
        switch raw {
        case "lose_fat": return ["lookBetter"]
        case "build_muscle": return ["getStronger", "lookBetter"]
        // Recomp plans are tagged lookBetter + liveLonger in the catalog
        case "recomp": return ["lookBetter", "liveLonger"]
        // Foundation plans: balanced, sustainable volume
        case "maintain": return ["getStronger", "feelBetter", "liveLonger"]
        case "live_longer": return ["liveLonger"]
        case "look_better": return ["lookBetter"]
        case "feel_better": return ["feelBetter"]
        case "get_stronger", "sport_performance": return ["getStronger"]
        default: return [raw]
        }
    }

    // MARK: - Public API

    /// Returns 3-4 recommended plans based on user profile.
    /// Plans are filtered by equipment, scored by goals/experience,
    /// and diversified by category.
    static func recommend(
        primaryGoal: String?,
        secondaryGoal: String?,
        equipment: String?,
        experience: String?,
        strengthPercentile: Double? = nil,
        bias: RecommendationBias? = nil,
        excludingPlanID: String? = nil
    ) -> [TrainingPlanTemplate] {

        let equipmentTier = mapEquipment(equipment)
        let experienceLevel = mapExperience(experience)

        // Build mapped goals array
        var goals: [String] = []
        if let p = primaryGoal { goals.append(contentsOf: mapGoal(p)) }
        if let s = secondaryGoal { goals.append(contentsOf: mapGoal(s)) }

        return recommendInternal(
            goals: goals,
            equipment: equipmentTier,
            experience: experienceLevel,
            strengthPercentile: strengthPercentile,
            bias: bias,
            excludingPlanID: excludingPlanID
        )
    }

    // MARK: - Internal Scoring

    private static func recommendInternal(
        goals: [String],
        equipment: EquipmentTier,
        experience: ExperienceLevel,
        strengthPercentile: Double?,
        bias: RecommendationBias?,
        excludingPlanID: String?
    ) -> [TrainingPlanTemplate] {

        let allPlans = TrainingPlanCatalog.allPlans

        // Step 1: Filter by equipment compatibility
        // EquipmentTier is Comparable: .bodyweight < .dumbbells < .fullGym
        // A user with fullGym can use all plans; bodyweight user only sees bodyweight plans
        var compatiblePlans = allPlans.filter { $0.equipmentTier <= equipment }

        // Exclude current plan if specified (for Change Plan flow)
        if let excludeID = excludingPlanID {
            compatiblePlans = compatiblePlans.filter { $0.id != excludeID }
        }

        // Step 2: Score each plan
        var scoredPlans: [(plan: TrainingPlanTemplate, score: Int)] = compatiblePlans.map { plan in
            var score = 0

            // +10 per matching goal
            for goal in goals {
                if plan.goalAlignment.contains(goal) {
                    score += 10
                }
            }

            // +5 for exact experience match
            if experienceRank(plan.experienceLevel) > experienceRank(experience) {
                score -= 5
            }
            // +3 for adjacent experience
            else if experienceIsAdjacent(plan.experienceLevel, experience) {
                score += 3
            }

            // -5 penalty for plans requiring MORE experience than user has
            if plan.experienceLevel.rawValue > experience.rawValue {
                score -= 5
            }

            // +8 boost for fundamentals if strength percentile is very low
            if let pct = strengthPercentile, pct < 25 {
                if plan.category == .basicMovement {
                    score += 8
                }
            }

            // Apply bias from TrainingStatusAnalyzer
            if let bias = bias {
                score += biasScore(for: plan, bias: bias)
            }

            return (plan: plan, score: score)
        }

        // Step 3: Sort by score descending
        scoredPlans.sort { $0.score > $1.score }

        // Step 4: Diversify — max 2 from same category
        var result: [TrainingPlanTemplate] = []
        var categoryCounts: [PlanCategory: Int] = [:]

        for scored in scoredPlans {
            let cat = scored.plan.category
            let count = categoryCounts[cat, default: 0]
            if count < 2 {
                result.append(scored.plan)
                categoryCounts[cat] = count + 1
            }
            if result.count >= 4 { break }
        }

        // Ensure at least 3 results (pull from remaining if needed)
        if result.count < 3 {
            for scored in scoredPlans {
                if !result.contains(where: { $0.id == scored.plan.id }) {
                    result.append(scored.plan)
                }
                if result.count >= 3 { break }
            }
        }

        return result
    }

    // MARK: - Bias Scoring

    private static func biasScore(for plan: TrainingPlanTemplate, bias: RecommendationBias) -> Int {
        switch bias {
        case .simplify:
            return plan.strengthDays <= 3 ? 5 : -3

        case .moreVolume:
            return plan.strengthDays >= 4 ? 5 : -2

        case .changeStimulus:
            return 3

        case .advance:
            return plan.experienceLevel == .advanced ? 5 :
                   plan.experienceLevel == .intermediate ? 3 : 0

        case .maintain:
            return plan.category == .strength ? 3 : 0
        }
    }

    // MARK: - Helpers

    private static func experienceIsAdjacent(_ a: ExperienceLevel, _ b: ExperienceLevel) -> Bool {
    let diff = abs(experienceRank(a) - experienceRank(b))
    return diff == 1
}

private static func experienceRank(_ level: ExperienceLevel) -> Int {
    switch level {
    case .beginner: return 0
    case .intermediate: return 1
    case .advanced: return 2
    }
}
}

// MARK: - Recommendation Bias

extension PlanRecommendationEngine {
    /// Bias applied by TrainingStatusAnalyzer based on current plan performance
    enum RecommendationBias: String, Codable {
        case simplify       // Adherence dropping — suggest simpler plans
        case moreVolume     // Crushing it — suggest higher volume
        case changeStimulus // Stalling — suggest different approach
        case advance        // Ready — suggest harder plans
        case maintain       // Doing well — keep similar difficulty
    }
}