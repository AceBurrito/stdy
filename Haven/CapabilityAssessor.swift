import Foundation

class CapabilityAssessor {
    
    // MARK: - Calculate Minimum Weeks Required
    static func calculateMinimumWeeks(
        eventType: String,
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        switch eventType {
        case "5k":
            return calculate5KRequirements(assessment: assessment)
        case "10k":
            return calculate10KRequirements(assessment: assessment)
        case "half_marathon":
            return calculateHalfMarathonRequirements(assessment: assessment)
        case "marathon":
            return calculateMarathonRequirements(assessment: assessment)
        case "hyrox":
            return calculateHYROXRequirements(assessment: assessment)
        case "sprint_tri":
            return calculateSprintTriRequirements(assessment: assessment)
        default:
            return (12, 16, ["Unknown event type"])
        }
    }
    
    // MARK: - 5K Requirements
    private static func calculate5KRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 4
        var recommended = 6
        
        switch assessment.runningCapability {
        case "cannot_run_10min":
            minimum = 8
            recommended = 10
            warnings.append("You'll start with run/walk intervals to build base safely")
            
        case "10_15min":
            minimum = 6
            recommended = 8
            warnings.append("We'll gradually build your continuous running time")
            
        case "20_30min":
            minimum = 4
            recommended = 6
            if assessment.recentRaces.contains("5k") {
                minimum = 3
                recommended = 4
            }
            
        case "30_45min", "45_60min", "60plus":
            minimum = 3
            recommended = 4
            if assessment.recentRaces.contains("5k") {
                minimum = 2
                recommended = 3
                warnings.append("You're well-prepared. This is a tune-up plan.")
            }
            
        default:
            break
        }
        
        // Adjust for strength training
        if assessment.strengthTrainingFrequency == "never" || 
           assessment.strengthTrainingFrequency == "occasionally" {
            warnings.append("We'll add injury-prevention strength work")
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - 10K Requirements
    private static func calculate10KRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 6
        var recommended = 8
        
        switch assessment.runningCapability {
        case "cannot_run_10min":
            minimum = 12
            recommended = 16
            warnings.append("Significant base building needed - will start with run/walk")
            
        case "10_15min":
            minimum = 10
            recommended = 12
            warnings.append("We'll build your continuous running time progressively")
            
        case "20_30min":
            minimum = 6
            recommended = 8
            if assessment.recentRaces.contains("5k") {
                minimum = 5
                recommended = 6
            }
            
        case "30_45min":
            minimum = 5
            recommended = 6
            if assessment.recentRaces.contains("10k") {
                minimum = 4
                recommended = 5
            }
            
        case "45_60min", "60plus":
            minimum = 4
            recommended = 5
            if assessment.recentRaces.contains("10k") {
                minimum = 3
                recommended = 4
            }
            
        default:
            break
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - Half Marathon Requirements
    private static func calculateHalfMarathonRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 10
        var recommended = 12
        
        switch assessment.runningCapability {
        case "cannot_run_10min":
            minimum = 20
            recommended = 24
            warnings.append("CRITICAL: Significant base building required")
            warnings.append("You'll need 12 weeks of run/walk before starting half marathon training")
            
        case "10_15min":
            minimum = 16
            recommended = 20
            warnings.append("You'll need 8 weeks of base building before half marathon-specific training")
            
        case "20_30min":
            minimum = 12
            recommended = 14
            if assessment.recentRaces.contains("10k") {
                minimum = 10
                recommended = 12
            }
            
        case "30_45min":
            minimum = 10
            recommended = 12
            if assessment.recentRaces.contains("10k") {
                minimum = 8
                recommended = 10
            }
            
        case "45_60min":
            minimum = 8
            recommended = 10
            if assessment.recentRaces.contains("half_marathon") {
                minimum = 6
                recommended = 8
            }
            
        case "60plus":
            minimum = 6
            recommended = 8
            if assessment.recentRaces.contains("half_marathon") {
                minimum = 5
                recommended = 6
            }
            
        default:
            break
        }
        
        // Injury risk warnings
        if assessment.strengthTrainingFrequency == "never" {
            warnings.append("HIGH INJURY RISK: No strength training history")
            warnings.append("We'll add 2x/week strength to prevent common running injuries")
            minimum += 2 // Add buffer for strength adaptation
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - Marathon Requirements
    private static func calculateMarathonRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 16
        var recommended = 20
        
        // Marathon requires solid running base
        switch assessment.runningCapability {
        case "cannot_run_10min", "10_15min":
            minimum = 32
            recommended = 36
            warnings.append("CRITICAL: Marathon requires established running base")
            warnings.append("Recommend training for half marathon first")
            
        case "20_30min":
            minimum = 24
            recommended = 28
            if !assessment.recentRaces.contains("half_marathon") {
                warnings.append("STRONGLY RECOMMENDED: Complete a half marathon first")
                warnings.append("Marathon is a significant step up in training load")
            }
            
        case "30_45min":
            minimum = 20
            recommended = 24
            if assessment.recentRaces.contains("half_marathon") {
                minimum = 18
                recommended = 20
            } else {
                warnings.append("Consider racing a half marathon before marathon training begins")
            }
            
        case "45_60min":
            minimum = 16
            recommended = 20
            if !assessment.recentRaces.contains("half_marathon") {
                warnings.append("Half marathon experience recommended but not required")
            }
            
        case "60plus":
            minimum = 16
            recommended = 18
            if assessment.recentRaces.contains("marathon") {
                minimum = 14
                recommended = 16
            }
            
        default:
            break
        }
        
        // Marathon-specific warnings
        if assessment.weeklyTimeAvailable == "3_5hrs" || 
           assessment.weeklyTimeAvailable == "6_8hrs" {
            warnings.append("Marathon training peaks at 12-16 hours/week")
            warnings.append("Your available time may be insufficient at peak training")
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - HYROX Requirements
    private static func calculateHYROXRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 12
        var recommended = 16
        
        // HYROX requires both running + functional fitness
        let hasRunningBase = ["30_45min", "45_60min", "60plus"].contains(assessment.runningCapability)
        let hasStrengthBase = ["regularly", "frequently", "very_frequently"].contains(assessment.strengthTrainingFrequency)
        let hasFunctionalExperience = assessment.functionalFitnessBackground?.count ?? 0 > 0
        
        if !hasRunningBase && !hasStrengthBase {
            // Need both running and strength foundation
            minimum = 20
            recommended = 24
            warnings.append("CRITICAL: Need to build both running endurance and strength base")
            warnings.append("First 12 weeks: General conditioning")
            warnings.append("Last 8-12 weeks: HYROX-specific training")
        } else if !hasRunningBase {
            // Has strength, needs running
            minimum = 16
            recommended = 20
            warnings.append("You'll need to build running endurance (currently \(assessment.runningCapability))")
            warnings.append("Target: 30+ min continuous running before HYROX-specific work")
        } else if !hasStrengthBase {
            // Has running, needs strength
            minimum = 14
            recommended = 18
            warnings.append("Limited strength training history - injury risk for HYROX stations")
            warnings.append("We'll build functional strength progressively")
        } else if !hasFunctionalExperience {
            // Has both, but no functional fitness
            minimum = 12
            recommended = 16
            warnings.append("You'll learn HYROX movements (sleds, carries, burpees, etc.)")
        } else {
            // Well prepared
            minimum = 10
            recommended = 12
        }
        
        // Equipment warnings
        if let equipment = assessment.availableEquipment {
            let criticalEquipment = ["skierg", "sled_push", "sled_pull", "rower"]
            let hasEquipment = criticalEquipment.filter { equipment.contains($0) }
            
            if hasEquipment.count < 3 && assessment.trainsAtHyroxGym != true {
                warnings.append("LIMITED EQUIPMENT: You're missing \(4 - hasEquipment.count) critical HYROX stations")
                warnings.append("We'll use substitutes but recommend finding HYROX gym for weeks 9-12")
            }
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - Sprint Triathlon Requirements
    private static func calculateSprintTriRequirements(
        assessment: UserCapabilityAssessment
    ) -> (minimum: Int, recommended: Int, warnings: [String]) {
        
        var warnings: [String] = []
        var minimum = 12
        var recommended = 16
        
        // Check each discipline
        let canSwim = assessment.swimmingCapability != nil && 
                      assessment.swimmingCapability != "cannot_swim"
        let canBike = assessment.cyclingCapability != nil && 
                      assessment.cyclingCapability != "no_biking"
        let canRun = ["20_30min", "30_45min", "45_60min", "60plus"].contains(assessment.runningCapability)
        
        // Swimming is usually the limiter
        if assessment.swimmingCapability == "cannot_swim" {
            minimum = 24
            recommended = 28
            warnings.append("CRITICAL: Learning to swim takes 3-6 months")
            warnings.append("STRONGLY RECOMMEND: Hire swim coach immediately")
            warnings.append("OR: Consider postponing until you can swim 200m continuously")
        } else if assessment.swimmingCapability == "100_200m" {
            minimum = 16
            recommended = 20
            warnings.append("Swimming will require significant focus (200m → 750m)")
            warnings.append("Recommend swim coaching for technique")
        }
        
        if !canBike {
            minimum += 4
            warnings.append("Limited cycling experience - need to build saddle time progressively")
        }
        
        if !canRun {
            minimum += 4
            warnings.append("Running base needs development before tri-specific training")
        }
        
        // Tri-specific warnings
        if assessment.triathlonExperience == nil || assessment.triathlonExperience == "none" {
            warnings.append("New to triathlon: You'll learn transitions, brick workouts, race nutrition")
            warnings.append("These skills take practice - don't underestimate learning curve")
        }
        
        return (minimum, recommended, warnings)
    }
    
    // MARK: - Timeline Status Calculation
    static func getTimelineStatus(
        weeksAvailable: Int,
        minimumRequired: Int,
        recommended: Int
    ) -> (status: String, successRate: Int?, message: String) {
        
        if weeksAvailable < minimumRequired {
            return (
                "insufficient",
                nil,
                "Not enough time to prepare safely for this event"
            )
        } else if weeksAvailable == minimumRequired {
            return (
                "minimum",
                60,
                "Tight timeline - no room for setbacks"
            )
        } else if weeksAvailable < recommended {
            return (
                "tight",
                75,
                "Achievable but compressed timeline"
            )
        } else if weeksAvailable < recommended + 4 {
            return (
                "comfortable",
                85,
                "Good timeline with buffer for life happening"
            )
        } else {
            return (
                "optimal",
                90,
                "Plenty of time to prepare properly"
            )
        }
    }
}