import Foundation

// MARK: - Pace Intervention Selector
// Tier-free, deterministic intervention selection based on deficiency analysis
// Uses InterventionLibrary directly, scores against PriorityAssessment results
// Cost: $0.00 per user — no AI, no API calls

class PaceInterventionSelector {
    
    // MARK: - User Info (minimal, no tier dependency)
    struct UserInfo {
        let name: String
        let age: Int
        let isMale: Bool
        let primaryGoal: String
        let sleepHours: Double?
        let hrv: Double?
        let rhr: Double?
        let vo2Max: Double?
        let steps: Double?
        let bodyweight: Double?
        let proteinGrams: Double?
        let activityLevel: String?
    }
    
    // MARK: - Select Interventions
    /// Returns top 6 interventions ranked by deficiency match, no tier filtering
    static func selectInterventions(
        deficiencies: [PriorityAssessment],
        userInfo: UserInfo
    ) -> InterventionRecommendationResponse {
        
        print("🎯 Selecting interventions (tier-free)...")
        print("   Deficiencies: \(deficiencies.count)")
        
        // Get ALL interventions (ignore tierRequirement)
        let allInterventions = InterventionLibrary.allInterventions
        
        // Score each intervention against deficiencies
        var scored: [(template: InterventionTemplate, score: Int)] = []
        
        for template in allInterventions {
            let score = calculateScore(
                template: template,
                deficiencies: deficiencies,
                userInfo: userInfo
            )
            scored.append((template, score))
        }
        
        // Sort by score (highest first)
        scored.sort { $0.score > $1.score }
        
        // Ensure category diversity: max 2 from same category in top 6
        let diversified = ensureCategoryDiversity(scored, maxPerCategory: 2)
        
        // Take top 6
        let top = Array(diversified.prefix(6))
        
        // Convert to Intervention objects
        let interventions = top.map { item -> Intervention in
            let template = item.template
            
            let personalizedWhy = personalizeText(
                template: template,
                userInfo: userInfo
            )
            
            let (currentValue, targetValue) = calculateValues(
                template: template,
                userInfo: userInfo
            )
            
            return Intervention(
                id: template.id,
                title: template.title,
                subtitle: template.subtitle,
                icon: template.icon,
                category: template.category.rawValue,
                impactScore: item.score,
                whyThisMatters: personalizedWhy,
                howToGuide: template.howToGuide,
                researchCitation: template.researchCitation,
                currentValue: currentValue,
                targetValue: targetValue
            )
        }
        
        // Build summary
        let summary = buildSummary(
            interventions: interventions,
            userName: userInfo.name
        )
        
        print("✅ Selected \(interventions.count) interventions ($0.00 cost)")
        for (i, intervention) in interventions.enumerated() {
            print("   \(i + 1). \(intervention.title) (score: \(intervention.impactScore), category: \(intervention.category))")
        }
        
        return InterventionRecommendationResponse(
            interventions: interventions,
            recommendationSummary: summary
        )
    }
    
    // MARK: - Scoring
    
    private static func calculateScore(
        template: InterventionTemplate,
        deficiencies: [PriorityAssessment],
        userInfo: UserInfo
    ) -> Int {
        var score = template.baseImpactScore
        
        // Boost if intervention addresses a user deficiency
        if let trigger = template.deficiencyTrigger {
            for deficiency in deficiencies {
                let bonus = matchDeficiency(
                    trigger: trigger,
                    deficiency: deficiency,
                    userInfo: userInfo
                )
                score += bonus
            }
        }
        
        // Small age boost for aging-related interventions (40+)
        if template.deficiencyTrigger == .aging && userInfo.age >= 40 {
            score += 5
        }
        
        // Small age boost for cognitive decline interventions (35+)
        if template.deficiencyTrigger == .cognitiveDecline && userInfo.age >= 35 {
            score += 3
        }
        
        return min(score, 100)
    }
    
    private static func matchDeficiency(
        trigger: DeficiencyTrigger,
        deficiency: PriorityAssessment,
        userInfo: UserInfo
    ) -> Int {
        let metric = deficiency.metric.lowercased()
        
        let matches: Bool
        switch trigger {
        case .lowSleep:
            matches = metric.contains("sleep") && deficiency.level == .critical
        case .sleepQuality:
            matches = metric.contains("sleep")
        case .lowProtein:
            matches = metric.contains("protein")
        case .lowVO2Max:
            matches = metric.contains("vo2") || metric.contains("cardio")
        case .lowHRV:
            matches = metric.contains("hrv") || metric.contains("recovery")
        case .lowSteps:
            matches = metric.contains("step") || metric.contains("neat")
        case .sedentary:
            matches = metric.contains("step") || metric.contains("movement") || metric.contains("activity")
        case .highStress:
            matches = metric.contains("stress") || metric.contains("hrv") || metric.contains("recovery")
        case .metabolic:
            matches = metric.contains("metabolic") || metric.contains("glucose")
        case .cardiovascular:
            matches = metric.contains("cardio") || metric.contains("vo2") || metric.contains("heart rate")
        case .recovery:
            matches = metric.contains("recovery") || metric.contains("hrv")
        case .aging:
            matches = userInfo.age >= 40
        case .cognitiveDecline:
            matches = userInfo.age >= 35 || metric.contains("cognitive") || metric.contains("purpose")
        }
        
        guard matches else { return 0 }
        
        switch deficiency.level {
        case .critical:    return 20
        case .deficient:   return 12
        case .adequate:    return 3
        case .optimal:     return 0
        case .excessive, .unknown: return 0
        }
    }
    
    // MARK: - Category Diversity
    
    private static func ensureCategoryDiversity(
        _ scored: [(template: InterventionTemplate, score: Int)],
        maxPerCategory: Int
    ) -> [(template: InterventionTemplate, score: Int)] {
        var result: [(template: InterventionTemplate, score: Int)] = []
        var categoryCounts: [InterventionCategory: Int] = [:]
        var overflow: [(template: InterventionTemplate, score: Int)] = []
        
        for item in scored {
            let cat = item.template.category
            let count = categoryCounts[cat, default: 0]
            
            if count < maxPerCategory {
                result.append(item)
                categoryCounts[cat] = count + 1
            } else {
                overflow.append(item)
            }
        }
        
        result.append(contentsOf: overflow)
        return result
    }
    
    // MARK: - Personalization
    
    private static func personalizeText(
        template: InterventionTemplate,
        userInfo: UserInfo
    ) -> String {
        var text = template.whyTemplate
        
        text = text.replacingOccurrences(of: "{age}", with: "\(userInfo.age)")
        text = text.replacingOccurrences(of: "{name}", with: userInfo.name)
        
        if let sleep = userInfo.sleepHours {
            text = text.replacingOccurrences(of: "{sleepHours}", with: String(format: "%.1f", sleep))
            let quality = sleep >= 7.5 ? "excellent" : sleep >= 7.0 ? "good" : sleep >= 6.5 ? "adequate" : "insufficient"
            text = text.replacingOccurrences(of: "{sleepQuality}", with: quality)
        } else {
            text = text.replacingOccurrences(of: "{sleepHours}", with: "unknown")
            text = text.replacingOccurrences(of: "{sleepQuality}", with: "unmeasured")
        }
        
        if let hrv = userInfo.hrv {
            text = text.replacingOccurrences(of: "{hrv}", with: String(format: "%.0f", hrv))
        } else {
            text = text.replacingOccurrences(of: "{hrv}", with: "unknown")
        }
        
        if let vo2 = userInfo.vo2Max {
            text = text.replacingOccurrences(of: "{vo2max}", with: String(format: "%.1f", vo2))
        }
        
        if let protein = userInfo.proteinGrams {
            text = text.replacingOccurrences(of: "{currentProtein}", with: "\(Int(protein))")
        }
        
        if let bw = userInfo.bodyweight {
            let proteinTarget = Int(bw * 0.8)
            let hydrationTarget = Int(bw * 0.5)
            
            if template.id == "hydration_target" {
                text = text.replacingOccurrences(of: "{target}", with: "\(hydrationTarget)")
                text = text.replacingOccurrences(of: "{calculated}", with: "\(hydrationTarget)oz daily (0.5oz/lb)")
            } else {
                text = text.replacingOccurrences(of: "{target}", with: "\(proteinTarget)")
                text = text.replacingOccurrences(of: "{calculated}", with: "\(proteinTarget)g daily (0.8g/lb)")
            }
        } else {
            text = text.replacingOccurrences(of: "{target}", with: "calculated")
            text = text.replacingOccurrences(of: "{calculated}", with: "based on bodyweight")
        }
        
        return text
    }
    
    private static func calculateValues(
        template: InterventionTemplate,
        userInfo: UserInfo
    ) -> (current: String?, target: String) {
        var targetValue = template.targetValue
        
        if template.requiresCalculation, let bw = userInfo.bodyweight {
            switch template.id {
            case "protein_target":
                targetValue = "\(Int(bw * 0.8))g daily (0.8g/lb)"
            case "hydration_target":
                targetValue = "\(Int(bw * 0.5))oz daily (0.5oz/lb)"
            default:
                break
            }
        }
        
        var currentValue: String? = nil
        
        switch template.id {
            
        // Nutrition — show current intake
        case "protein_target", "protein_breakfast":
            if let protein = userInfo.proteinGrams {
                currentValue = "\(Int(protein))g/day"
            }
            
        case "hydration_target":
            currentValue = "Not tracked"
            
        case "antioxidant_rich_foods", "fiber_intake", "processed_food_limitation":
            currentValue = "Not tracked"
            
        // Sleep — show current sleep average
        case "consistent_sleep_schedule", "morning_sunlight_exposure", "caffeine_cutoff",
             "screen_limits_before_bed", "magnesium_glycinate", "morning_walk",
             "nasal_breathing", "evening_wind_down":
            if let sleep = userInfo.sleepHours {
                currentValue = String(format: "%.1fh average sleep", sleep)
            }
            
        // Movement — show current steps
        case "daily_steps_target", "post_meal_walks", "limiting_sitting":
            if let steps = userInfo.steps {
                currentValue = "\(Int(steps)) steps/day"
            }
            
        // Recovery — show HRV for cold/breathing interventions
        case "resonant_breathing", "cold_shower_finish", "cold_plunge":
            if let hrv = userInfo.hrv {
                currentValue = String(format: "%.0fms HRV", hrv)
            }
            
        // Movement/Longevity — no baseline to show
        case "dead_hang_practice", "deep_squat_hold", "balance_training",
             "mobility_routine", "yoga_practice":
            currentValue = nil
            
        // Recovery — no baseline
        case "sauna_protocol", "meditation_practice", "foam_rolling",
             "progressive_relaxation", "five_minute_journal":
            currentValue = nil
            
        // Lifestyle/Purpose — no baseline
        case "daily_skill_practice", "creative_flow_time", "nature_exposure",
             "dental_hygiene":
            currentValue = nil
            
        // Supplements — no baseline
        case "creatine_supplementation", "omega3_supplementation",
             "vitamin_d_supplementation", "meal_timing":
            currentValue = nil
            
        default:
            currentValue = nil
        }
        
        return (currentValue, targetValue)
    }
    
    // MARK: - Summary
    
    private static func buildSummary(
        interventions: [Intervention],
        userName: String
    ) -> String {
        guard interventions.count >= 2 else {
            return "Select up to 3 habits to begin your longevity journey."
        }
        
        let topTwo = interventions.prefix(2).map { $0.title }.joined(separator: " and ")
        let categories = Set(interventions.map { $0.category })
        let categoryNote = categories.count >= 3 ?
            " These span \(categories.count) pillars of longevity for balanced improvement." : ""
        
        return "\(userName), based on your current metrics, \(topTwo.lowercased()) are your highest-impact starting points. Select up to 3 habits you can realistically maintain.\(categoryNote)"
    }
}