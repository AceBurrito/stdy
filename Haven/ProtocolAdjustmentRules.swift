import Foundation

// MARK: - Protocol Action Types
enum ProtocolAction: String {
    case simplify = "SIMPLIFY"
    case maintain = "MAINTAIN"
    case progress = "PROGRESS"
}

// MARK: - Protocol Adjustment Rules
struct ProtocolAdjustmentRules {
    
    // MARK: - Consecutive Week Counting
    struct ConsecutiveWeeks {
        let high: Int  // Weeks at ≥80% adherence
        let low: Int   // Weeks at <60% adherence
    }
    
    static func countConsecutiveWeeks(weeks: [WeeklyCheckInData]) -> ConsecutiveWeeks {
        var highCount = 0
        var lowCount = 0
        
        // Count from most recent week backwards
        for week in weeks {
            if week.habitCompletionRate >= 0.80 {
                highCount += 1
            } else {
                break
            }
        }
        
        // Reset and count low weeks
        for week in weeks {
            if week.habitCompletionRate < 0.60 {
                lowCount += 1
            } else {
                break
            }
        }
        
        return ConsecutiveWeeks(high: highCount, low: lowCount)
    }
    
    // MARK: - Main Decision Logic
    static func determineAction(
        adherence: Double,
        consecutiveHighWeeks: Int,
        consecutiveLowWeeks: Int,
        avgSleep: Double
    ) -> ProtocolAction {
        
        // RULE 1: Sleep Priority Override (Warning, not immediate simplify)
        // We'll handle sleep warnings separately, not as immediate SIMPLIFY
        
        // RULE 2: SIMPLIFY - Only after 2 consecutive low weeks
        if consecutiveLowWeeks >= 2 {
            return .simplify
        }
        
        // RULE 3: PROGRESS - Crushing it for 3+ weeks
        if consecutiveHighWeeks >= 3 && avgSleep >= 7.0 {
            return .progress
        }
        
        // RULE 4: MAINTAIN - Everything else
        return .maintain
    }
    
    // MARK: - Sleep Warning Detection
    static func detectSleepIssue(
        currentWeek: WeeklyCheckInData,
        previousWeeks: [WeeklyCheckInData]
    ) -> SleepWarningLevel {
        
        let threshold = 6.5
        
        // Check current week
        if currentWeek.avgSleep >= threshold {
            return .none
        }
        
        // Check if last week was also low
        if let lastWeek = previousWeeks.first {
            if lastWeek.avgSleep < threshold {
                return .critical // 2 weeks in a row
            }
        }
        
        return .warning // First week below threshold
    }
    
    // MARK: - Regression Detection
    static func detectRegression(weeks: [WeeklyCheckInData]) -> RegressionAlert? {
        guard weeks.count >= 3 else { return nil }
        
        let currentWeek = weeks[0]
        let previousWeeks = Array(weeks.dropFirst().prefix(2))
        
        // Check Pattern 1: Was high (80%+) for 2 weeks, now low (<60%)
        let wasHigh = previousWeeks.allSatisfy { $0.habitCompletionRate >= 0.80 }
        let nowLow = currentWeek.habitCompletionRate < 0.60
        
        if wasHigh && nowLow {
            return RegressionAlert(
                type: .suddenDrop,
                message: "You were crushing it at 80%+ for 2 weeks, now at \(Int(currentWeek.habitCompletionRate * 100))%. What changed?"
            )
        }
        
        // Check Pattern 2: 20%+ decline week-over-week
        if let lastWeek = previousWeeks.first {
            let decline = lastWeek.habitCompletionRate - currentWeek.habitCompletionRate
            
            if decline >= 0.20 {
                return RegressionAlert(
                    type: .sharpDecline,
                    message: "Adherence dropped \(Int(decline * 100))% from last week (\(Int(lastWeek.habitCompletionRate * 100))% → \(Int(currentWeek.habitCompletionRate * 100))%)"
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Foundation Training Progression Check
    static func checkMovementPlanReadiness(
        profile: UserProfile,
        weeks: [WeeklyCheckInData]
    ) -> MovementProgressionStatus {
        
       
        
        guard let startDate = profile.movementPlanStartDate else {
            print("⚠️ Foundation training missing start date")
            return .notReady(reason: "Missing start date tracking")
        }
        
        let weeksOnPlan = Calendar.current.dateComponents([.weekOfYear], from: startDate, to: Date()).weekOfYear ?? 0
        
        // Need at least 4 weeks of data
        guard weeks.count >= 4 else {
            return .notReady(reason: "Need 4 weeks of data (have \(weeks.count))")
        }
        
        let last4Weeks = Array(weeks.prefix(4))
        let avgAdherence = last4Weeks.map { $0.habitCompletionRate }.reduce(0, +) / 4.0
        let avgSleep = last4Weeks.map { $0.avgSleep }.reduce(0, +) / 4.0
        
        // FAST TRACK: 4 weeks if crushing it
        if weeksOnPlan >= 4 {
            let allWeeksHigh = last4Weeks.allSatisfy { $0.habitCompletionRate >= 0.80 }
            
            if allWeeksHigh && avgSleep >= 7.0 {
                return .ready(
                    weeksCompleted: weeksOnPlan,
                    avgAdherence: avgAdherence,
                    fastTrack: true
                )
            }
        }
        
        // STANDARD TRACK: 6 weeks with good adherence
        if weeksOnPlan >= 6 && avgAdherence >= 0.80 {
            return .ready(
                weeksCompleted: weeksOnPlan,
                avgAdherence: avgAdherence,
                fastTrack: false
            )
        }
        
        return .notReady(reason: "Week \(weeksOnPlan)/6, avg adherence \(Int(avgAdherence * 100))%")
    }
}

// MARK: - Supporting Types

enum SleepWarningLevel {
    case none
    case warning      // First week <6.5h
    case critical     // 2+ weeks <6.5h
}

struct RegressionAlert {
    enum RegressionType {
        case suddenDrop    // Was 80%+, now <60%
        case sharpDecline  // 20%+ decline
    }
    
    let type: RegressionType
    let message: String
}

enum MovementProgressionStatus {
    case notApplicable
    case notReady(reason: String)
    case ready(weeksCompleted: Int, avgAdherence: Double, fastTrack: Bool)
}