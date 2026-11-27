import Foundation
import SwiftData

// MARK: - Intervention Model
struct Intervention: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: String
    let impactScore: Int
    let whyThisMatters: String
    let howToGuide: String?
    let researchCitation: String
    let currentValue: String?
    let targetValue: String?

    var customTitle: String?
    var customDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case icon
        case category
        case impactScore = "impact_score"
        case whyThisMatters = "why_this_matters"
        case howToGuide = "how_to_guide"
        case researchCitation = "research_citation"
        case currentValue = "current_value"
        case targetValue = "target_value"
    }
}

// MARK: - Recommendation Response
struct InterventionRecommendationResponse: Codable {
    let interventions: [Intervention]
    let recommendationSummary: String
    
    enum CodingKeys: String, CodingKey {
        case interventions
        case recommendationSummary = "recommendation_summary"
    }
}

// MARK: - Intervention Recommendation Engine
class InterventionRecommendationEngine {
    
    // MARK: - Generate Recommendations (Deterministic)
    static func generateRecommendations(
        tier: TrainingTierAssessment.TrainingTier,
        deficiencies: [PriorityAssessment],
        userContext: LongevityPlanPrompts.UserContext,
        modelContext: ModelContext
    ) async throws -> InterventionRecommendationResponse {
        
        print("🔵 Generating intervention recommendations (deterministic)...")
        print("   Tier: \(tier.rawValue) (\(tier.name))")
        print("   Deficiencies: \(deficiencies.count)")
        
        // Load intervention templates from bundle
        let allInterventions = loadInterventionTemplates()
        
        // Score and rank based on deficiencies
        var scored: [(intervention: Intervention, score: Int)] = []
        
        for intervention in allInterventions {
            var score = intervention.impactScore
            
            for deficiency in deficiencies {
                if intervention.category.lowercased() == deficiency.metric.lowercased() {
                    score += deficiency.priority * 10
                }
            }
            
            // Boost sleep interventions if sleep is deficient
            if let sleepDeficiency = deficiencies.first(where: { $0.metric.lowercased() == "sleep" }) {
                if intervention.category.lowercased() == "sleep" {
                    score += sleepDeficiency.priority * 5
                }
            }
            
            scored.append((intervention, score))
        }
        
        // Sort by score descending, take top 5-7
        let ranked = scored
            .sorted { $0.score > $1.score }
            .prefix(7)
            .map { $0.intervention }
        
        let summary = buildRecommendationSummary(
            tier: tier,
            deficiencies: deficiencies,
            count: ranked.count
        )
        
        print("✅ Generated \(ranked.count) intervention recommendations")
        
        return InterventionRecommendationResponse(
            interventions: Array(ranked),
            recommendationSummary: summary
        )
    }
    
    // MARK: - Load Intervention Templates
    private static func loadInterventionTemplates() -> [Intervention] {
        // Try loading from bundle JSON first
        if let url = Bundle.main.url(forResource: "intervention_templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let interventions = try? JSONDecoder().decode([Intervention].self, from: data) {
            return interventions
        }
        
        // Fallback: hardcoded core interventions
        return defaultInterventions()
    }
    
    // MARK: - Default Interventions (Fallback)
    private static func defaultInterventions() -> [Intervention] {
        [
            Intervention(
                id: "morning_sunlight_exposure",
                title: "Morning Sunlight",
                subtitle: "10 min within 1hr of waking",
                icon: "sun.max.fill",
                category: "Sleep",
                impactScore: 9,
                whyThisMatters: "Morning light exposure anchors your circadian rhythm, improving sleep onset by 30-45 minutes and boosting daytime alertness.",
                howToGuide: "Step outside within 1 hour of waking. Face toward the sky (not directly at the sun) for 10 minutes. Cloudy days still work — overcast sky provides 10,000+ lux.",
                researchCitation: "Zeitzer et al. (2000): PMID 10742677",
                currentValue: nil,
                targetValue: "10 min daily"
            ),
            Intervention(
                id: "sleep_consistency",
                title: "Consistent Bedtime",
                subtitle: "Same time ±30 min every night",
                icon: "moon.fill",
                category: "Sleep",
                impactScore: 9,
                whyThisMatters: "Sleep regularity is a stronger predictor of mortality than sleep duration. A consistent schedule improves deep sleep and HRV.",
                howToGuide: "Pick a target bedtime and stick to it within 30 minutes, including weekends. Set a wind-down alarm 30 minutes before.",
                researchCitation: "Windred et al. (2024): Sleep regularity index",
                currentValue: nil,
                targetValue: "±30 min consistency"
            ),
            Intervention(
                id: "protein_per_meal",
                title: "Protein Target",
                subtitle: "30g+ protein per meal",
                icon: "fork.knife",
                category: "Nutrition",
                impactScore: 8,
                whyThisMatters: "Muscle protein synthesis requires ~30g leucine-rich protein per meal. Most people front-load carbs and under-eat protein at breakfast and lunch.",
                howToGuide: "Aim for 30-40g protein at each meal. Easy wins: Greek yogurt at breakfast, chicken/fish at lunch, any protein at dinner.",
                researchCitation: "Schoenfeld & Aragon (2018): PMID 29497353",
                currentValue: nil,
                targetValue: "30g per meal"
            ),
            Intervention(
                id: "daily_walk",
                title: "Daily Walk",
                subtitle: "20+ min outdoor walk",
                icon: "figure.walk",
                category: "Movement",
                impactScore: 8,
                whyThisMatters: "A daily walk improves insulin sensitivity, reduces cortisol, and contributes to the 7,000+ daily steps associated with reduced all-cause mortality.",
                howToGuide: "Walk for 20+ minutes at a comfortable pace. After meals is ideal for blood sugar management. No phone if possible.",
                researchCitation: "Paluch et al. (2021): Steps and mortality meta-analysis",
                currentValue: nil,
                targetValue: "20 min daily"
            ),
            Intervention(
                id: "hydration_target",
                title: "Hydration",
                subtitle: "Half bodyweight in oz daily",
                icon: "drop.fill",
                category: "Nutrition",
                impactScore: 7,
                whyThisMatters: "Even mild dehydration (1-2%) impairs cognitive function, exercise performance, and recovery. Most people are chronically under-hydrated.",
                howToGuide: "Drink half your body weight in ounces daily. Start with 16oz immediately on waking. Keep a water bottle visible all day.",
                researchCitation: "Popkin et al. (2010): PMID 20646222",
                currentValue: nil,
                targetValue: nil
            ),
            Intervention(
                id: "breathwork_recovery",
                title: "Breathwork",
                subtitle: "5 min daily down-regulation",
                icon: "wind",
                category: "Recovery",
                impactScore: 7,
                whyThisMatters: "Physiological sighs (double inhale, extended exhale) activate the parasympathetic nervous system, reducing cortisol and improving HRV within minutes.",
                howToGuide: "5 minutes of box breathing or physiological sighs. Best done post-workout or before bed. Inhale 4s, hold 4s, exhale 6-8s.",
                researchCitation: "Balban et al. (2023): Cyclic sighing - PMID 36630990",
                currentValue: nil,
                targetValue: "5 min daily"
            ),
            Intervention(
                id: "screen_curfew",
                title: "Screen Curfew",
                subtitle: "No screens 30 min before bed",
                icon: "iphone.slash",
                category: "Sleep",
                impactScore: 7,
                whyThisMatters: "Blue light from screens suppresses melatonin production by up to 50%. A 30-minute buffer dramatically improves sleep onset latency.",
                howToGuide: "Set a phone alarm 30 min before bedtime. Put devices in another room. Read, stretch, or talk instead.",
                researchCitation: "Chang et al. (2015): PMID 25535358",
                currentValue: nil,
                targetValue: "30 min screen-free"
            ),
        ]
    }
    
    // MARK: - Build Summary
    private static func buildRecommendationSummary(
        tier: TrainingTierAssessment.TrainingTier,
        deficiencies: [PriorityAssessment],
        count: Int
    ) -> String {
        let topDeficiency = deficiencies.first?.metric ?? "overall wellness"
        return "Based on your assessment, we recommend starting with \(count) habits focused on \(topDeficiency). These are ranked by impact — start with the top 2-3 and add more as they become automatic."
    }
    
    // MARK: - Save Selections to Profile
    static func saveSelections(
        profile: UserProfile,
        selectedInterventions: [Intervention],
        modelContext: ModelContext
    ) throws {
        
        profile.selectedInterventionIds = selectedInterventions.map { $0.id }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let jsonData = try? encoder.encode(selectedInterventions),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            profile.selectedInterventionsJSON = jsonString
        }
        
        try modelContext.save()
        
        print("✅ Saved \(selectedInterventions.count) selected interventions to profile")
    }
    
    // MARK: - Get Saved Selections
    static func getSavedSelections(profile: UserProfile) -> [Intervention]? {
        guard let jsonString = profile.selectedInterventionsJSON,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([Intervention].self, from: data)
    }
}

// MARK: - Errors
enum InterventionError: Error {
    case invalidJSON
    case noInterventions
    case parsingFailed(Error)
}