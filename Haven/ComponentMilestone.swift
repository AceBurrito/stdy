import Foundation
import SwiftData

// MARK: - Component Milestone Model

@Model
class ComponentMilestone {
    var id: UUID = UUID()
    var component: String = ""         // "sleep", "hrv", "rhr", "vo2max", "steps", "strength"
    var milestoneType: String = ""     // "tier_crossing", "percentile_jump", "absolute_threshold", "personal_best"
    var message: String = ""
    var detail: String?
    var date: Date = Date()
    var dismissed: Bool = false
    
    var userProfile: UserProfile?
    
    init(component: String, milestoneType: String, message: String, detail: String? = nil) {
        self.id = UUID()
        self.component = component
        self.milestoneType = milestoneType
        self.message = message
        self.detail = detail
        self.date = Date()
        self.dismissed = false
    }
}

// MARK: - Milestone Detection Engine

struct MilestoneDetector {
    
    /// Run after each Pace recalculation. Compares latest score to previous scores
    /// and generates milestones for meaningful changes.
    static func detectMilestones(
        latest: BiologicalPaceScore,
        previous: BiologicalPaceScore?,
        baseline: BiologicalPaceScore?,
        modelContext: ModelContext
    ) -> [ComponentMilestone] {
        
        var milestones: [ComponentMilestone] = []
        
        let componentPairs: [(name: String, latestPct: Double?, prevPct: Double?, basePct: Double?)] = [
            ("Sleep", latest.sleepPercentile, previous?.sleepPercentile, baseline?.sleepPercentile),
            ("HRV", latest.hrvPercentile, previous?.hrvPercentile, baseline?.hrvPercentile),
            ("Resting HR", latest.rhrPercentile, previous?.rhrPercentile, baseline?.rhrPercentile),
            ("VO₂ Max", latest.vo2MaxPercentile, previous?.vo2MaxPercentile, baseline?.vo2MaxPercentile),
            ("Daily Movement", latest.stepsPercentile, previous?.stepsPercentile, baseline?.stepsPercentile),
            ("Strength", latest.strengthPercentile, previous?.strengthPercentile, baseline?.strengthPercentile),
        ]
        
        for component in componentPairs {
            guard let current = component.latestPct else { continue }
            
            // 1. Tier crossing (crossed a meaningful threshold)
            if let prev = component.prevPct {
                let currentTier = tier(for: current)
                let prevTier = tier(for: prev)
                
                if currentTier != prevTier && current > prev {
                    let milestone = ComponentMilestone(
                        component: component.name,
                        milestoneType: "tier_crossing",
                        message: "Your \(component.name) moved from \(prevTier) to \(currentTier).",
                        detail: "Now at the \(ordinal(Int(current))) percentile for your age group."
                    )
                    milestones.append(milestone)
                }
            }
            
            // 2. Big percentile jump from baseline (10+ points)
            if let base = component.basePct {
                let jump = current - base
                if jump >= 10 {
                    let milestone = ComponentMilestone(
                        component: component.name,
                        milestoneType: "percentile_jump",
                        message: "Your \(component.name) improved \(Int(jump)) percentile points since onboarding.",
                        detail: "From \(ordinal(Int(base))) to \(ordinal(Int(current))) percentile."
                    )
                    milestones.append(milestone)
                }
            }
            
            // 3. Absolute thresholds (RHR < 60, sleep avg > 7.5, etc.)
            if let absoluteMilestone = checkAbsoluteThreshold(component: component.name, score: latest) {
                milestones.append(absoluteMilestone)
            }
        }
        
        // Insert new milestones
        for milestone in milestones {
            // Check we atlas't already created this exact milestone type+component recently (within 30 days)
            if !isDuplicate(milestone, in: modelContext) {
                modelContext.insert(milestone)
            }
        }
        
        try? modelContext.save()
        
        return milestones
    }
    
    // MARK: - Tier Labels
    
    private static func tier(for percentile: Double) -> String {
        if percentile >= 80 { return "Elite" }
        if percentile >= 65 { return "Above Average" }
        if percentile >= 35 { return "Average" }
        if percentile >= 20 { return "Below Average" }
        return "At Risk"
    }
    
    // MARK: - Absolute Thresholds
    
    private static func checkAbsoluteThreshold(component: String, score: BiologicalPaceScore) -> ComponentMilestone? {
        switch component {
        case "Resting HR":
            if let rhr = score.rhrUsed, rhr < 60 {
                return ComponentMilestone(
                    component: component,
                    milestoneType: "absolute_threshold",
                    message: "Your resting heart rate dropped below 60 bpm.",
                    detail: "That puts you in an excellent cardiovascular fitness range."
                )
            }
        case "Sleep":
            if let sleep = score.sleepHoursUsed, sleep >= 7.5 {
                return ComponentMilestone(
                    component: component,
                    milestoneType: "absolute_threshold",
                    message: "Your average sleep hit \(String(format: "%.1f", sleep)) hours.",
                    detail: "You're now in the optimal range for recovery and longevity."
                )
            }
        default:
            break
        }
        return nil
    }
    
    // MARK: - Deduplication
    
    private static func isDuplicate(_ milestone: ComponentMilestone, in context: ModelContext) -> Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let component = milestone.component
        let type = milestone.milestoneType
        
        let descriptor = FetchDescriptor<ComponentMilestone>(
            predicate: #Predicate<ComponentMilestone> {
                $0.component == component &&
                $0.milestoneType == type &&
                $0.date >= thirtyDaysAgo
            }
        )
        
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }
    
    // MARK: - Helpers
    
    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}