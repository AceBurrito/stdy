import Foundation

// MARK: - Deficiency Assessment Engine
// Uses research thresholds to determine what actually needs intervention

struct DeficiencyAssessment {
    
    // MARK: - Sleep Assessment
    static func assessSleep(averageHours: Double?) -> DeficiencyLevel {
        guard let hours = averageHours else { return .unknown }
        
        if hours < 6.0 {
            return .critical  // CRITICAL - Research: <6h = significant mortality risk
        } else if hours < 7.0 {
            return .deficient  // Suboptimal - Research: 7-8h optimal (Cappuccio 2010)
        } else if hours <= 8.0 {
            return .adequate  // TARGET ZONE ✅
        } else if hours <= 9.0 {
            return .adequate  // Still acceptable range
        } else {
            return .excessive  // May indicate quality issues or health concerns
        }
    }
    
    // MARK: - Protein Assessment  
    static func assessProtein(dailyGrams: Double?, bodyWeight: Double?) -> DeficiencyLevel {
        guard let protein = dailyGrams, let weight = bodyWeight else { return .unknown }
        
        let gramsPerPound = protein / weight
        
        if gramsPerPound < 0.6 {
            return .critical  // CRITICAL - Research: Risk of muscle loss
        } else if gramsPerPound < 0.8 {
            return .deficient  // Suboptimal - Research: 0.8-1.0g/lb for maintenance
        } else if gramsPerPound <= 1.0 {
            return .adequate  // Maintenance range ✅
        } else {
            return .optimal  // Muscle building range (Morton 2018)
        }
    }
    
    // MARK: - VO2 Max Assessment (age/gender adjusted)
    static func assessVO2Max(value: Double?, age: Int, isMale: Bool) -> DeficiencyLevel {
        guard let vo2 = value else { return .unknown }
        
        let thresholds = getVO2Thresholds(age: age, isMale: isMale)
        
        if vo2 < thresholds.poor {
            return .critical  // Research: Bottom quartile has 5x mortality risk
        } else if vo2 < thresholds.belowAverage {
            return .deficient  // Below average for age/gender
        } else if vo2 < thresholds.good {
            return .adequate  // Average fitness ✅
        } else {
            return .optimal  // Above average (Mandsager 2018)
        }
    }
    
    // MARK: - HRV Assessment (age/gender adjusted)
    static func assessHRV(value: Double?, age: Int, isMale: Bool) -> DeficiencyLevel {
        guard let hrv = value else { return .unknown }
        
        let baseline = getHRVBaseline(age: age, isMale: isMale)
        
        if hrv < baseline * 0.6 {
            return .critical  // Very low recovery capacity
        } else if hrv < baseline * 0.8 {
            return .deficient  // Below optimal
        } else if hrv >= baseline * 1.2 {
            return .optimal  // Excellent recovery
        } else {
            return .adequate  // Normal range ✅
        }
    }
    
    // MARK: - RHR Assessment
    static func assessRHR(value: Double?) -> DeficiencyLevel {
        guard let rhr = value else { return .unknown }
        
        if rhr > 85 {
            return .critical  // Research: Cardiovascular risk, medical evaluation recommended
        } else if rhr > 75 {
            return .deficient  // Below average fitness
        } else if rhr > 60 {
            return .adequate  // Average to good ✅
        } else {
            return .optimal  // Excellent cardiovascular fitness
        }
    }
    
    // MARK: - Steps Assessment
    static func assessSteps(dailyAverage: Double?) -> DeficiencyLevel {
        guard let steps = dailyAverage else { return .unknown }
        
        if steps < 5000 {
            return .critical  // Sedentary - Research: <5k = significantly increased mortality risk
        } else if steps < 7500 {
            return .deficient  // Below recommended - Research: 7,500-10,000 optimal (Lee 2019)
        } else if steps <= 10000 {
            return .adequate  // Recommended range ✅
        } else {
            return .optimal  // Above average activity
        }
    }

    // Add to DeficiencyAssessment struct
static func shouldPrescribeHabit(
    metric: String,
    level: DeficiencyLevel,
    currentValue: Double?,
    targetValue: Double?,
    otherDeficienciesExist: Bool
) -> Bool {
    
    // Critical deficiencies ALWAYS get prescribed
    if level == .critical {
        return true
    }
    
    // If metric is adequate/optimal, skip unless ALL others are also adequate
    if level == .adequate || level == .optimal {
        return false
    }
    
    // For deficient metrics, check minimum delta rules
    switch metric {
    case "Protein":
        guard let current = currentValue, let target = targetValue else { return true }
        let delta = abs(target - current)
        // Only prescribe if gap is >20g
        return delta > 20
        
    case "Daily Steps":
        guard let current = currentValue else { return true }
        // If ≥7500 steps, only prescribe if they're sedentary/lightly active
        // (This will be handled in the prompt context)
        return current < 7500
        
    case "Sleep":
        guard let current = currentValue else { return true }
        // Only prescribe if <7h average
        // (Consistency handled separately)
        return current < 7.0
        
    default:
        return true
    }
}
    
    // MARK: - Activity Level Assessment
    static func assessActivityLevel(_ level: String) -> DeficiencyLevel {
        switch level.lowercased() {
        case "sedentary":
            return .critical  // No regular activity
        case "lightly active", "light":
            return .deficient  // Some activity but inconsistent
        case "moderately active", "moderate":
            return .adequate  // Regular activity ✅
        case "very active", "active", "athlete":
            return .optimal  // Consistent training
        default:
            return .unknown
        }
    }
    
    // MARK: - Helper: VO2 Thresholds by Age/Gender
    private static func getVO2Thresholds(age: Int, isMale: Bool) -> (poor: Double, belowAverage: Double, good: Double) {
        if isMale {
            switch age {
            case 0..<30:   return (poor: 30, belowAverage: 38, good: 45)
            case 30..<40:  return (poor: 28, belowAverage: 36, good: 42)
            case 40..<50:  return (poor: 26, belowAverage: 34, good: 40)
            case 50..<60:  return (poor: 24, belowAverage: 32, good: 38)
            default:       return (poor: 22, belowAverage: 30, good: 36)
            }
        } else {
            switch age {
            case 0..<30:   return (poor: 26, belowAverage: 34, good: 41)
            case 30..<40:  return (poor: 24, belowAverage: 32, good: 38)
            case 40..<50:  return (poor: 22, belowAverage: 30, good: 36)
            case 50..<60:  return (poor: 20, belowAverage: 28, good: 34)
            default:       return (poor: 18, belowAverage: 26, good: 32)
            }
        }
    }
    
    // MARK: - Helper: HRV Baseline by Age/Gender
    private static func getHRVBaseline(age: Int, isMale: Bool) -> Double {
        if isMale {
            switch age {
            case 0..<30:   return 62.0
            case 30..<40:  return 56.0
            case 40..<50:  return 48.0
            case 50..<60:  return 42.0
            default:       return 38.0
            }
        } else {
            switch age {
            case 0..<30:   return 68.0
            case 30..<40:  return 62.0
            case 40..<50:  return 54.0
            case 50..<60:  return 48.0
            default:       return 44.0
            }
        }
    }
}

// MARK: - Deficiency Level Enum
enum DeficiencyLevel: String, Codable {
    case critical = "Critical"
    case deficient = "Deficient"
    case adequate = "Adequate"
    case optimal = "Optimal"
    case excessive = "Excessive"
    case unknown = "Unknown"
    
    var needsIntervention: Bool {
        return self == .critical || self == .deficient
    }
    
    var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .deficient: return "🟡"
        case .adequate: return "✅"
        case .optimal: return "💚"
        case .excessive: return "⚠️"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Priority Assessment
struct PriorityAssessment {
    let metric: String
    let level: DeficiencyLevel
    let priority: Int
    let reasoning: String
    let currentValue: String?
    let targetValue: String?
}

// MARK: - Data Availability Tracking
struct MetricAvailability {
    let totalMetrics: Int
    let availableMetrics: Int
    let unknownMetrics: [String]
    
    var completeness: Double {
        Double(availableMetrics) / Double(totalMetrics)
    }
    
    var hasMinimumData: Bool {
        availableMetrics >= 2
    }
    
    var completenessLevel: String {
        if completeness >= 0.7 { return "High" }
        if completeness >= 0.4 { return "Medium" }
        return "Low"
    }
}

// MARK: - Contextual Modifier (for nuanced AI decisions)
struct ContextualModifier {
    let description: String
    let impactLevel: String  // "mitigating", "neutral", "compounding"
}

// MARK: - Comprehensive Priority Determination
extension DeficiencyAssessment {
    
    static func determinePriorities(
        sleepHours: Double?,
        proteinGrams: Double?,
        bodyWeight: Double?,
        vo2Max: Double?,
        hrv: Double?,
        rhr: Double?,
        steps: Double?,
        activityLevel: String?,
        age: Int,
        isMale: Bool,
        primaryGoal: String
    ) -> [PriorityAssessment] {
        
        var priorities: [PriorityAssessment] = []
        
        // Assess all metrics
        let sleepLevel = assessSleep(averageHours: sleepHours)
        let proteinLevel = assessProtein(dailyGrams: proteinGrams, bodyWeight: bodyWeight)
        let vo2Level = assessVO2Max(value: vo2Max, age: age, isMale: isMale)
        let hrvLevel = assessHRV(value: hrv, age: age, isMale: isMale)
        let rhrLevel = assessRHR(value: rhr)
        let stepsLevel = assessSteps(dailyAverage: steps)
        let activityLevelStatus = activityLevel != nil ? assessActivityLevel(activityLevel!) : .unknown
        
        // 1. SLEEP - Always Priority #1 if deficient
        if sleepLevel.needsIntervention {
            let sleepValue = sleepHours != nil ? String(format: "%.1f hours", sleepHours!) : "Unknown"
            priorities.append(PriorityAssessment(
                metric: "Sleep",
                level: sleepLevel,
                priority: 1,
                reasoning: sleepLevel == .critical ? 
                    "Critical sleep deficiency. Everything else depends on adequate sleep." :
                    "Sleep below optimal range. Improving sleep will enhance all other metrics.",
                currentValue: sleepValue,
                targetValue: "7-8 hours"
            ))
        }
        
        // 2. PROTEIN - Priority if critical OR deficient + relevant goal
        let proteinRelevantGoals = ["lose_weight", "look_better", "live_longer", "get_stronger", "build_muscle"]
        let goalNormalized = primaryGoal.lowercased().replacingOccurrences(of: " ", with: "_")
        
        if proteinLevel == .critical || 
           (proteinLevel == .deficient && proteinRelevantGoals.contains(goalNormalized)) {
            let proteinValue = proteinGrams != nil && bodyWeight != nil ? 
                String(format: "%.0fg/day (%.1fg/lb)", proteinGrams!, proteinGrams! / bodyWeight!) : "Unknown"
            let targetProtein = bodyWeight != nil ? String(format: "%.0fg/day (0.8g/lb)", bodyWeight! * 0.8) : "0.8g/lb"
            
            priorities.append(PriorityAssessment(
                metric: "Protein",
                level: proteinLevel,
                priority: proteinLevel == .critical ? 1 : 2,
                reasoning: proteinLevel == .critical ?
                    "Critical protein deficiency. At risk of muscle loss, especially during weight loss." :
                    "Protein intake below optimal. Adequate protein supports your goal and preserves muscle mass.",
                currentValue: proteinValue,
                targetValue: targetProtein
            ))
        }
        
        // 3. ACTIVITY LEVEL - If sedentary, movement is critical
        if activityLevelStatus == .critical || activityLevelStatus == .deficient {
            priorities.append(PriorityAssessment(
                metric: "Movement/Activity",
                level: activityLevelStatus,
                priority: 2,
                reasoning: activityLevelStatus == .critical ?
                    "Sedentary lifestyle is a major health risk. Starting regular movement is essential." :
                    "Activity level is inconsistent. Building regular training habits is the next step.",
                currentValue: activityLevel ?? "Sedentary",
                targetValue: "Regular training 2-3x/week minimum"
            ))
        }
        
        // 4. STEPS - Daily movement deficiency
        if stepsLevel.needsIntervention {
            let stepsValue = steps != nil ? String(format: "%.0f steps/day", steps!) : "Unknown"
            priorities.append(PriorityAssessment(
                metric: "Daily Steps",
                level: stepsLevel,
                priority: stepsLevel == .critical ? 2 : 3,
                reasoning: stepsLevel == .critical ?
                    "Very low daily movement (<5,000 steps). This is a major health risk independent of exercise." :
                    "Daily steps below optimal. Increasing NEAT (non-exercise activity) improves metabolic health.",
                currentValue: stepsValue,
                targetValue: "7,500-10,000 steps/day"
            ))
        }
        
        // 5. VO2 MAX / CARDIO FITNESS
        if vo2Level.needsIntervention {
            let vo2Value = vo2Max != nil ? String(format: "%.1f ml/kg/min", vo2Max!) : "Unknown"
            priorities.append(PriorityAssessment(
                metric: "Cardiovascular Fitness",
                level: vo2Level,
                priority: vo2Level == .critical ? 2 : 3,
                reasoning: vo2Level == .critical ?
                    "VO2 Max is critically low. This is the strongest predictor of longevity - must be addressed." :
                    "VO2 Max below average for age/gender. Improving cardiovascular fitness significantly reduces mortality risk.",
                currentValue: vo2Value,
                targetValue: "Age/gender-adjusted average range"
            ))
        }
        
        // 6. HRV / RECOVERY
        if hrvLevel.needsIntervention {
            let hrvValue = hrv != nil ? String(format: "%.0f ms", hrv!) : "Unknown"
            priorities.append(PriorityAssessment(
                metric: "Recovery/Stress Management",
                level: hrvLevel,
                priority: 3,
                reasoning: "HRV indicates poor recovery capacity. This suggests chronic stress, overtraining, or insufficient recovery.",
                currentValue: hrvValue,
                targetValue: "Age/gender-adjusted baseline"
            ))
        }
        
        // 7. RHR / CARDIOVASCULAR HEALTH
        if rhrLevel.needsIntervention {
            let rhrValue = rhr != nil ? String(format: "%.0f bpm", rhr!) : "Unknown"
            priorities.append(PriorityAssessment(
                metric: "Resting Heart Rate",
                level: rhrLevel,
                priority: rhrLevel == .critical ? 1 : 3,
                reasoning: rhrLevel == .critical ?
                    "Elevated resting heart rate (>85 bpm) indicates cardiovascular stress. Medical evaluation recommended alongside lifestyle intervention." :
                    "Resting heart rate above optimal. Improving cardiovascular fitness will lower RHR.",
                currentValue: rhrValue,
                targetValue: "60-70 bpm"
            ))
        }
        
        return priorities.sorted { 
            if $0.priority == $1.priority {
                if $0.level == .critical && $1.level != .critical {
                    return true
                }
                return false
            }
            return $0.priority < $1.priority
        }
    }
    
    // MARK: - Check Data Availability
    static func checkDataAvailability(
        sleepHours: Double?,
        proteinGrams: Double?,
        vo2Max: Double?,
        hrv: Double?,
        rhr: Double?,
        steps: Double?
    ) -> MetricAvailability {
        
        var available = 0
        var unknown: [String] = []
        
        if sleepHours != nil { available += 1 } else { unknown.append("Sleep") }
        if proteinGrams != nil { available += 1 } else { unknown.append("Protein") }
        if vo2Max != nil { available += 1 } else { unknown.append("VO2 Max") }
        if hrv != nil { available += 1 } else { unknown.append("HRV") }
        if rhr != nil { available += 1 } else { unknown.append("RHR") }
        if steps != nil { available += 1 } else { unknown.append("Steps") }
        
        return MetricAvailability(
            totalMetrics: 6,
            availableMetrics: available,
            unknownMetrics: unknown
        )
    }
    
    // MARK: - Build Contextual Modifiers
    static func buildContextualModifiers(
        sleepHours: Double?,
        sleepLevel: DeficiencyLevel,
        hrv: Double?,
        hrvLevel: DeficiencyLevel,
        rhr: Double?,
        rhrLevel: DeficiencyLevel,
        age: Int,
        isMale: Bool
    ) -> [String: [ContextualModifier]] {
        
        var modifiers: [String: [ContextualModifier]] = [:]
        
        // Sleep context
        if sleepLevel == .deficient {
            var sleepMods: [ContextualModifier] = []
            
            if hrvLevel == .optimal && rhrLevel == .optimal {
                sleepMods.append(ContextualModifier(
                    description: "Recovery metrics (HRV \(String(format: "%.0f", hrv ?? 0))ms, RHR \(String(format: "%.0f", rhr ?? 0))bpm) are excellent despite borderline sleep duration",
                    impactLevel: "mitigating"
                ))
            }
            
            if let hours = sleepHours, hours >= 6.5 {
                sleepMods.append(ContextualModifier(
                    description: "Sleep duration (\(String(format: "%.1f", hours))h) is close to 7h threshold - marginal deficiency",
                    impactLevel: "mitigating"
                ))
            }
            
            if !sleepMods.isEmpty {
                modifiers["Sleep"] = sleepMods
            }
        }
        
        // HRV context
        if hrvLevel == .deficient && sleepLevel == .critical {
            modifiers["HRV"] = [ContextualModifier(
                description: "Low HRV likely caused by severe sleep deprivation - addressing sleep should improve HRV",
                impactLevel: "compounding"
            )]
        }
        
        return modifiers
    }
    
    // MARK: - Build Context String for AI
    static func buildContextString(
        deficiencies: [PriorityAssessment],
        modifiers: [String: [ContextualModifier]]
    ) -> String {
        if deficiencies.isEmpty {
            return """
            ✅ ALL METRICS IN ADEQUATE OR OPTIMAL RANGE
            
            No critical deficiencies detected. Focus on:
            - Maintaining current practices
            - Progressive overload in training
            - Optimizing already-adequate metrics toward optimal range
            """
        }
        
        return deficiencies.enumerated().map { index, assessment in
            var assessmentString = """
            \(assessment.level.emoji) Priority #\(index + 1): \(assessment.metric)
               Status: \(assessment.level.rawValue)
               Current: \(assessment.currentValue ?? "Unknown")
               Target: \(assessment.targetValue ?? "To be determined")
               Reason: \(assessment.reasoning)
            """
            
            // Add contextual modifiers if they exist
            if let mods = modifiers[assessment.metric], !mods.isEmpty {
                assessmentString += "\n           Context:"
                for mod in mods {
                    assessmentString += "\n           • \(mod.description)"
                }
            }
            
            // Add AI decision guidance
            if assessment.level == .critical {
                assessmentString += "\n           ⚠️ MANDATORY INTERVENTION - Must prescribe regardless of other factors"
            } else if !modifiers[assessment.metric, default: []].isEmpty {
                assessmentString += "\n           💡 AI DECISION REQUIRED - Consider context when prioritizing"
            }
            
            return assessmentString
        }.joined(separator: "\n\n")
    }
    
    // MARK: - Build Adequate Metrics Context
    static func buildAdequateMetricsContext(
        sleepHours: Double?,
        proteinGrams: Double?,
        bodyWeight: Double?,
        vo2Max: Double?,
        hrv: Double?,
        rhr: Double?,
        steps: Double?,
        activityLevel: String?,
        age: Int,
        isMale: Bool
    ) -> String {
        
        var adequateMetrics: [String] = []
        
        let sleepLevel = assessSleep(averageHours: sleepHours)
        if sleepLevel == .adequate || sleepLevel == .optimal {
            let hours = sleepHours != nil ? String(format: "%.1f hours", sleepHours!) : "adequate"
            adequateMetrics.append("✅ Sleep: \(hours) - DO NOT prescribe sleep optimization")
        }
        
        let proteinLevel = assessProtein(dailyGrams: proteinGrams, bodyWeight: bodyWeight)
        if proteinLevel == .adequate || proteinLevel == .optimal {
            let intake = proteinGrams != nil && bodyWeight != nil ? 
                String(format: "%.0fg (%.1fg/lb)", proteinGrams!, proteinGrams! / bodyWeight!) : "adequate"
            adequateMetrics.append("✅ Protein: \(intake) - DO NOT prescribe protein tracking")
        }
        
        let vo2Level = assessVO2Max(value: vo2Max, age: age, isMale: isMale)
        if vo2Level == .adequate || vo2Level == .optimal {
            let vo2Value = vo2Max != nil ? String(format: "%.1f ml/kg/min", vo2Max!) : "adequate"
            adequateMetrics.append("✅ VO2 Max: \(vo2Value) - Maintain, don't overhaul cardio")
        }
        
        let hrvLevel = assessHRV(value: hrv, age: age, isMale: isMale)
        if hrvLevel == .adequate || hrvLevel == .optimal {
            let hrvValue = hrv != nil ? String(format: "%.0f ms", hrv!) : "adequate"
            adequateMetrics.append("✅ HRV: \(hrvValue) - Recovery capacity is good")
        }
        
        let rhrLevel = assessRHR(value: rhr)
        if rhrLevel == .adequate || rhrLevel == .optimal {
            let rhrValue = rhr != nil ? String(format: "%.0f bpm", rhr!) : "adequate"
            adequateMetrics.append("✅ RHR: \(rhrValue) - Cardiovascular health is good")
        }
        
        let stepsLevel = assessSteps(dailyAverage: steps)
        if stepsLevel == .adequate || stepsLevel == .optimal {
            let stepsValue = steps != nil ? String(format: "%.0f steps/day", steps!) : "adequate"
            adequateMetrics.append("✅ Daily Steps: \(stepsValue) - Good baseline activity")
        }
        
        let activityLevelStatus = activityLevel != nil ? assessActivityLevel(activityLevel!) : .unknown
        if activityLevelStatus == .adequate || activityLevelStatus == .optimal {
            adequateMetrics.append("✅ Activity Level: \(activityLevel ?? "Regular") - Training consistency established")
        }
        
        if adequateMetrics.isEmpty {
            return "No metrics currently in adequate range."
        }
        
        return """
        CELEBRATE THESE - DO NOT PRESCRIBE HABITS FOR THEM:
        
        \(adequateMetrics.joined(separator: "\n"))
        """
    }
}