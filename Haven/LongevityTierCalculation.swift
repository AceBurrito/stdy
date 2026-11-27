import Foundation
import SwiftData

// MARK: - Activity Level Enum

enum ActivityLevel: String, CaseIterable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        }
    }
}

// MARK: - Baseline Inference (for missing biomarker data)

struct BaselineInference {
    let bmi: Double
    let activityLevel: ActivityLevel
    let age: Int
    let gender: String?
    let sleepSelfReport: Double? // hours per night
    
    // Infer VO2 Max percentile (35% weight) based on BMI and activity level
    func inferredVO2MaxPercentile() -> Int {
        var baseline = 50
        
        // BMI impact (cardio fitness highly correlated with body composition)
        if bmi > 35 { baseline -= 25 }
        else if bmi > 30 { baseline -= 20 }
        else if bmi > 27 { baseline -= 12 }
        else if bmi < 22 { baseline += 5 }
        
        // Activity level impact
        switch activityLevel {
        case .sedentary: baseline -= 20
        case .lightlyActive: baseline -= 8
        case .moderatelyActive: baseline += 5
        case .veryActive: baseline += 15
        }
        
        // Age penalty for sedentary older adults (VO2 Max declines faster with inactivity)
        if age > 50 && activityLevel == .sedentary {
            baseline -= 10
        }
        
        return max(10, min(90, baseline))
    }
    
    // Infer RHR percentile (8% weight) based on BMI and activity level
    func inferredRHRPercentile() -> Int {
        var rhr = 70 // baseline RHR in bpm
        
        // BMI impact (higher BMI = higher RHR)
        if bmi > 35 { rhr += 15 }
        else if bmi > 30 { rhr += 12 }
        else if bmi > 27 { rhr += 7 }
        
        // Activity level impact (training lowers RHR)
        switch activityLevel {
        case .sedentary: rhr += 10
        case .lightlyActive: rhr += 5
        case .moderatelyActive: rhr -= 2
        case .veryActive: rhr -= 10
        }
        
        // Convert RHR to percentile (lower is better)
        return LongevityTierCalculation.calculateRHRPercentile(rhr: Double(rhr)) ?? 50
    }
    
    // Infer HRV percentile (12% weight) based on BMI, activity, and age
    func inferredHRVPercentile() -> Int {
        var baseline = 50
        
        // BMI impact (obesity linked to inflammation and poor recovery)
        if bmi > 30 { baseline -= 15 }
        else if bmi > 27 { baseline -= 8 }
        
        // Activity level (training improves HRV)
        switch activityLevel {
        case .sedentary: baseline -= 15
        case .lightlyActive: baseline -= 5
        case .moderatelyActive: baseline += 5
        case .veryActive: baseline += 10
        }
        
        // Age impact (HRV naturally declines with age)
        if age > 60 { baseline -= 10 }
        else if age > 50 { baseline -= 5 }
        
        return max(15, min(85, baseline))
    }
    
    // Infer Sleep Score (20% weight) from self-report
    func inferredSleepScore() -> Int? {
        // If they self-reported hours, use that
        if let hours = sleepSelfReport {
            return LongevityTierCalculation.calculateSleepScore(
                avgHours: hours,
                consistency: nil // can't infer consistency without tracking data
            )
        }
        
        // Otherwise, assume slightly below optimal (we have no data)
        return 60
    }
    
    // Validation: Should we allow self-reported strength without performance data?
    func shouldAllowSelfReportedStrength() -> Bool {
        // Don't allow "I'm strong" claims if clearly contradicted by other data
        if bmi > 32 { return false } // Significantly overweight + no data = can't trust claim
        if activityLevel == .sedentary { return false } // Sedentary + no data = unlikely to be strong
        return true
    }
    
    // Cap self-reported strength claims (we don't have actual performance data)
    func maxAllowedSelfReportedStrengthPercentile() -> Int {
        if bmi > 30 { return 40 } // Overweight users likely not above 40th percentile
        if age > 50 && activityLevel != .veryActive { return 45 }
        return 55 // Never trust above-average claims without actual data
    }
}

// MARK: - Longevity Tier Calculation

struct LongevityTierCalculation {
    
    // MARK: - Tier Definitions
    enum LongevityTier: String, CaseIterable {
        case atRisk = "at_risk"
        case rising = "rising"
        case phoenix = "phoenix"
        case optimal = "optimal"
        case elite = "elite"
        
        var displayName: String {
            switch self {
            case .atRisk: return "At Risk"
            case .rising: return "Rising"
            case .phoenix: return "Phoenix"
            case .optimal: return "Optimal"
            case .elite: return "Elite"
            }
        }
        
        var percentileRange: String {
            switch self {
            case .atRisk: return "Bottom 50%"
            case .rising: return "50-70th percentile"
            case .phoenix: return "70-85th percentile"
            case .optimal: return "85-95th percentile"
            case .elite: return "Top 5%"
            }
        }
        
        var description: String {
            switch self {
            case .atRisk:
                return "Your biomarkers place you at elevated risk. This is your starting point - most people never measure this. Now let's change it."
            case .rising:
                return "You're above average and building momentum. The foundation is forming. Keep pushing toward Phoenix."
            case .phoenix:
                return "You've transformed. Top 30% for longevity markers. This is what rising from the ashes looks like."
            case .optimal:
                return "Longevity-optimized. Top 15%. Your biomarkers predict a long, healthy life. Now maintain and refine."
            case .elite:
                return "Rare air. Top 5% of humans for longevity metrics. You've built something exceptional."
            }
        }
        
        var urgencyMessage: String {
            switch self {
            case .atRisk:
                return "Research shows this range carries 2-5x higher mortality risk compared to optimal levels. The good news: these metrics are trainable."
            case .rising:
                return "You're moving in the right direction. Consistent effort over the next 12 weeks can push you into Phoenix territory."
            case .phoenix:
                return "You've crossed a major threshold. From here, it's optimization, not transformation."
            case .optimal:
                return "Maintenance is the game now. Protect what you've built."
            case .elite:
                return "You're operating at peak human performance. Sustain it."
            }
        }
    }
    
    // MARK: - Calculation Result
    struct TierResult {
        let tier: LongevityTier
        let percentile: Int
        let componentScores: ComponentScores
        let missingComponents: [MissingComponent]
        let inferredComponents: [String] // NEW: Track what was inferred vs measured
        let limitingFactor: String?
        let primaryRecommendation: String?
        let isComplete: Bool
        
        var completenessPercentage: Int {
            let totalWeight = 100
            let missingWeight = missingComponents.reduce(0) { $0 + $1.weight }
            return totalWeight - missingWeight
        }
        
        var hasInferredData: Bool {
            !inferredComponents.isEmpty
        }
    }
    
    struct ComponentScores {
        let vo2MaxPercentile: Int?
        let strengthPercentile: Int?
        let sleepScore: Int?
        let hrvPercentile: Int?
        let rhrPercentile: Int?
        
        var availableScores: [(name: String, percentile: Int, weight: Int)] {
            var scores: [(String, Int, Int)] = []
            if let vo2 = vo2MaxPercentile { scores.append(("VO2 Max", vo2, 35)) }
            if let strength = strengthPercentile { scores.append(("Strength", strength, 25)) }
            if let sleep = sleepScore { scores.append(("Sleep", sleep, 20)) }
            if let hrv = hrvPercentile { scores.append(("HRV", hrv, 12)) }
            if let rhr = rhrPercentile { scores.append(("RHR", rhr, 8)) }
            return scores
        }
        
        var lowestComponent: String? {
            availableScores.min(by: { $0.percentile < $1.percentile })?.name
        }
    }
    
    struct MissingComponent {
        let name: String
        let weight: Int
        let message: String
        let actionPrompt: String
    }
    
    // MARK: - Strength Input Types
    struct StrengthInput {
        // From logged workouts
        var benchPressMax: Double?
        var squatMax: Double?
        var deadliftMax: Double?
        
        // From assessment questions
        var pushupRange: PushupRange?
        var deadHangRange: DeadHangRange?
        var canStandFromSitting: Bool? 
        
        // From training consistency (fallback)
        var strengthTrainingDaysPerWeek: Int?
        
        var hasLoggedLifts: Bool {
            benchPressMax != nil || squatMax != nil || deadliftMax != nil
        }
        
        var hasAssessmentData: Bool {
            pushupRange != nil || deadHangRange != nil || canStandFromSitting != nil
        }
        
        var hasAnyData: Bool {
            hasLoggedLifts || hasAssessmentData || (strengthTrainingDaysPerWeek ?? 0) > 0
        }
    }
    
    enum PushupRange: String, CaseIterable {
        case zeroToFive = "0-5"
        case sixToFifteen = "6-15"
        case sixteenToThirty = "16-30"
        case thirtyOneToFifty = "31-50"
        case fiftyPlus = "50+"
        
        func percentile(age: Int, isMale: Bool) -> Int {
            if isMale {
                if age < 40 {
                    switch self {
                    case .zeroToFive: return 15
                    case .sixToFifteen: return 35
                    case .sixteenToThirty: return 55
                    case .thirtyOneToFifty: return 75
                    case .fiftyPlus: return 90
                    }
                } else if age < 60 {
                    switch self {
                    case .zeroToFive: return 25
                    case .sixToFifteen: return 45
                    case .sixteenToThirty: return 65
                    case .thirtyOneToFifty: return 85
                    case .fiftyPlus: return 95
                    }
                } else {
                    switch self {
                    case .zeroToFive: return 35
                    case .sixToFifteen: return 55
                    case .sixteenToThirty: return 75
                    case .thirtyOneToFifty: return 90
                    case .fiftyPlus: return 97
                    }
                }
            } else {
                if age < 40 {
                    switch self {
                    case .zeroToFive: return 20
                    case .sixToFifteen: return 45
                    case .sixteenToThirty: return 65
                    case .thirtyOneToFifty: return 85
                    case .fiftyPlus: return 95
                    }
                } else if age < 60 {
                    switch self {
                    case .zeroToFive: return 30
                    case .sixToFifteen: return 55
                    case .sixteenToThirty: return 75
                    case .thirtyOneToFifty: return 90
                    case .fiftyPlus: return 97
                    }
                } else {
                    switch self {
                    case .zeroToFive: return 40
                    case .sixToFifteen: return 65
                    case .sixteenToThirty: return 85
                    case .thirtyOneToFifty: return 95
                    case .fiftyPlus: return 99
                    }
                }
            }
        }
    }
    
    enum DeadHangRange: String, CaseIterable {
        case cantDoIt = "cant"
        case underFifteen = "under_15"
        case fifteenToThirty = "15-30"
        case thirtyToSixty = "30-60"
        case sixtyPlus = "60+"
        
        var percentile: Int? {
            switch self {
            case .cantDoIt: return nil  // Exclude from calculation
            case .underFifteen: return 25
            case .fifteenToThirty: return 45
            case .thirtyToSixty: return 65
            case .sixtyPlus: return 85
            }
        }
        
        var displayText: String {
            switch self {
            case .cantDoIt: return "Can't do it / No access to bar"
            case .underFifteen: return "Under 15 seconds"
            case .fifteenToThirty: return "15-30 seconds"
            case .thirtyToSixty: return "30-60 seconds"
            case .sixtyPlus: return "60+ seconds"
            }
        }
    }

    // Sit-to-stand assessment (predictor of mortality in older adults)
    static func sitToStandPercentile(canStand: Bool, age: Int) -> Int {
        if !canStand {
            // Unable to stand without hands is a major red flag
            return age < 50 ? 10 : 20  // Worse for younger people
        } else {
            // Able to stand indicates good functional strength
            return age < 50 ? 60 : 75  // Better for older people
        }
    }
    
    // MARK: - Main Calculation
    
    static func calculate(
        age: Int,
        gender: String?,
        bodyweight: Double?,
        vo2Max: Double?,
        strengthInput: StrengthInput,
        sleepAverage: Double?,
        sleepConsistency: Double?,
        hrv: Double?,
        rhr: Double?,
        // NEW: Baseline inference data
        height: Double?,
        activityLevel: ActivityLevel?,
        sleepSelfReport: Double?
    ) -> TierResult {
        
        let isMale = gender?.lowercased().contains("male") ?? true
        var missingComponents: [MissingComponent] = []
        var inferredComponents: [String] = [] // Track what we inferred
        
        // Calculate BMI if we have height and weight
        let bmi: Double? = {
            guard let weight = bodyweight, let height = height, height > 0 else { return nil }
            return weight / pow(height, 2) * 703 // imperial formula (lbs / inches^2 * 703)
        }()
        
        // Create baseline inference engine
        let baselineInference: BaselineInference? = {
            guard let bmi = bmi, let activity = activityLevel else { return nil }
            return BaselineInference(
                bmi: bmi,
                activityLevel: activity,
                age: age,
                gender: gender,
                sleepSelfReport: sleepSelfReport
            )
        }()
        
        // Calculate VO2 Max (35% weight)
        let vo2Percentile: Int?
        if let vo2 = vo2Max {
            vo2Percentile = calculateVO2MaxPercentile(vo2Max: vo2, age: age, gender: gender)
        } else if let inference = baselineInference {
            vo2Percentile = inference.inferredVO2MaxPercentile()
            inferredComponents.append("VO2 Max")
        } else {
            vo2Percentile = nil
            missingComponents.append(MissingComponent(
                name: "VO2 Max",
                weight: 35,
                message: "VO2 Max is the strongest predictor of longevity. This accounts for 35% of your score.",
                actionPrompt: "Sync a fitness tracker or complete a VO2 Max test."
            ))
        }
        
        // Calculate Strength (25% weight)
        let strengthPercentile = calculateStrengthPercentile(
            input: strengthInput,
            bodyweight: bodyweight,
            age: age,
            isMale: isMale,
            baselineInference: baselineInference
        )
        if strengthPercentile == nil {
            missingComponents.append(MissingComponent(
                name: "Strength",
                weight: 25,
                message: "Strength is the second strongest predictor of longevity.",
                actionPrompt: "Complete the strength assessment."
            ))
        }
        
        // Calculate Sleep (20% weight)
        let sleepScore: Int?
        if let sleepAvg = sleepAverage {
            sleepScore = calculateSleepScore(avgHours: sleepAvg, consistency: sleepConsistency)
        } else if let inference = baselineInference {
            sleepScore = inference.inferredSleepScore()
            if sleepScore != nil {
                inferredComponents.append("Sleep")
            }
        } else {
            sleepScore = nil
            missingComponents.append(MissingComponent(
                name: "Sleep",
                weight: 20,
                message: "Sleep is the foundation for recovery and adaptation.",
                actionPrompt: "Connect Apple Health to track sleep automatically."
            ))
        }
        
        // Calculate HRV (12% weight)
        let hrvPercentile: Int?
        if let hrvValue = hrv {
            hrvPercentile = calculateHRVPercentile(hrv: hrvValue, age: age)
        } else if let inference = baselineInference {
            hrvPercentile = inference.inferredHRVPercentile()
            inferredComponents.append("HRV")
        } else {
            hrvPercentile = nil
            missingComponents.append(MissingComponent(
                name: "HRV",
                weight: 12,
                message: "Heart Rate Variability indicates recovery capacity.",
                actionPrompt: "Sync a device that tracks HRV (Apple Watch, Oura, Whoop)."
            ))
        }
        
        // Calculate RHR (8% weight)
        let rhrPercentile: Int?
        if let rhrValue = rhr {
            rhrPercentile = calculateRHRPercentile(rhr: rhrValue)
        } else if let inference = baselineInference {
            rhrPercentile = inference.inferredRHRPercentile()
            inferredComponents.append("RHR")
        } else {
            rhrPercentile = nil
            missingComponents.append(MissingComponent(
                name: "Resting Heart Rate",
                weight: 8,
                message: "Resting heart rate indicates cardiovascular efficiency.",
                actionPrompt: "Sync a device that tracks resting heart rate."
            ))
        }
        
        // Build component scores
        let componentScores = ComponentScores(
            vo2MaxPercentile: vo2Percentile,
            strengthPercentile: strengthPercentile,
            sleepScore: sleepScore,
            hrvPercentile: hrvPercentile,
            rhrPercentile: rhrPercentile
        )
        
        // Calculate overall percentile
        let overallPercentile = calculateOverallPercentile(scores: componentScores)
        let tier = tierFromPercentile(overallPercentile)
        
        // Generate recommendation
        let limitingFactor = componentScores.lowestComponent
        let recommendation = generateRecommendation(
            limitingFactor: limitingFactor,
            componentScores: componentScores,
            missingComponents: missingComponents
        )
        
        return TierResult(
            tier: tier,
            percentile: overallPercentile,
            componentScores: componentScores,
            missingComponents: missingComponents,
            inferredComponents: inferredComponents,
            limitingFactor: limitingFactor,
            primaryRecommendation: recommendation,
            isComplete: missingComponents.isEmpty
        )
    }
    

    
    // MARK: - Strength Percentile Calculation (UPDATED)

    static func calculateStrengthPercentile(
        input: StrengthInput,
        bodyweight: Double?,
        age: Int,
        isMale: Bool,
        baselineInference: BaselineInference? // NEW
    ) -> Int? {
        
        // Priority 1: Calculate from logged lifts (most accurate)
        if input.hasLoggedLifts, let bw = bodyweight, bw > 0 {
            var liftPercentiles: [Int] = []
            
            if let bench = input.benchPressMax {
                let ratio = bench / bw
                liftPercentiles.append(benchPressPercentile(ratio: ratio, isMale: isMale))
            }
            
            if let squat = input.squatMax {
                let ratio = squat / bw
                liftPercentiles.append(squatPercentile(ratio: ratio, isMale: isMale))
            }
            
            if let deadlift = input.deadliftMax {
                let ratio = deadlift / bw
                liftPercentiles.append(deadliftPercentile(ratio: ratio, isMale: isMale))
            }
            
            if !liftPercentiles.isEmpty {
                return liftPercentiles.reduce(0, +) / liftPercentiles.count
            }
        }
        
        // Priority 2: Calculate from assessment questions
        if input.hasAssessmentData {
            var assessmentPercentiles: [Int] = []
            
            if let pushups = input.pushupRange {
                assessmentPercentiles.append(pushups.percentile(age: age, isMale: isMale))
            }
            
            if let deadHang = input.deadHangRange, let percentile = deadHang.percentile {
                assessmentPercentiles.append(percentile)
            }

            if let canStand = input.canStandFromSitting {
                assessmentPercentiles.append(sitToStandPercentile(canStand: canStand, age: age))
            }
            
            if !assessmentPercentiles.isEmpty {
                return assessmentPercentiles.reduce(0, +) / assessmentPercentiles.count
            }
        }
        
        // Priority 3: Self-reported training frequency (heavily validated against baseline)
        if let trainingDays = input.strengthTrainingDaysPerWeek, trainingDays > 0 {
            
            // Check if we should even allow self-reported strength
            if let baseline = baselineInference {
                if !baseline.shouldAllowSelfReportedStrength() {
                    // Clear contradiction - return low percentile based on baseline
                    return 20
                }
                
                // Cap the claim based on other observable data
                let claimedPercentile = min(trainingDays * 15, 70) // 2 days = 30th, 3+ = 45-70th
                let maxAllowed = baseline.maxAllowedSelfReportedStrengthPercentile()
                return min(claimedPercentile, maxAllowed)
            }
            
            // No baseline data, give moderate credit but cap it
            return min(trainingDays * 15, 55)
        }
        
        // Priority 4: No strength data at all
        return nil
    }
    
    // MARK: - Relative Strength Percentiles
    
    static func benchPressPercentile(ratio: Double, isMale: Bool) -> Int {
        if isMale {
            switch ratio {
            case ..<0.5: return 15
            case 0.5..<0.75: return 30
            case 0.75..<1.0: return 50
            case 1.0..<1.25: return 70
            case 1.25..<1.5: return 85
            default: return 95
            }
        } else {
            switch ratio {
            case ..<0.25: return 15
            case 0.25..<0.5: return 35
            case 0.5..<0.75: return 55
            case 0.75..<1.0: return 75
            case 1.0..<1.25: return 90
            default: return 97
            }
        }
    }
    
    static func squatPercentile(ratio: Double, isMale: Bool) -> Int {
        if isMale {
            switch ratio {
            case ..<0.75: return 15
            case 0.75..<1.0: return 30
            case 1.0..<1.5: return 50
            case 1.5..<2.0: return 70
            case 2.0..<2.5: return 85
            default: return 95
            }
        } else {
            switch ratio {
            case ..<0.5: return 15
            case 0.5..<0.75: return 35
            case 0.75..<1.25: return 55
            case 1.25..<1.75: return 75
            case 1.75..<2.25: return 90
            default: return 97
            }
        }
    }
    
    static func deadliftPercentile(ratio: Double, isMale: Bool) -> Int {
        if isMale {
            switch ratio {
            case ..<1.0: return 15
            case 1.0..<1.25: return 30
            case 1.25..<1.75: return 50
            case 1.75..<2.25: return 70
            case 2.25..<2.75: return 85
            default: return 95
            }
        } else {
            switch ratio {
            case ..<0.75: return 15
            case 0.75..<1.0: return 35
            case 1.0..<1.5: return 55
            case 1.5..<2.0: return 75
            case 2.0..<2.5: return 90
            default: return 97
            }
        }
    }
    
    // MARK: - VO2 Max Percentile
    
    static func calculateVO2MaxPercentile(vo2Max: Double?, age: Int, gender: String?) -> Int? {
        guard let vo2 = vo2Max, vo2 > 0 else { return nil }
        
        let isMale = gender?.lowercased().contains("male") ?? true
        
        let thresholds: (p20: Double, p40: Double, p60: Double, p80: Double, p95: Double)
        
        if isMale {
            switch age {
            case ..<30: thresholds = (38, 42, 46, 51, 58)
            case 30..<40: thresholds = (35, 39, 43, 48, 55)
            case 40..<50: thresholds = (32, 36, 40, 45, 52)
            case 50..<60: thresholds = (29, 33, 37, 42, 49)
            case 60..<70: thresholds = (26, 30, 34, 39, 46)
            default: thresholds = (23, 27, 31, 36, 43)
            }
        } else {
            switch age {
            case ..<30: thresholds = (30, 34, 38, 43, 50)
            case 30..<40: thresholds = (28, 32, 36, 40, 47)
            case 40..<50: thresholds = (26, 30, 34, 38, 45)
            case 50..<60: thresholds = (24, 28, 32, 36, 42)
            case 60..<70: thresholds = (22, 26, 30, 34, 40)
            default: thresholds = (20, 24, 28, 32, 38)
            }
        }
        
        if vo2 >= thresholds.p95 { return 97 }
        if vo2 >= thresholds.p80 { return Int(80 + (vo2 - thresholds.p80) / (thresholds.p95 - thresholds.p80) * 15) }
        if vo2 >= thresholds.p60 { return Int(60 + (vo2 - thresholds.p60) / (thresholds.p80 - thresholds.p60) * 20) }
        if vo2 >= thresholds.p40 { return Int(40 + (vo2 - thresholds.p40) / (thresholds.p60 - thresholds.p40) * 20) }
        if vo2 >= thresholds.p20 { return Int(20 + (vo2 - thresholds.p20) / (thresholds.p40 - thresholds.p20) * 20) }
        return max(5, Int(vo2 / thresholds.p20 * 20))
    }
    
    // MARK: - HRV Percentile
    
    static func calculateHRVPercentile(hrv: Double?, age: Int) -> Int? {
        guard let hrv = hrv, hrv > 0 else { return nil }
        
        let thresholds: (p20: Double, p40: Double, p60: Double, p80: Double, p95: Double)
        
        switch age {
        case ..<30: thresholds = (25, 40, 55, 75, 100)
        case 30..<40: thresholds = (20, 35, 50, 65, 90)
        case 40..<50: thresholds = (18, 30, 42, 58, 80)
        case 50..<60: thresholds = (15, 25, 35, 50, 70)
        case 60..<70: thresholds = (12, 20, 30, 42, 60)
        default: thresholds = (10, 18, 25, 35, 50)
        }
        
        if hrv >= thresholds.p95 { return 97 }
        if hrv >= thresholds.p80 { return Int(80 + (hrv - thresholds.p80) / (thresholds.p95 - thresholds.p80) * 15) }
        if hrv >= thresholds.p60 { return Int(60 + (hrv - thresholds.p60) / (thresholds.p80 - thresholds.p60) * 20) }
        if hrv >= thresholds.p40 { return Int(40 + (hrv - thresholds.p40) / (thresholds.p60 - thresholds.p40) * 20) }
        if hrv >= thresholds.p20 { return Int(20 + (hrv - thresholds.p20) / (thresholds.p40 - thresholds.p20) * 20) }
        return max(5, Int(hrv / thresholds.p20 * 20))
    }
    
    // MARK: - RHR Percentile
    
    static func calculateRHRPercentile(rhr: Double?) -> Int? {
        guard let rhr = rhr, rhr > 0 else { return nil }
        
        // Inverted - lower is better
        let thresholds: (p95: Double, p80: Double, p60: Double, p40: Double, p20: Double) = (50, 58, 65, 72, 80)
        
        if rhr <= thresholds.p95 { return 97 }
        if rhr <= thresholds.p80 { return Int(80 + (thresholds.p80 - rhr) / (thresholds.p80 - thresholds.p95) * 15) }
        if rhr <= thresholds.p60 { return Int(60 + (thresholds.p60 - rhr) / (thresholds.p60 - thresholds.p80) * 20) }
        if rhr <= thresholds.p40 { return Int(40 + (thresholds.p40 - rhr) / (thresholds.p40 - thresholds.p60) * 20) }
        if rhr <= thresholds.p20 { return Int(20 + (thresholds.p20 - rhr) / (thresholds.p20 - thresholds.p40) * 20) }
        return max(5, Int((100 - rhr) / (100 - thresholds.p20) * 20))
    }
    
    // MARK: - Sleep Score
    
    static func calculateSleepScore(avgHours: Double?, consistency: Double?) -> Int? {
        guard let hours = avgHours, hours > 0 else { return nil }
        
        let durationScore: Double
        if hours >= 7 && hours <= 9 {
            durationScore = 100
        } else if hours >= 6 && hours < 7 {
            durationScore = 60 + (hours - 6) * 40
        } else if hours > 9 && hours <= 10 {
            durationScore = 100 - (hours - 9) * 20
        } else if hours >= 5 && hours < 6 {
            durationScore = 30 + (hours - 5) * 30
        } else if hours < 5 {
            durationScore = max(10, hours * 6)
        } else {
            durationScore = max(50, 100 - (hours - 10) * 25)
        }
        
        var consistencyModifier: Double = 0
        if let stdDev = consistency {
            if stdDev <= 0.5 { consistencyModifier = 10 }
            else if stdDev <= 1.0 { consistencyModifier = 5 }
            else if stdDev >= 1.5 { consistencyModifier = -10 }
        }
        
        return min(100, max(0, Int(durationScore + consistencyModifier)))
    }
    
    // MARK: - Overall Percentile
    
    static func calculateOverallPercentile(scores: ComponentScores) -> Int {
        // Weights: VO2 35%, Strength 25%, Sleep 20%, HRV 12%, RHR 8%
        var totalWeight: Double = 0
        var weightedSum: Double = 0
        
        if let vo2 = scores.vo2MaxPercentile {
            weightedSum += Double(vo2) * 0.35
            totalWeight += 0.35
        }
        
        if let strength = scores.strengthPercentile {
            weightedSum += Double(strength) * 0.25
            totalWeight += 0.25
        }
        
        if let sleep = scores.sleepScore {
            weightedSum += Double(sleep) * 0.20
            totalWeight += 0.20
        }
        
        if let hrv = scores.hrvPercentile {
            weightedSum += Double(hrv) * 0.12
            totalWeight += 0.12
        }
        
        if let rhr = scores.rhrPercentile {
            weightedSum += Double(rhr) * 0.08
            totalWeight += 0.08
        }
        
        guard totalWeight > 0 else { return 50 }
        
        return Int(weightedSum / totalWeight)
    }
    
    // MARK: - Tier from Percentile
    
    static func tierFromPercentile(_ percentile: Int) -> LongevityTier {
        switch percentile {
        case 95...: return .elite
        case 85..<95: return .optimal
        case 70..<85: return .phoenix
        case 50..<70: return .rising
        default: return .atRisk
        }
    }
    
    // MARK: - Generate Recommendation
    
    static func generateRecommendation(
        limitingFactor: String?,
        componentScores: ComponentScores,
        missingComponents: [MissingComponent]
    ) -> String? {
        
        // If missing major components, prioritize getting that data
        if let missingStrength = missingComponents.first(where: { $0.name == "Strength" }) {
            return "Complete the strength assessment to get your full Longevity Tier. Strength accounts for 25% of your score."
        }
        
        if let missingVO2 = missingComponents.first(where: { $0.name == "VO2 Max" }) {
            return "Connect a fitness tracker to capture VO2 Max - the strongest predictor of longevity (35% of your score)."
        }
        
        // Otherwise, recommend based on limiting factor
        guard let factor = limitingFactor else { return nil }
        
        switch factor {
        case "VO2 Max":
            if let vo2 = componentScores.vo2MaxPercentile, vo2 < 30 {
                return "Your VO2 Max is your biggest opportunity. Start with Zone 2 cardio 2-3x/week. This single metric has the strongest link to longevity."
            } else {
                return "Building your VO2 Max will have the biggest impact on your longevity tier. Add structured cardio progression."
            }
            
        case "Strength":
            if let strength = componentScores.strengthPercentile, strength < 30 {
                return "Strength is your biggest opportunity. Start with 2x/week resistance training. Muscle mass predicts longevity better than BMI."
            } else {
                return "Increasing your strength will significantly improve your longevity tier. Focus on progressive overload."
            }
            
        case "Sleep":
            if let sleep = componentScores.sleepScore, sleep < 50 {
                return "Sleep is your foundation - and it's limiting everything else. Focus here first. Target 7-8 hours with consistent bed/wake times."
            } else {
                return "Improving sleep consistency and duration will compound all your other efforts."
            }
            
        case "HRV":
            return "Your HRV suggests room for recovery optimization. Focus on sleep quality, stress management, and avoiding overtraining."
            
        case "Resting Heart Rate", "RHR":
            return "Improving your resting heart rate through consistent cardio will boost your overall longevity metrics."
            
        default:
            return nil
        }
    }
    
    // MARK: - Calculate and Save
    
    static func calculateAndSave(
        profile: UserProfile,
        vo2Max: Double?,
        strengthInput: StrengthInput,
        sleepAverage: Double?,
        sleepConsistency: Double?,
        hrv: Double?,
        rhr: Double?,
        modelContext: ModelContext
    ) -> TierResult {
        
        // Parse activity level from string
        let activityLevel = profile.activityLevel.flatMap { ActivityLevel(rawValue: $0) }
        
        let result = calculate(
            age: profile.age ?? 40,
            gender: profile.gender,
            bodyweight: profile.weight,
            vo2Max: vo2Max,
            strengthInput: strengthInput,
            sleepAverage: sleepAverage,
            sleepConsistency: sleepConsistency,
            hrv: hrv,
            rhr: rhr,
            height: profile.height,
            activityLevel: activityLevel,
            sleepSelfReport: profile.selfReportedSleepHours
        )
        
        profile.longevityTier = result.tier.rawValue
        profile.longevityTierPercentile = result.percentile
        profile.lastLongevityTierCalculationDate = Date()
        
        if profile.longevityTierRevealedAt == nil {
            profile.longevityTierRevealedAt = Date()
        }
        
        try? modelContext.save()
        
        print("✅ Longevity Tier Calculated: \(result.tier.displayName)")
        print("   Percentile: \(result.percentile)")
        print("   Complete: \(result.isComplete) (\(result.completenessPercentage)%)")
        print("   Inferred: \(result.inferredComponents.joined(separator: ", "))")
        print("   Limiting Factor: \(result.limitingFactor ?? "None")")
        if !result.missingComponents.isEmpty {
            print("   Missing: \(result.missingComponents.map { $0.name }.joined(separator: ", "))")
        }
        
        return result
    }
    
    // MARK: - Get Tier from Profile
    
    static func getTier(from profile: UserProfile) -> LongevityTier? {
        guard let tierString = profile.longevityTier else { return nil }
        return LongevityTier(rawValue: tierString)
    }
    
    // MARK: - Generate Reveal Message
    
    static func generateRevealMessage(result: TierResult, userName: String) -> String {
        let tier = result.tier
        
        var message = """
        \(userName), your Longevity Tier: **\(tier.displayName)**
        
        \(tier.percentileRange)
        
        \(tier.description)
        
        \(tier.urgencyMessage)
        """
        
        // Add inference notice if we used estimated data
        if result.hasInferredData {
            let inferredList = result.inferredComponents.joined(separator: ", ")
            message += "\n\n⚠️ **Based on Estimated Data**\n\(inferredList) estimated from your baseline info. Connect Apple Health for your actual metrics."
        }
        
        // Add completeness warning if incomplete
        if !result.isComplete {
            let missingNames = result.missingComponents.map { $0.name }.joined(separator: ", ")
            message += "\n\n⚠️ **Assessment \(result.completenessPercentage)% Complete**\nMissing: \(missingNames)"
        }
        
        if let recommendation = result.primaryRecommendation {
            message += "\n\n**Your #1 Priority:** \(recommendation)"
        }
        
        return message
    }
}